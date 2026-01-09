defmodule TravelAgentWeb.Router do
  use TravelAgentWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {TravelAgentWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", TravelAgentWeb do
    pipe_through(:browser)

    live("/", ChatLive, :index)
  end

  if Application.compile_env(:travel_agent, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: TravelAgentWeb.Telemetry)
    end
  end
end
