defmodule Foreman.Role do
  @moduledoc """
  Static deployment roles for a single release; no Erlang clustering required.
  Both roles keep Repo and Oban's Postgres notifier. Only worker/all execute jobs.
  Future scheduler and watcher children belong in `worker_children/0`, not in
  the application's common child list.
  """

  @roles %{
    "web" => %{endpoint: true, worker: false},
    "worker" => %{endpoint: false, worker: true},
    "all" => %{endpoint: true, worker: true}
  }

  def children(role, oban) do
    settings = Map.fetch!(@roles, role)
    oban = Keyword.put(oban, :notifier, Oban.Notifiers.Postgres)

    oban =
      if settings.worker,
        do: oban,
        else: Keyword.merge(oban, queues: false, plugins: false, peer: false)

    [{Oban, oban}] ++
      if(settings.worker, do: worker_children(), else: []) ++
      if(settings.endpoint, do: [ForemanWeb.Endpoint], else: [])
  end

  def endpoint?(role), do: Map.fetch!(@roles, role).endpoint

  defp worker_children do
    if Application.get_env(:foreman, :runtime_enabled, true),
      do: [
        Foreman.Forge.Credentials,
        Foreman.Runtime,
        Foreman.Config.Watcher,
        Foreman.SpoolWorker,
        Foreman.SessionMonitor,
        Foreman.Previews.Poller
      ],
      else: []
  end
end
