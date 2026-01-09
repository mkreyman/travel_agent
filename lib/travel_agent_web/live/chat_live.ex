defmodule TravelAgentWeb.ChatLive do
  @moduledoc """
  LiveView for the chat interface.

  Provides a simple, responsive chat UI that communicates with the ConversationAgent.
  """

  use TravelAgentWeb, :live_view

  alias TravelAgent.Agent.ConversationAgent

  @impl true
  def mount(_params, _session, socket) do
    # Start a new conversation agent for this session
    {:ok, agent} = ConversationAgent.start_link()

    socket =
      socket
      |> assign(:agent, agent)
      |> assign(:messages, [])
      |> assign(:input_value, "")
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    # Add user message to UI
    user_message = %{role: "user", content: message}

    socket =
      socket
      |> update(:messages, &(&1 ++ [user_message]))
      |> assign(:input_value, "")
      |> assign(:loading, true)

    # Send to agent asynchronously
    send(self(), {:chat, message})

    {:noreply, socket}
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_input", %{"message" => value}, socket) do
    {:noreply, assign(socket, :input_value, value)}
  end

  @impl true
  def handle_info({:chat, message}, socket) do
    case ConversationAgent.chat(socket.assigns.agent, message) do
      {:ok, response} ->
        assistant_message = %{role: "assistant", content: response}

        socket =
          socket
          |> update(:messages, &(&1 ++ [assistant_message]))
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, _reason} ->
        error_message = %{role: "system", content: "Sorry, an error occurred. Please try again."}

        socket =
          socket
          |> update(:messages, &(&1 ++ [error_message]))
          |> assign(:loading, false)

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen max-w-4xl mx-auto p-4">
      <header class="mb-4">
        <h1 class="text-2xl font-bold text-gray-800">AI Assistant</h1>
      </header>

      <div class="flex-1 overflow-y-auto space-y-4 mb-4 p-4 bg-gray-50 rounded-lg" id="messages">
        <%= for message <- @messages do %>
          <div class={[
            "p-3 rounded-lg max-w-[80%]",
            message_classes(message.role)
          ]}>
            <p class="text-sm font-medium mb-1">{role_label(message.role)}</p>
            <p class="whitespace-pre-wrap">{message.content}</p>
          </div>
        <% end %>

        <%= if @loading do %>
          <div class="flex items-center space-x-2 text-gray-500">
            <div class="animate-pulse">Thinking...</div>
          </div>
        <% end %>
      </div>

      <form phx-submit="send_message" class="flex space-x-2">
        <input
          type="text"
          name="message"
          value={@input_value}
          phx-change="update_input"
          placeholder="Type your message..."
          class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          autocomplete="off"
          disabled={@loading}
        />
        <button
          type="submit"
          disabled={@loading || @input_value == ""}
          class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Send
        </button>
      </form>
    </div>
    """
  end

  defp message_classes("user"), do: "bg-blue-100 ml-auto"
  defp message_classes("assistant"), do: "bg-white border border-gray-200"
  defp message_classes("system"), do: "bg-yellow-100 mx-auto text-center"

  defp role_label("user"), do: "You"
  defp role_label("assistant"), do: "Assistant"
  defp role_label("system"), do: "System"
end
