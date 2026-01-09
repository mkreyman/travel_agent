defmodule TravelAgent.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TravelAgentWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:travel_agent, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TravelAgent.PubSub},
      {Registry, keys: :unique, name: TravelAgent.AgentRegistry},
      {DynamicSupervisor, name: TravelAgent.AgentSupervisor, strategy: :one_for_one},
      TravelAgentWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TravelAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TravelAgentWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
