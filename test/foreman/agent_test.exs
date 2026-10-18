defmodule Foreman.AgentTest do
  use Foreman.DataCase, async: false
  alias Foreman.{Agent, Overlay, Repo}

  setup do
    Overlay.backfill("sample", [
      %{bead_id: "s-1", status: "open", issue_type: "task"},
      %{bead_id: "s-e", status: "open", issue_type: "epic"}
    ])

    :ok
  end

  test "unknown ticket gets exactly one forced read before 404" do
    parent = self()
    Application.put_env(:foreman, :agent_sync, fn repo -> send(parent, {:sync, repo}) end)
    on_exit(fn -> Application.delete_env(:foreman, :agent_sync) end)

    assert {404, %{error: "not_found"}} =
             Agent.event("sample", "s-missing", %{"event" => "review"})

    assert_received {:sync, "sample"}
    refute_received {:sync, _}
  end

  test "missing epic target is a payload error, not an out-of-order claim" do
    key = {"sample", "draft:plan"}
    Overlay.apply_event(key, {:create, %{title: "Plan"}})
    Overlay.apply_event(key, :start_spec)
    Overlay.apply_event(key, :approve_spec)

    assert {422, %{error: "beads_epic_required"}} =
             Agent.event("sample", "draft:plan", %{"event" => "ticket"})

    Application.put_env(:foreman, :agent_sync, fn _ -> :ok end)
    on_exit(fn -> Application.delete_env(:foreman, :agent_sync) end)

    assert {404, _} =
             Agent.event("sample", "draft:plan", %{
               "event" => "ticket",
               "payload" => %{"beads_epic_id" => "s-missing"}
             })

    assert Overlay.get(key).stage == :spec_approved
  end

  test "approving a draft without a new spec link preserves its existing link" do
    assert {200, _} =
             Agent.event("sample", "draft:spec", %{
               "event" => "create",
               "payload" => %{"title" => "Spec", "spec_link" => "docs/spec.md"}
             })

    Agent.event("sample", "draft:spec", %{"event" => "start_spec"})
    Agent.event("sample", "draft:spec", %{"event" => "approve_spec"})
    assert Overlay.get({"sample", "draft:spec"}).spec_link == "docs/spec.md"
  end

  test "draft events work through the same claim-only API" do
    for {event, payload, stage} <- [
          {"create", %{"title" => "New thing"}, :idea},
          {"start_spec", %{}, :speccing},
          {"approve_spec", %{"spec_link" => "docs/spec.md"}, :spec_approved},
          {"abandon", %{}, :abandoned},
          {"revive", %{}, :idea},
          {"start_spec", %{}, :speccing},
          {"approve_spec", %{}, :spec_approved},
          {"ticket", %{"beads_epic_id" => "s-e"}, :ticketed}
        ] do
      assert {200, %{stage: ^stage}} =
               Agent.event("sample", "draft:idea", %{"event" => event, "payload" => payload})
    end
  end

  test "attachments to a draft stay visible after it is ticketed" do
    {:ok, config} =
      Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

    config =
      Map.put(config, "repos", [%{"key" => "sample", "path" => "/tmp/sample", "enabled" => true}])

    Repo.insert_all("board_config", [
      %{id: 1, config: config, source: "test", discovered: [], loaded_at: DateTime.utc_now()}
    ])

    rows = [
      %{id: "s-1", title: "Ticket", issue_type: "task", status: "open"},
      %{id: "s-e", title: "Epic", issue_type: "epic", status: "open"}
    ]

    Foreman.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    key = {"sample", "draft:plan"}
    Overlay.apply_event(key, {:create, %{title: "Plan"}})
    Agent.link({"sample", "s-1"}, key, "attach")
    Overlay.apply_event(key, :start_spec)
    Overlay.apply_event(key, :approve_spec)
    Overlay.apply_event(key, {:ticket, %{beads_epic_id: "s-e"}})
    assert Foreman.Drilldown.epic(key).total == 1
    Agent.link({"sample", "s-1"}, {"sample", "s-e"}, "detach")
    assert Foreman.Drilldown.epic(key).total == 0
  end

  test "attach and detach cross-repo tickets use only board-side links" do
    Overlay.backfill("other", [%{bead_id: "o-e", status: "open", issue_type: "epic"}])
    assert {200, _} = Agent.link({"sample", "s-1"}, {"other", "o-e"}, "attach")
    assert {200, _} = Agent.link({"sample", "s-1"}, {"other", "o-e"}, "attach")
    assert Repo.aggregate("epic_links", :count) == 1
    assert {422, _} = Agent.link({"sample", "s-e"}, {"other", "o-e"}, "attach")
    assert {422, _} = Agent.link({"sample", "s-1"}, {"sample", "s-1"}, "attach")
    assert {200, _} = Agent.link({"sample", "s-1"}, {"other", "o-e"}, "detach")
    assert Repo.aggregate("epic_links", :count) == 0
  end
end
