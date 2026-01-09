defmodule TravelAgentWeb.ChatLive do
  @moduledoc """
  LiveView for the chat interface.

  Provides a modern, responsive chat UI that communicates with the ConversationAgent.
  """

  use TravelAgentWeb, :live_view

  alias TravelAgent.Agent.ConversationAgent
  alias TravelAgent.Tools.DestinationTool

  @max_message_length 4000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:agent, nil)
      |> assign(:messages, [])
      |> assign(:input_value, "")
      |> assign(:loading, false)
      |> assign(:error, nil)

    # Only start agent when connected (mount is called twice: HTTP render + WebSocket)
    socket =
      if connected?(socket) do
        system_prompt = Application.get_env(:travel_agent, :travel_system_prompt)

        {:ok, agent} =
          DynamicSupervisor.start_child(
            TravelAgent.AgentSupervisor,
            {ConversationAgent,
             system_prompt: system_prompt, tools: [DestinationTool], liveview_pid: self()}
          )

        assign(socket, :agent, agent)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket)
      when message != "" and byte_size(message) <= @max_message_length do
    # Don't process if agent isn't ready yet
    if is_nil(socket.assigns.agent) do
      {:noreply, assign(socket, :error, "Please wait for the chat to initialize...")}
    else
      # Add user message to UI
      user_message = %{role: "user", content: message}

      socket =
        socket
        |> update(:messages, &(&1 ++ [user_message]))
        |> assign(:input_value, "")
        |> assign(:loading, true)
        |> assign(:error, nil)

      # Send to agent asynchronously
      send(self(), {:chat, message})

      {:noreply, socket}
    end
  end

  def handle_event("send_message", %{"message" => message}, socket)
      when byte_size(message) > @max_message_length do
    {:noreply, assign(socket, :error, "Message too long (max #{@max_message_length} characters)")}
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_input", %{"message" => value}, socket) do
    {:noreply, assign(socket, :input_value, value)}
  end

  def handle_event("clear_history", _params, socket) do
    if socket.assigns.agent do
      ConversationAgent.clear_history(socket.assigns.agent)
    end

    {:noreply, assign(socket, :messages, [])}
  end

  def handle_event("send_suggestion", %{"text" => text}, socket) do
    handle_event("send_message", %{"message" => text}, socket)
  end

  @impl true
  def handle_info({:chat, message}, socket) do
    case ConversationAgent.chat_with_tools(socket.assigns.agent, message) do
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
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <div class="flex flex-col h-screen max-w-4xl mx-auto p-4">
        <%!-- Header --%>
        <header class="flex items-center justify-between mb-4 pb-4 border-b border-white/10">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-500 to-fuchsia-500 flex items-center justify-center shadow-lg shadow-violet-500/25">
              <svg
                class="w-6 h-6 text-white"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
            <div>
              <h1 class="text-xl font-semibold text-white">Travel Agent</h1>
              <p class="text-sm text-slate-400">Your AI-powered travel planning assistant</p>
            </div>
          </div>
          <button
            :if={@messages != []}
            phx-click="clear_history"
            class="px-3 py-1.5 text-sm text-slate-400 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
          >
            Clear chat
          </button>
        </header>

        <%!-- Messages Area --%>
        <div
          class="flex-1 overflow-y-auto space-y-4 mb-4 px-2 scrollbar-thin scrollbar-thumb-slate-700 scrollbar-track-transparent"
          id="messages"
          phx-hook="ScrollToBottom"
        >
          <%!-- Empty State --%>
          <%= if @messages == [] and not @loading do %>
            <div class="flex flex-col items-center justify-center h-full text-center px-4">
              <div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-violet-500/20 to-fuchsia-500/20 flex items-center justify-center mb-6 border border-violet-500/30">
                <svg
                  class="w-8 h-8 text-violet-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <h2 class="text-xl font-medium text-white mb-2">Where would you like to go?</h2>
              <p class="text-slate-400 mb-8 max-w-md">
                I can help you plan trips, find destinations, and create memorable travel experiences.
              </p>
              <div class="flex flex-wrap justify-center gap-2">
                <.suggestion_chip text="Plan a beach vacation" />
                <.suggestion_chip text="Suggest mountain destinations" />
                <.suggestion_chip text="Help me with trip planning" />
              </div>
            </div>
          <% end %>

          <%!-- Message Bubbles --%>
          <%= for message <- @messages do %>
            <div class={[
              "flex gap-3",
              if(message.role == "user", do: "flex-row-reverse", else: "flex-row")
            ]}>
              <%!-- Avatar --%>
              <div class={[
                "w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0",
                avatar_classes(message.role)
              ]}>
                <%= if message.role == "user" do %>
                  <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
                  </svg>
                <% else %>
                  <svg
                    class="w-4 h-4 text-white"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                <% end %>
              </div>

              <%!-- Message Content --%>
              <div class={[
                "max-w-[75%] rounded-2xl px-4 py-3",
                message_classes(message.role)
              ]}>
                <div class="prose prose-sm prose-invert max-w-none">
                  {render_content(message)}
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Typing Indicator --%>
          <%= if @loading do %>
            <div class="flex gap-3">
              <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-violet-500 to-fuchsia-500 flex items-center justify-center flex-shrink-0">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <div class="bg-slate-800/50 backdrop-blur border border-slate-700/50 rounded-2xl px-4 py-3">
                <div class="flex items-center gap-1">
                  <div class="w-2 h-2 bg-violet-400 rounded-full animate-bounce [animation-delay:-0.3s]">
                  </div>
                  <div class="w-2 h-2 bg-violet-400 rounded-full animate-bounce [animation-delay:-0.15s]">
                  </div>
                  <div class="w-2 h-2 bg-violet-400 rounded-full animate-bounce"></div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Input Area --%>
        <div class="bg-slate-800/30 backdrop-blur-xl border border-slate-700/50 rounded-2xl p-2">
          <%= if @error do %>
            <p class="text-sm text-red-400 mb-2 px-2">{@error}</p>
          <% end %>
          <form phx-submit="send_message" class="flex items-center gap-2">
            <input
              type="text"
              name="message"
              id="message-input"
              value={@input_value}
              phx-change="update_input"
              phx-hook="FocusInput"
              placeholder="Ask about destinations, travel tips, itineraries..."
              class="flex-1 bg-transparent px-4 py-3 text-white placeholder-slate-500 focus:outline-none"
              autocomplete="off"
              disabled={@loading}
            />
            <button
              type="submit"
              disabled={@loading || @input_value == ""}
              class="p-3 bg-gradient-to-r from-violet-500 to-fuchsia-500 text-white rounded-xl hover:from-violet-600 hover:to-fuchsia-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg shadow-violet-500/25 disabled:shadow-none"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
                />
              </svg>
            </button>
          </form>
          <p class="text-xs text-slate-600 text-center mt-1">Press Enter to send</p>
        </div>
      </div>
    </div>
    """
  end

  # Components

  defp suggestion_chip(assigns) do
    ~H"""
    <button
      phx-click="send_suggestion"
      phx-value-text={@text}
      class="px-4 py-2 bg-slate-800/50 hover:bg-slate-700/50 border border-slate-700/50 hover:border-violet-500/50 text-slate-300 hover:text-white rounded-full text-sm transition-all"
    >
      {@text}
    </button>
    """
  end

  # Styles

  defp avatar_classes("user"), do: "bg-gradient-to-br from-blue-500 to-cyan-500"
  defp avatar_classes("assistant"), do: "bg-gradient-to-br from-violet-500 to-fuchsia-500"
  defp avatar_classes("system"), do: "bg-gradient-to-br from-amber-500 to-orange-500"

  defp message_classes("user") do
    "bg-gradient-to-br from-blue-500 to-cyan-500 text-white"
  end

  defp message_classes("assistant") do
    "bg-slate-800/50 backdrop-blur border border-slate-700/50 text-slate-100"
  end

  defp message_classes("system") do
    "bg-amber-500/20 border border-amber-500/30 text-amber-200"
  end

  # Markdown Rendering

  defp render_content(%{role: "assistant", content: content}) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> Phoenix.HTML.raw(html)
      {:error, _, _} -> content
    end
  end

  defp render_content(%{content: content}), do: content
end
