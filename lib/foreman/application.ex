defmodule Foreman.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    role = Application.fetch_env!(:foreman, :role)

    children =
      [
        ForemanWeb.Telemetry,
        {Phoenix.PubSub, name: Foreman.PubSub},
        Foreman.Repo
      ] ++ Foreman.Role.children(role, Application.fetch_env!(:foreman, Oban))

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Foreman.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    if Foreman.Role.endpoint?(Application.fetch_env!(:foreman, :role)) do
      ForemanWeb.Endpoint.config_change(changed, removed)
    end

    :ok
  end
end
