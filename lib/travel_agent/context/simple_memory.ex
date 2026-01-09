defmodule TravelAgent.Context.SimpleMemory do
  @moduledoc """
  Simple in-memory message storage for conversation context.

  Stores messages as a list of maps with role, content, and timestamp.
  Suitable for sprint/competition mode where persistence isn't needed.
  """

  @type t :: %__MODULE__{
          system_prompt: String.t(),
          messages: [message()]
        }

  @type message :: %{role: String.t(), content: String.t(), timestamp: DateTime.t()}

  defstruct [:system_prompt, messages: []]

  @doc """
  Create a new memory store with a system prompt.
  """
  @spec new(String.t()) :: t()
  def new(system_prompt) do
    %__MODULE__{
      system_prompt: system_prompt,
      messages: []
    }
  end

  @doc """
  Add a message to the conversation history.
  """
  @spec add_message(t(), String.t(), String.t()) :: t()
  def add_message(%__MODULE__{} = memory, role, content) do
    message = %{role: role, content: content, timestamp: DateTime.utc_now()}
    %{memory | messages: memory.messages ++ [message]}
  end

  @doc """
  Get all messages formatted for LLM API, including system prompt.
  """
  @spec get_messages(t()) :: [message()]
  def get_messages(%__MODULE__{} = memory) do
    system_message = %{
      role: "system",
      content: memory.system_prompt,
      timestamp: DateTime.utc_now()
    }

    [system_message | memory.messages]
  end

  @doc """
  Get the system prompt.
  """
  @spec get_system_prompt(t()) :: String.t()
  def get_system_prompt(%__MODULE__{system_prompt: prompt}), do: prompt

  @doc """
  Get message count (excluding system prompt).
  """
  @spec message_count(t()) :: non_neg_integer()
  def message_count(%__MODULE__{messages: messages}), do: length(messages)
end
