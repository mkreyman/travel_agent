# Competition Starter Template

Pre-configured Phoenix project for 2-hour competition sprints.

## Quick Start

```bash
# 1. Copy to workspace with your project name
cp -r ~/workspace/.claude/skills/ai-agent-builder/competition-starter ~/workspace/<your_project>

# 2. Run setup script (renames modules, updates configs)
cd ~/workspace/<your_project>
./setup.sh <YourProjectName>

# 3. Verify PLT (should be instant if pre-built)
mix dialyzer

# 4. Start development
mix phx.server
```

## Pre-Built Components

- **Quality Gates**: `mix precommit` alias configured
- **Pre-commit Hook**: Ready to install
- **LLM Client Behaviour**: Mox-ready pattern
- **GenServer Agent**: Conversation agent template
- **LiveView Chat**: Basic chat interface
- **Test Setup**: Mocks and fixtures ready

## Directory Structure

```
lib/template_app/
├── agent/
│   └── conversation_agent.ex    # GenServer with in-memory state
├── llm/
│   ├── client_behaviour.ex      # Behaviour for LLM swapping/mocking
│   └── openai_client.ex         # Default OpenAI implementation
└── context/
    └── simple_memory.ex         # In-memory message list

lib/template_app_web/
└── live/
    └── chat_live.ex             # Single LiveView for chat UI

test/
├── support/
│   ├── mocks.ex                 # Mox definitions
│   └── fixtures.ex              # Test helpers
└── agent/
    └── conversation_agent_test.exs
```

## After Setup

1. Add your OpenAI API key to config/runtime.exs
2. Update the system prompt in `conversation_agent.ex`
3. Implement competition-specific features
4. Run `mix precommit` before every commit

## PLT Status

To build PLT (takes 3-5 minutes, do this BEFORE competition):

```bash
mix deps.get
mix dialyzer --plt
```

The PLT will be cached for instant dialyzer runs during competition.
