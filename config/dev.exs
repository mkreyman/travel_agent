import Config

config :travel_agent, TravelAgentWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_needs_to_be_at_least_64_bytes_long_for_security",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:travel_agent, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:travel_agent, ~w(--watch)]}
  ]

config :travel_agent, TravelAgentWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/travel_agent_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :travel_agent, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
