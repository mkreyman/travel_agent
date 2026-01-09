ExUnit.start(capture_log: true)

# Configure app to use mock LLM client in tests
Application.put_env(:travel_agent, :llm_client, TravelAgent.LLM.MockClient)
