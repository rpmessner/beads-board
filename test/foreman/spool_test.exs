defmodule Foreman.SpoolTest do
  use Foreman.DataCase, async: false
  alias Foreman.{Spool, Overlay, Repo, AgentCommands}

  setup do
    Overlay.backfill("sample", [%{bead_id: "s-1", status: "open", issue_type: "task"}])
    :ok
  end

  defp request(event, payload \\ %{}),
    do: %{
      "request_id" => Ecto.UUID.generate(),
      "action" => "event",
      "repo" => "sample",
      "id" => "s-1",
      "event" => event,
      "payload" => payload
    }

  test "offline events persist then replay exactly once in insertion order" do
    dispatch = request("dispatch", %{"window" => "build"})
    progress = request("progress", %{"body" => "working"})
    assert :ok = Spool.enqueue(dispatch)
    assert :ok = Spool.enqueue(progress)
    assert Repo.aggregate("spooled_events", :count) == 2
    assert :ok = Spool.replay()
    assert :ok = Spool.replay()
    assert Overlay.get({"sample", "s-1"}).stage == :building

    assert Enum.map(Overlay.history({"sample", "s-1"}), & &1.event) == [
             "backfill",
             "dispatch",
             "progress"
           ]

    assert Repo.all(from s in "spooled_events", order_by: s.id, select: s.state) == [
             "applied",
             "applied"
           ]
  end

  test "boot before config or first projection leaves unresolved events pending" do
    command =
      request("dispatch", %{"window" => "startup"})
      |> Map.delete("repo")
      |> Map.put("project", "sample")

    Spool.enqueue(command)
    Spool.replay()
    assert Repo.one(from s in "spooled_events", select: s.state) == "pending"
    assert Overlay.get({"sample", "s-1"}).stage == :queued

    {:ok, config} =
      Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

    config =
      Map.put(config, "repos", [%{"key" => "sample", "path" => "/tmp/sample", "enabled" => true}])

    Repo.insert_all("board_config", [
      %{id: 1, config: config, source: "test", discovered: [], loaded_at: DateTime.utc_now()}
    ])

    Spool.replay()
    assert Overlay.get({"sample", "s-1"}).stage == :dispatched
  end

  test "worker replays on boot and subsequent ticks do not duplicate effects" do
    Spool.enqueue(request("dispatch", %{"window" => "boot"}))
    pid = start_supervised!({Foreman.SpoolWorker, interval: 60_000})
    _ = :sys.get_state(pid)
    assert Overlay.get({"sample", "s-1"}).stage == :dispatched
    send(pid, :replay)
    _ = :sys.get_state(pid)
    assert Enum.map(Overlay.history({"sample", "s-1"}), & &1.event) == ["backfill", "dispatch"]
  end

  test "replay refuses observed events rather than treating them as trusted facts" do
    Spool.enqueue(request("bead_closed"))
    Spool.replay()
    assert Overlay.get({"sample", "s-1"}).stage == :queued
    assert Repo.one(from s in "spooled_events", select: s.state) == "rejected"
  end

  test "request IDs cannot be reused with a different claim" do
    original = request("dispatch", %{"window" => "build"})
    assert {200, _} = AgentCommands.execute(original)

    assert {422, %{error: "request_id_reused"}} =
             AgentCommands.execute(Map.put(original, "event", "abandon"))

    assert Overlay.get({"sample", "s-1"}).stage == :dispatched
  end

  test "lost HTTP response does not duplicate effects on replay; invalid claim is terminal" do
    dispatch = request("dispatch", %{"window" => "build"})
    assert {200, _} = AgentCommands.execute(dispatch)
    Spool.enqueue(dispatch)
    Spool.enqueue(request("commit"))
    Spool.replay()

    assert Enum.map(Overlay.history({"sample", "s-1"}), & &1.event) == [
             "backfill",
             "dispatch",
             "commit"
           ]

    assert Repo.all(from s in "spooled_events", order_by: s.id, select: s.state) == [
             "applied",
             "rejected"
           ]
  end
end
