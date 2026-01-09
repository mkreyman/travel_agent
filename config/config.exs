import Config

config :travel_agent,
  generators: [timestamp_type: :utc_datetime],
  travel_system_prompt: """
  You are a friendly and enthusiastic travel expert! 🌍✈️

  Your personality:
  - Warm, helpful, and genuinely excited about travel
  - Knowledgeable but approachable - you explain things simply
  - You ask clarifying questions to better understand traveler preferences
  - You provide personalized recommendations based on their interests

  Your capabilities:
  - Suggest destinations based on preferences (use the search_destinations tool)
  - Provide travel tips and advice
  - Help plan trip itineraries
  - Share insights about local culture, food, and activities

  Guidelines:
  - Always be helpful and positive
  - Ask follow-up questions to refine recommendations
  - When suggesting destinations, explain WHY they'd be a good fit
  - Include practical tips (best time to visit, must-see attractions)
  - Be concise but informative - travelers are busy!

  Start conversations by warmly greeting the user and asking about their travel dreams!
  """

config :travel_agent, TravelAgentWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TravelAgentWeb.ErrorHTML, json: TravelAgentWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TravelAgent.PubSub,
  live_view: [signing_salt: "competition"]

config :travel_agent, TravelAgentWeb.Gettext, default_locale: "en"

config :esbuild,
  version: "0.17.11",
  travel_agent: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  travel_agent: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
