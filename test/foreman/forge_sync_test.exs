defmodule Foreman.ForgeSyncTest do
  use Foreman.DataCase, async: false
  alias Foreman.Forge.{SyncJob, Store}

  setup do
    Repo.insert_all("board_config", [
      %{
        id: 1,
        config: %{
          "repos" => [
            %{"key" => "sample", "forge" => "github", "github" => "owner/repo", "enabled" => true}
          ]
        },
        source: "test",
        discovered: [],
        loaded_at: DateTime.utc_now()
      }
    ])

    :ok
  end

  test "failed GraphQL reads retain the good snapshot and back off rate limiting" do
    snapshot = %{"default_branch" => "main", "change_requests" => []}
    fake = start_supervised!({Foreman.Forge.Fake, snapshot})
    assert {:ok, :ok} = SyncJob.sync("sample", Foreman.Forge.Fake, server: fake)

    Repo.update_all("forge_snapshots",
      set: [attempted_at: DateTime.add(DateTime.utc_now(), -121)]
    )

    Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 429, "limited") end)

    assert {:ok, :ok} =
             SyncJob.sync("sample", Foreman.Forge.GitHub,
               token: "test",
               plug: {Req.Test, __MODULE__}
             )

    row = Store.get("sample")
    assert row.snapshot == snapshot
    assert row.error == "rate_limited"
    refute SyncJob.due?(row, true)
    refute SyncJob.due?(row)
  end

  test "manual notifications enqueue one Oban job and cadence ticks share admission" do
    state = %{epoch: "test", schedules: %{}, jobs: %{}}
    event = {:notification, :foreman_events, %{"kind" => "forge_requested", "key" => "sample"}}
    assert {:noreply, ^state} = Foreman.Runtime.handle_info(event, state)
    Foreman.Runtime.handle_info(event, state)

    assert [%{args: %{"key" => "sample", "manual" => true}}] =
             Repo.all(from j in Oban.Job, where: j.worker == "Foreman.Forge.SyncJob")

    Store.replace("sample", "owner/repo", %{"default_branch" => "main", "change_requests" => []})
    refute SyncJob.due?(Store.get("sample"))

    Repo.update_all("forge_snapshots",
      set: [attempted_at: DateTime.add(DateTime.utc_now(), -121)]
    )

    assert SyncJob.due?(Store.get("sample"))
  end

  test "removed configuration cannot publish a late read" do
    Req.Test.stub(__MODULE__, fn conn ->
      Repo.update_all("board_config", set: [config: %{"repos" => []}])
      Req.Test.json(conn, File.read!("test/fixtures/forge/form-engine.json") |> Jason.decode!())
    end)

    SyncJob.sync("sample", Foreman.Forge.GitHub, token: "test", plug: {Req.Test, __MODULE__})
    assert Store.get("sample") == nil
  end
end
