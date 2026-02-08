defmodule Oaks.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OaksWeb.Telemetry,
      Oaks.Repo,
      {DNSCluster, query: Application.get_env(:oaks, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Oaks.PubSub},
      # Start a worker by calling: Oaks.Worker.start_link(arg)
      # {Oaks.Worker, arg},
      # Start to serve requests, typically the last entry
      OaksWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Oaks.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OaksWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
