defmodule Board.RoleTest do
  use ExUnit.Case, async: true

  test "web has a Postgres notifier but no queues, plugins or worker leadership" do
    children =
      Board.Role.children("web",
        repo: Board.Repo,
        queues: [external_reads: 4],
        plugins: [Oban.Plugins.Pruner]
      )

    assert BoardWeb.Endpoint in children
    {Oban, opts} = List.keyfind(children, Oban, 0)
    assert opts[:queues] == false
    assert opts[:plugins] == false
    assert opts[:peer] == false
    assert opts[:notifier] == Oban.Notifiers.Postgres
  end

  test "worker runs configured queues without an endpoint; all keeps both" do
    opts = [repo: Board.Repo, queues: [external_reads: 4], plugins: [Oban.Plugins.Pruner]]
    worker = Board.Role.children("worker", opts)
    refute BoardWeb.Endpoint in worker
    {Oban, worker_opts} = List.keyfind(worker, Oban, 0)
    assert worker_opts[:queues] == [external_reads: 4]
    assert worker_opts[:plugins] == [Oban.Plugins.Pruner]
    assert worker_opts[:notifier] == Oban.Notifiers.Postgres
    assert Board.Role.children("all", opts) == worker ++ [BoardWeb.Endpoint]
    refute Board.Role.endpoint?("worker")
    assert Board.Role.endpoint?("web")
  end

  test "unknown roles fail closed instead of enabling all services" do
    assert_raise KeyError, fn -> Board.Role.children("typo", []) end
  end
end
