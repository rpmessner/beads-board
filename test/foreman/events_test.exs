defmodule Foreman.EventsTest do
  use ExUnit.Case, async: false

  test "worker invalidations arrive through Postgres at an independent web notifier" do
    start_supervised!(
      {Oban,
       name: Foreman.EventsTest.Web,
       repo: Foreman.Repo,
       testing: :manual,
       notifier: {Oban.Notifiers.Postgres, sync_connect: true}}
    )

    assert :ok = Foreman.Events.subscribe(Foreman.EventsTest.Web)
    key = "repo-#{System.unique_integer([:positive])}"

    connection = start_supervised!({Postgrex.Notifications, Foreman.Repo.config()})
    {:ok, ref} = Postgrex.Notifications.listen(connection, "public.oban_foreman_events")

    for kind <- [:projection_changed, :sync_status_changed, :config_changed] do
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Foreman.Repo, fn ->
        assert :ok = Foreman.Events.broadcast(kind, key)
      end)

      wire_kind = Atom.to_string(kind)

      assert_receive {:notification, :foreman_events,
                      %{"version" => 1, "kind" => ^wire_kind, "key" => ^key}},
                     2_000

      assert_receive {:notification, ^connection, ^ref, "public.oban_foreman_events", _}, 2_000
    end
  end

  test "projection changes notify after commit, but unchanged exports do not" do
    key = "projection-notify-#{System.unique_integer([:positive])}"
    assert :ok = Foreman.Events.subscribe()

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Foreman.Repo, fn ->
        Foreman.Repo.query!("DELETE FROM bead_repos WHERE key = $1", [key])
      end)
    end)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Foreman.Repo, fn ->
      assert {:ok, :changed} = Foreman.Beads.Projection.replace(key, "")
    end)

    assert_receive {:notification, :foreman_events,
                    %{"kind" => "projection_changed", "key" => ^key}},
                   2_000

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Foreman.Repo, fn ->
      assert {:ok, :unchanged} = Foreman.Beads.Projection.replace(key, "")
    end)

    refute_receive {:notification, :foreman_events, %{"key" => ^key}}
  end

  test "rolled-back data cannot send an invalidation" do
    assert :ok = Foreman.Events.subscribe()
    key = "rollback-#{System.unique_integer([:positive])}"

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Foreman.Repo, fn ->
      assert {:error, :aborted} =
               Foreman.Repo.transaction(fn ->
                 :ok = Foreman.Events.broadcast(:projection_changed, key)
                 Foreman.Repo.rollback(:aborted)
               end)
    end)

    refute_receive {:notification, :foreman_events, %{"key" => ^key}}
    assert :ok = Foreman.Events.unsubscribe()
  end
end
