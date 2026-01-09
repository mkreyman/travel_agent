# Travel Agent

AI-powered travel planning assistant built with Phoenix LiveView and OpenAI GPT-4o.

**Live Demo:** https://travel-agent-ai.fly.dev

## Overview

This project demonstrates building conversational AI agents using Phoenix LiveView with:

- **GenServer-per-conversation** architecture for isolated agent state
- **Tool use pattern** for extensible agent capabilities (OpenAI function calling)
- **Behaviour-based LLM client** for easy testing with Mox
- **Real-time chat UI** with markdown rendering

## Features

- Interactive chat interface with Phoenix LiveView
- OpenAI GPT-4o integration for natural language understanding
- Tool/function calling for destination recommendations
- Markdown rendering for formatted responses
- Real-time "thinking" indicators during AI processing

## Quick Start

```bash
# Clone the repository
git clone https://github.com/mkreyman/travel_agent.git
cd travel_agent

# Install dependencies
mix deps.get

# Set your OpenAI API key
export OPENAI_API_KEY=sk-your-key-here

# Start the server
mix phx.server
```

Visit http://localhost:4000 to start chatting with the travel agent.

## Development

### Prerequisites

- Elixir 1.18.4+
- Erlang/OTP 27.2.4+
- OpenAI API key

### Running Tests

```bash
mix test
```

### Code Quality

```bash
# Format code
mix format

# Run static analysis
mix credo --strict

# Run all quality checks
mix format --check-formatted && mix compile --warnings-as-errors && mix credo --strict && mix test
```

## Architecture

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

### Key Components

- **ConversationAgent** - GenServer managing conversation state and LLM interactions
- **OpenAIClient** - HTTP client for OpenAI Chat Completions API
- **ToolBehaviour** - Extensible pattern for adding agent capabilities
- **ChatLive** - Phoenix LiveView for real-time chat interface

## Deployment

The application is deployed to Fly.io with automatic CI/CD:

- **Push to main/master** triggers tests, then deploys on success
- **Pull requests** run tests only (no deployment)

### Manual Deployment

```bash
fly deploy
```

### Required Secrets

```bash
fly secrets set OPENAI_API_KEY=sk-your-key-here
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
```

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):

1. **Test Job** - Runs on all pushes and PRs
   - Format check (`mix format --check-formatted`)
   - Compilation with warnings as errors
   - Credo static analysis
   - Test suite

2. **Deploy Job** - Runs after successful tests on main/master
   - Deploys to Fly.io using Docker build

## License

MIT
