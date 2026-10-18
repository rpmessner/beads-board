defmodule Foreman.RoleTest do
  use ExUnit.Case, async: true

  test "web has a Postgres notifier but no queues, plugins or worker leadership" do
    children =
      Foreman.Role.children("web",
        repo: Foreman.Repo,
        queues: [external_reads: 4],
        plugins: [Oban.Plugins.Pruner]
      )

    assert ForemanWeb.Endpoint in children
    {Oban, opts} = List.keyfind(children, Oban, 0)
    assert opts[:queues] == false
    assert opts[:plugins] == false
    assert opts[:peer] == false
    assert opts[:notifier] == Oban.Notifiers.Postgres
  end

  test "worker runs configured queues without an endpoint; all keeps both" do
    opts = [repo: Foreman.Repo, queues: [external_reads: 4], plugins: [Oban.Plugins.Pruner]]
    worker = Foreman.Role.children("worker", opts)
    refute ForemanWeb.Endpoint in worker
    {Oban, worker_opts} = List.keyfind(worker, Oban, 0)
    assert worker_opts[:queues] == [external_reads: 4]
    assert worker_opts[:plugins] == [Oban.Plugins.Pruner]
    assert worker_opts[:notifier] == Oban.Notifiers.Postgres
    assert Foreman.Role.children("all", opts) == worker ++ [ForemanWeb.Endpoint]
    refute Foreman.Role.endpoint?("worker")
    assert Foreman.Role.endpoint?("web")
  end

  test "unknown roles fail closed instead of enabling all services" do
    assert_raise KeyError, fn -> Foreman.Role.children("typo", []) end
  end

  test "the shipped worker config rescues jobs orphaned by a killed worker" do
    plugins = Config.Reader.read!("config/config.exs", env: :prod)[:foreman][Oban][:plugins]
    {Oban.Plugins.Lifeline, opts} = List.keyfind(plugins, Oban.Plugins.Lifeline, 0)

    # Above every job timeout, so a running job is never rescued mid-flight.
    assert opts[:rescue_after] > Foreman.Merge.MergeJob.timeout(%Oban.Job{})
  end
end
