defmodule Board.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BoardWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:board, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Board.PubSub},
      # Start a worker by calling: Board.Worker.start_link(arg)
      # {Board.Worker, arg},
      # Start to serve requests, typically the last entry
      BoardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    children =
      if Application.get_env(:board, :start_repo, true),
        do: [Board.Repo | children],
        else: children

    opts = [strategy: :one_for_one, name: Board.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
