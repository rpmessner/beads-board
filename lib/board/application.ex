defmodule Board.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    role = Application.fetch_env!(:board, :role)

    children =
      [
        BoardWeb.Telemetry,
        {Phoenix.PubSub, name: Board.PubSub},
        Board.Repo
      ] ++ Board.Role.children(role, Application.fetch_env!(:board, Oban))

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Board.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    if Board.Role.endpoint?(Application.fetch_env!(:board, :role)) do
      BoardWeb.Endpoint.config_change(changed, removed)
    end

    :ok
  end
end
