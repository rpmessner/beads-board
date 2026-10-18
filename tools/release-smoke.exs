role = System.fetch_env!("BOARD_ROLE")
true = Application.fetch_env!(:board, :role) == role
false = Node.alive?()
[] = Node.list()
true = is_pid(Process.whereis(Board.Repo))

case role do
  "web" ->
    true = is_pid(Process.whereis(BoardWeb.Endpoint))
    nil = Process.whereis(Board.Runtime)
    nil = Process.whereis(Board.Config.Watcher)
    [] = Oban.config().queues
    [] = Oban.config().plugins
    {Oban.Peers.Isolated, [leader?: false]} = Oban.config().peer
    :ok = Board.Events.subscribe()
    IO.puts("SMOKE_WEB_READY_NO_WORKERS")

    receive do
      {:notification, :board_events, %{"kind" => "sync_status_changed"}} ->
        [_, _] = Board.Beads.Projection.list_raw("release-smoke")
        IO.puts("SMOKE_WEB_RECEIVED_SYNC_VIA_POSTGRES")
    after
      30_000 -> raise "worker sync notification did not reach web"
    end

  "worker" ->
    nil = Process.whereis(BoardWeb.Endpoint)
    nil = System.get_env("SECRET_KEY_BASE")
    true = is_pid(Process.whereis(Board.Runtime))
    true = is_pid(Process.whereis(Board.Config.Watcher))
    true = Keyword.has_key?(Oban.config().queues, :external_reads)
    IO.puts("SMOKE_WORKER_READY_NO_ENDPOINT_OR_SECRET")
end
