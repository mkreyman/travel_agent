defmodule TravelAgent.Agent.ConversationAgent do
  @moduledoc """
  GenServer managing a single conversation session.

  Maintains message history in-memory and delegates to LLM client for responses.
  """

  use GenServer

  require Logger

  alias TravelAgent.Context.SimpleMemory

  @default_system_prompt """
  You are a helpful AI assistant. Be concise and friendly.
  """

  @max_context_messages 20

  # Client API

  @doc """
  Starts a new conversation agent.

  ## Options
  - `:system_prompt` - Custom system prompt (optional)
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

    state = %{
      memory: SimpleMemory.new(system_prompt),
      llm_client: client
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
  def handle_call(:clear_history, _from, state) do
    system_prompt = SimpleMemory.get_system_prompt(state.memory)
    state = put_in(state.memory, SimpleMemory.new(system_prompt))
    {:reply, :ok, state}
  end

  # Private Functions

  defp maybe_trim_context(messages) when length(messages) > @max_context_messages do
    # Keep system message + last N messages
    [system | rest] = messages
    [system | Enum.take(rest, -(@max_context_messages - 1))]
  end

  defp maybe_trim_context(messages), do: messages

  defp llm_client do
    Application.get_env(:travel_agent, :llm_client, TravelAgent.LLM.OpenAIClient)
  end
end
