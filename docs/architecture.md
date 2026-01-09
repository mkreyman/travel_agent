# Travel Agent Architecture

Sprint Mode Build - Conversational Travel Planning Agent

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Phoenix Application                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    TravelAgentWeb                         │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │              ChatLive (LiveView)                    │  │  │
│  │  │  - WebSocket connection                             │  │  │
│  │  │  - Message display                                  │  │  │
│  │  │  - User input handling                              │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                      TravelAgent                          │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────┐  │  │
│  │  │ Conversation    │  │   LLM Client    │  │   Tools   │  │  │
│  │  │ Agent           │──│   (OpenAI)      │──│  Registry │  │  │
│  │  │ (GenServer)     │  │                 │  │           │  │  │
│  │  └─────────────────┘  └─────────────────┘  └───────────┘  │  │
│  │          │                                       │        │  │
│  │          │            ┌──────────────────────────┘        │  │
│  │          ▼            ▼                                   │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │                 Available Tools                     │  │  │
│  │  │  - DestinationTool (mock recommendations)           │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Module Structure

```
lib/travel_agent/
├── application.ex              # OTP Application, starts supervision tree
├── agent/
│   └── conversation_agent.ex   # GenServer managing conversation state
├── llm/
│   ├── client_behaviour.ex     # Behaviour for LLM clients (enables Mox)
│   └── openai_client.ex        # OpenAI GPT-4o implementation
└── tools/
    ├── tool_behaviour.ex       # Behaviour for agent tools
    └── destination_tool.ex     # Mock destination recommendations

lib/travel_agent_web/
├── live/
│   └── chat_live.ex            # LiveView chat interface
└── components/
    └── chat_components.ex      # HEEx chat UI components
```

## Data Flow

```
User Input                    Response Display
    │                               ▲
    ▼                               │
┌─────────────────────────────────────────────┐
│              ChatLive                       │
│  handle_event("send_message", ...)          │
└─────────────────────────────────────────────┘
    │                               ▲
    │ ConversationAgent.chat/2      │ {:ok, response}
    ▼                               │
┌─────────────────────────────────────────────┐
│          ConversationAgent                  │
│  1. Add user message to history             │
│  2. Build messages payload                  │
│  3. Call LLM client                         │
│  4. Process tool calls (if any)             │
│  5. Add assistant response to history       │
│  6. Return response                         │
└─────────────────────────────────────────────┘
    │                               ▲
    │ LLMClient.chat/2              │ {:ok, response} | {:tool_call, ...}
    ▼                               │
┌─────────────────────────────────────────────┐
│            OpenAI Client                    │
│  - POST /v1/chat/completions                │
│  - Includes tool definitions                │
│  - Handles tool_calls in response           │
└─────────────────────────────────────────────┘
```

### Tool Execution Flow

When LLM requests a tool call:

1. LLM returns `tool_calls` in response
2. ConversationAgent looks up tool module
3. Tool.execute/1 called with arguments
4. Tool result added to messages as `tool` role
5. LLM called again with tool result
6. Final response returned to user

## In-Memory State Design

### ConversationAgent State

```elixir
%{
  conversation_id: String.t(),
  messages: [
    %{role: "system", content: String.t()},
    %{role: "user", content: String.t()},
    %{role: "assistant", content: String.t()},
    %{role: "assistant", content: nil, tool_calls: [...]},
    %{role: "tool", tool_call_id: String.t(), content: String.t()}
  ],
  system_prompt: String.t(),
  tools: [module()]  # [TravelAgent.Tools.DestinationTool]
}
```

### ChatLive Assigns

```elixir
%{
  conversation_id: String.t(),
  messages: [%{role: String.t(), content: String.t()}],  # Display only
  form: Phoenix.HTML.Form.t(),
  loading: boolean()
}
```

## Key Patterns

### GenServer-per-Conversation

Each conversation spawns its own GenServer process:

```elixir
# Start conversation
{:ok, pid} = ConversationAgent.start_link(conversation_id: "uuid-here")

# Or use Registry for named lookup
ConversationAgent.start_link(conversation_id: id, name: via_tuple(id))
```

### Behaviour-Based LLM Client

Enables testing with Mox:

```elixir
# lib/travel_agent/llm/client_behaviour.ex
defmodule TravelAgent.LLM.ClientBehaviour do
  @callback chat(messages :: list(), opts :: keyword()) ::
    {:ok, String.t()} | {:tool_calls, list()} | {:error, term()}
end

# config/test.exs
config :travel_agent, :llm_client, TravelAgent.LLM.MockClient

# config/runtime.exs
config :travel_agent, :llm_client, TravelAgent.LLM.OpenAIClient
```

### Config-Based Dependency Injection

```elixir
defmodule TravelAgent.Agent.ConversationAgent do
  defp llm_client do
    Application.get_env(:travel_agent, :llm_client, TravelAgent.LLM.OpenAIClient)
  end
end
```

### Tool Behaviour

```elixir
defmodule TravelAgent.Tools.ToolBehaviour do
  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameters() :: map()  # JSON Schema
  @callback execute(args :: map()) :: {:ok, String.t()} | {:error, term()}
end
```

## Supervision Tree

```
TravelAgent.Application
└── TravelAgent.Supervisor (one_for_one)
    ├── Registry (for ConversationAgent lookup)
    ├── DynamicSupervisor (for ConversationAgent processes)
    └── TravelAgentWeb.Endpoint
```

## Configuration

### Required Environment Variables

```
OPENAI_API_KEY=sk-...
```

### Application Config

```elixir
# config/config.exs
config :travel_agent,
  llm_client: TravelAgent.LLM.OpenAIClient,
  llm_model: "gpt-4o",
  system_prompt: "You are a friendly travel expert..."
```

## Testing Strategy

- **ConversationAgent**: Unit tests with Mox for LLM client
- **OpenAI Client**: Integration tests (optional, behind flag)
- **Tools**: Unit tests with mock data verification
- **ChatLive**: LiveView tests with stubbed ConversationAgent
