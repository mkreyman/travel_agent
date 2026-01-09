defmodule TravelAgent.Agent.ConversationAgent do
  @moduledoc """
  GenServer managing a single conversation session.

  Maintains message history in-memory and delegates to LLM client for responses.
  Supports tool use for enhanced agent capabilities.
  """

  use GenServer

  require Logger

  alias TravelAgent.Context.SimpleMemory
  alias TravelAgent.Tools.ToolBehaviour

  @default_system_prompt """
  You are a helpful AI assistant. Be concise and friendly.
  """

  @max_context_messages 20
  @max_tool_iterations 5

  # Client API

  @doc """
  Starts a new conversation agent.

  ## Options
  - `:system_prompt` - Custom system prompt (optional)
  - `:tools` - List of tool modules implementing ToolBehaviour (optional)
  - `:name` - GenServer name for registration
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Send a message and get a response.

  ## Parameters
  - `agent` - Agent PID or registered name
  - `message` - User message string

  ## Returns
  - `{:ok, response}` on success
  - `{:error, reason}` on failure
  """
  def chat(agent, message) do
    GenServer.call(agent, {:chat, message}, 30_000)
  end

  @doc """
  Send a message with tool use enabled.

  The agent will automatically execute tool calls from the LLM
  and return the final response.

  ## Parameters
  - `agent` - Agent PID or registered name
  - `message` - User message string

  ## Returns
  - `{:ok, response}` on success
  - `{:error, reason}` on failure
  """
  def chat_with_tools(agent, message) do
    GenServer.call(agent, {:chat_with_tools, message}, 60_000)
  end

  @doc """
  Get the conversation history.
  """
  def get_history(agent) do
    GenServer.call(agent, :get_history)
  end

  @doc """
  Clear the conversation history, keeping only the system prompt.
  """
  def clear_history(agent) do
    GenServer.call(agent, :clear_history)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    system_prompt = Keyword.get(opts, :system_prompt, @default_system_prompt)
    client = Keyword.get(opts, :llm_client, llm_client())
    tools = Keyword.get(opts, :tools, [])

    state = %{
      memory: SimpleMemory.new(system_prompt),
      llm_client: client,
      tools: tools,
      tool_map: build_tool_map(tools)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:chat, user_message}, _from, state) do
    state = update_in(state.memory, &SimpleMemory.add_message(&1, "user", user_message))

    messages =
      state.memory
      |> SimpleMemory.get_messages()
      |> maybe_trim_context()

    case state.llm_client.chat(messages, []) do
      {:ok, response} ->
        state = update_in(state.memory, &SimpleMemory.add_message(&1, "assistant", response))
        {:reply, {:ok, response}, state}

      {:error, reason} = error ->
        Logger.error("LLM chat failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, SimpleMemory.get_messages(state.memory), state}
  end

  @impl true
  def handle_call({:chat_with_tools, user_message}, _from, state) do
    state = update_in(state.memory, &SimpleMemory.add_message(&1, "user", user_message))

    messages =
      state.memory
      |> SimpleMemory.get_messages()
      |> maybe_trim_context()

    openai_tools = Enum.map(state.tools, &ToolBehaviour.to_openai_tool/1)

    case run_tool_loop(state.llm_client, messages, openai_tools, state.tool_map, 0) do
      {:ok, response, updated_messages} ->
        # Save the final conversation state
        state = save_tool_conversation(state, updated_messages)
        {:reply, {:ok, response}, state}

      {:error, reason} = error ->
        Logger.error("LLM chat with tools failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:clear_history, _from, state) do
    system_prompt = SimpleMemory.get_system_prompt(state.memory)
    state = put_in(state.memory, SimpleMemory.new(system_prompt))
    {:reply, :ok, state}
  end

  # Private Functions

  defp run_tool_loop(_client, _messages, _tools, _tool_map, iteration)
       when iteration >= @max_tool_iterations do
    {:error, :max_tool_iterations_exceeded}
  end

  defp run_tool_loop(client, messages, tools, tool_map, iteration) do
    case client.chat_with_tools(messages, tools, []) do
      {:ok, %{"content" => content, "tool_calls" => nil}} ->
        clean_content = strip_surrounding_quotes(content)
        {:ok, clean_content, messages ++ [%{role: "assistant", content: clean_content}]}

      {:ok, %{"content" => content}} when is_binary(content) and content != "" ->
        clean_content = strip_surrounding_quotes(content)
        {:ok, clean_content, messages ++ [%{role: "assistant", content: clean_content}]}

      {:ok, %{"tool_calls" => tool_calls} = response} when is_list(tool_calls) ->
        # Add assistant message with tool calls to history
        assistant_message = build_assistant_tool_message(response)
        messages = messages ++ [assistant_message]

        # Execute each tool call
        tool_results = Enum.map(tool_calls, &execute_tool_call(&1, tool_map))

        # Add tool results to messages
        messages = messages ++ tool_results

        # Continue the loop
        run_tool_loop(client, messages, tools, tool_map, iteration + 1)

      {:ok, %{"content" => nil}} ->
        {:ok, "", messages}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_assistant_tool_message(%{"tool_calls" => tool_calls} = response) do
    %{
      role: "assistant",
      content: response["content"],
      tool_calls:
        Enum.map(tool_calls, fn tc ->
          %{
            id: tc["id"],
            type: tc["type"],
            function: %{
              name: tc["function"]["name"],
              arguments: tc["function"]["arguments"]
            }
          }
        end)
    }
  end

  defp execute_tool_call(tool_call, tool_map) do
    tool_name = tool_call["function"]["name"]
    tool_id = tool_call["id"]

    case Map.get(tool_map, tool_name) do
      nil ->
        build_tool_error(tool_id, "Unknown tool: #{tool_name}")

      tool_module ->
        execute_known_tool(tool_module, tool_call, tool_id)
    end
  end

  defp execute_known_tool(tool_module, tool_call, tool_id) do
    case Jason.decode(tool_call["function"]["arguments"]) do
      {:ok, args} ->
        run_tool(tool_module, args, tool_id)

      {:error, _} ->
        build_tool_error(tool_id, "Invalid arguments JSON")
    end
  end

  defp run_tool(tool_module, args, tool_id) do
    case tool_module.execute(args) do
      {:ok, result} ->
        %{role: "tool", tool_call_id: tool_id, content: result}

      {:error, reason} ->
        build_tool_error(tool_id, inspect(reason))
    end
  end

  defp build_tool_error(tool_id, message) do
    %{
      role: "tool",
      tool_call_id: tool_id,
      content: Jason.encode!(%{error: message})
    }
  end

  defp save_tool_conversation(state, messages) do
    # Extract only user/assistant messages for clean history
    # Skip the system message (already in memory) and tool-related messages
    new_messages =
      messages
      |> Enum.drop(1)
      |> Enum.filter(fn msg ->
        msg.role in ["user", "assistant"] and not Map.has_key?(msg, :tool_calls)
      end)

    Enum.reduce(new_messages, state, fn msg, acc ->
      update_in(acc.memory, &SimpleMemory.add_message(&1, msg.role, msg.content || ""))
    end)
  end

  defp build_tool_map(tools) do
    tools
    |> Enum.map(fn module -> {module.name(), module} end)
    |> Map.new()
  end

  defp maybe_trim_context(messages) when length(messages) > @max_context_messages do
    # Keep system message + last N messages
    [system | rest] = messages
    [system | Enum.take(rest, -(@max_context_messages - 1))]
  end

  defp maybe_trim_context(messages), do: messages

  defp llm_client do
    Application.get_env(:travel_agent, :llm_client, TravelAgent.LLM.OpenAIClient)
  end

  defp strip_surrounding_quotes(nil), do: nil

  defp strip_surrounding_quotes(content) when is_binary(content) do
    content
    |> String.trim()
    |> strip_quotes()
  end

  defp strip_quotes(<<"\"", rest::binary>>) do
    case String.trim_trailing(rest, "\"") do
      ^rest -> "\"" <> rest
      trimmed -> trimmed
    end
  end

  defp strip_quotes(content), do: content
end
