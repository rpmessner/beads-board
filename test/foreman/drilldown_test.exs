defmodule Foreman.DrilldownTest do
  use Foreman.DataCase, async: false

  setup do
    {:ok, config} =
      Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

    config =
      Map.put(config, "repos", [%{"key" => "sample", "path" => "/tmp/sample", "enabled" => true}])

    Foreman.Repo.insert_all("board_config", [
      %{
        id: 1,
        config: config,
        source: "/tmp/settings",
        discovered: [],
        loaded_at: DateTime.utc_now()
      }
    ])

    rows = [
      %{id: "e", title: "Epic", issue_type: "epic", status: "open"},
      %{
        id: "a",
        title: "Planned",
        issue_type: "task",
        status: "closed",
        dependencies: [%{depends_on_id: "e", type: "parent-child"}]
      },
      %{
        id: "f",
        title: "Fallout",
        issue_type: "bug",
        status: "open",
        description: "Description",
        acceptance_criteria: "Acceptance",
        priority: 1,
        dependencies: [
          %{depends_on_id: "e", type: "parent-child"},
          %{depends_on_id: "a", type: "discovered-from"},
          %{depends_on_id: "a", type: "blocks"}
        ]
      }
    ]

    Foreman.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    %{config: config}
  end

  test "linked drafts keep their original route and full epic history" do
    key = {"sample", "draft:plan"}
    Foreman.Overlay.apply_event(key, {:create, %{title: "Plan"}})
    Foreman.Overlay.apply_event(key, :start_spec)
    Foreman.Overlay.apply_event(key, :approve_spec)
    Foreman.Overlay.apply_event(key, {:ticket, %{beads_epic_id: "e"}})
    epic = Foreman.Drilldown.epic(key)
    assert epic != nil
    assert epic.id == "e"
    assert length(epic.history) == 5
  end

  test "redispatch stays allowed for every existing session window" do
    Foreman.Overlay.apply_event({"sample", "f"}, {:dispatch, %{window: "<new session>"}})
    assert :dispatch in Foreman.Drilldown.ticket({"sample", "f"}).allowed
  end

  test "ticket includes incoming dependencies and board-side epic attachments" do
    Foreman.Repo.insert_all("epic_links", [
      %{repo_key: "sample", bead_id: "a", epic_repo_key: "other", epic_bead_id: "external-epic"}
    ])

    result = Foreman.Drilldown.ticket({"sample", "a"})

    assert Map.get(result, :dependents) == [
             %{key: {"sample", "f"}, type: "discovered-from"},
             %{key: {"sample", "f"}, type: "blocks"}
           ]

    assert Map.get(result, :attachments) == [%{repo: "other", id: "external-epic"}]
  end

  test "configured columns have independent identities even with repeated titles", %{
    config: config
  } do
    config =
      Map.put(config, "columns", [
        %{"title" => "Work", "stages" => ["queued"]},
        %{"title" => "Work", "stages" => ["done"]}
      ])

    Foreman.Repo.query!("UPDATE board_config SET config = $1", [config])
    result = Foreman.Drilldown.epic({"sample", "e"})
    assert result.columns |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 2
  end

  test "ticket includes refused claims, session details, notes, CRs and machine events" do
    key = {"sample", "f"}
    Foreman.Overlay.apply_event(key, :review)
    Foreman.Overlay.apply_event(key, {:dispatch, %{window: "worker", branch: "feature"}})
    Foreman.Overlay.apply_event(key, {:progress, %{body: "Working"}}, %{actor: "agent"})
    result = Foreman.Drilldown.ticket(key)
    assert result != nil
    assert result.raw["description"] == "Description"
    assert result.raw["acceptance_criteria"] == "Acceptance"
    assert result.stage == :building
    assert Enum.map(result.history, & &1.outcome) == ["row", "invalid", "row", "row"]
    assert [session] = result.sessions
    assert session.details["branch"] == "feature"
    assert [note] = result.notes
    assert note.body == "Working"
    assert Enum.sort(result.allowed) == [:abandon, :dispatch, :progress, :report]
    Foreman.Overlay.apply_event(key, {:cr_opened, %{number: 42}})
    assert Foreman.Drilldown.ticket(key).crs == [42]
    assert Foreman.Drilldown.ticket({"sample", "missing"}) == nil
  end

  test "epic columns use config and separate fallout, with directed blockers and own history", %{
    config: config
  } do
    result = Foreman.Drilldown.epic({"sample", "e"})
    assert result != nil
    assert Enum.map(result.columns, & &1.title) == Enum.map(config["columns"], & &1["title"])
    assert Enum.flat_map(result.columns, &Enum.map(&1.planned, fn t -> t.id end)) == ["a"]
    assert Enum.flat_map(result.columns, &Enum.map(&1.fallout, fn t -> t.id end)) == ["f"]
    assert result.edges == [%{from: {"sample", "a"}, to: {"sample", "f"}}]
    assert Enum.map(result.graph.nodes, & &1.key) == [{"sample", "a"}, {"sample", "f"}]
    [blocker, blocked] = result.graph.nodes
    assert blocker.x < blocked.x
    assert blocked.fallout
    assert blocked.title == "Fallout"
    assert Enum.map(result.history, & &1.to_stage) == ["ticketed"]
  end
end
