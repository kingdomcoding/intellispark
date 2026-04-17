defmodule Intellispark.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IntellisparkWeb.Telemetry,
      Intellispark.Repo,
      {DNSCluster, query: Application.get_env(:intellispark, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Intellispark.PubSub},
      {Finch, name: Intellispark.Finch},
      {Oban, Application.fetch_env!(:intellispark, Oban)},
      IntellisparkWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Intellispark.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    IntellisparkWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
