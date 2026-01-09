defmodule TravelAgent.LLM.OpenAIClient do
  @moduledoc """
  OpenAI API client implementation.

  Uses the ChatCompletions endpoint with GPT-4o as default model.
  """

  @behaviour TravelAgent.LLM.ClientBehaviour

  @default_model "gpt-4o"
  @default_temperature 0.7
  @default_max_tokens 1024
  @default_retries 3
  @retry_delay 1000

  @impl true
  def chat(messages, options \\ []) do
    model = Keyword.get(options, :model, @default_model)
    temperature = Keyword.get(options, :temperature, @default_temperature)
    max_tokens = Keyword.get(options, :max_tokens, @default_max_tokens)

    body = %{
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens
    }

    case Req.post(api_url(), json: body, headers: headers(), retry: retry_options()) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def chat_with_tools(messages, tools, options \\ []) do
    model = Keyword.get(options, :model, @default_model)
    temperature = Keyword.get(options, :temperature, @default_temperature)
    max_tokens = Keyword.get(options, :max_tokens, @default_max_tokens)

    body = %{
      model: model,
      messages: messages,
      tools: tools,
      temperature: temperature,
      max_tokens: max_tokens
    }

    case Req.post(api_url(), json: body, headers: headers(), retry: retry_options()) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => message} | _]}}} ->
        {:ok, message}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp api_url, do: "https://api.openai.com/v1/chat/completions"

  defp headers do
    [
      {"authorization", "Bearer #{api_key()}"},
      {"content-type", "application/json"}
    ]
  end

  defp api_key do
    Application.fetch_env!(:travel_agent, :openai_api_key)
  end

  defp retry_options do
    [
      max_retries: @default_retries,
      delay: @retry_delay,
      retry: fn
        {:ok, %{status: status}} when status in [429, 500, 502, 503, 504] -> true
        {:error, %Req.TransportError{}} -> true
        _ -> false
      end
    ]
  end
end
