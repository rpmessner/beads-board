role = System.fetch_env!("FOREMAN_ROLE")
true = Application.fetch_env!(:foreman, :role) == role
false = Node.alive?()
[] = Node.list()
true = is_pid(Process.whereis(Foreman.Repo))

case role do
  "web" ->
    true = is_pid(Process.whereis(ForemanWeb.Endpoint))
    nil = Process.whereis(Foreman.Runtime)
    nil = Process.whereis(Foreman.Config.Watcher)
    [] = Oban.config().queues
    [] = Oban.config().plugins
    {Oban.Peers.Isolated, [leader?: false]} = Oban.config().peer
    :ok = Foreman.Events.subscribe()
    IO.puts("SMOKE_WEB_READY_NO_WORKERS")

    receive do
      {:notification, :foreman_events, %{"kind" => "sync_status_changed"}} ->
        [_, _] = Foreman.Beads.Projection.list_raw("release-smoke")
        IO.puts("SMOKE_WEB_RECEIVED_SYNC_VIA_POSTGRES")
    after
      30_000 -> raise "worker sync notification did not reach web"
    end

  "worker" ->
    nil = Process.whereis(ForemanWeb.Endpoint)
    nil = System.get_env("SECRET_KEY_BASE")
    true = is_pid(Process.whereis(Foreman.Runtime))
    true = is_pid(Process.whereis(Foreman.Config.Watcher))
    true = Keyword.has_key?(Oban.config().queues, :external_reads)
    IO.puts("SMOKE_WORKER_READY_NO_ENDPOINT_OR_SECRET")
end
