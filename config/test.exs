import Config

config :travel_agent, TravelAgentWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "test_secret_key_base_needs_to_be_at_least_64_bytes_long_for_security_purposes",
  server: false

# Use mock LLM client in tests
config :travel_agent, :llm_client, TravelAgent.LLM.MockClient

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
