defmodule TravelAgent.Fixtures do
  @moduledoc """
  Test fixtures and helpers.
  """

  import Mox

  alias TravelAgent.LLM.MockClient

  @doc """
  Setup mock LLM client to return a specific response.
  """
  def mock_llm_response(response) do
    expect(MockClient, :chat, fn _messages, _opts ->
      {:ok, response}
    end)
  end

  @doc """
  Setup mock LLM client to return multiple responses in sequence.
  """
  def mock_llm_responses(responses) when is_list(responses) do
    for response <- responses do
      expect(MockClient, :chat, fn _messages, _opts ->
        {:ok, response}
      end)
    end
  end

  @doc """
  Setup mock LLM client to return an error.
  """
  def mock_llm_error(error \\ :timeout) do
    expect(MockClient, :chat, fn _messages, _opts ->
      {:error, error}
    end)
  end

  @doc """
  Sample messages for testing.
  """
  def sample_messages do
    [
      %{role: "system", content: "You are a helpful assistant."},
      %{role: "user", content: "Hello!"},
      %{role: "assistant", content: "Hi there! How can I help you today?"}
    ]
  end
end
