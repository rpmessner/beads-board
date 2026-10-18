defmodule BoardWeb.InitiativesLiveTest do
  use BoardWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    {:ok, config} =
      Board.Config.parse_layers([{"defaults", File.read!("priv/board.defaults.toml")}])

    config =
      Map.put(config, "repos", [%{"key" => "sample", "path" => "/tmp/sample", "enabled" => true}])

    Board.Repo.insert_all("board_config", [
      %{
        id: 1,
        config: config,
        source: "/tmp/settings",
        discovered: [],
        loaded_at: DateTime.utc_now()
      }
    ])

    rows = [
      b("e", "epic"),
      b("a", "task", [%{depends_on_id: "e", type: "parent-child"}], "closed"),
      Map.put(b("f", "bug", [%{depends_on_id: "a", type: "discovered-from"}]), :labels, [
        "follow-up"
      ]),
      b("o", "chore")
    ]

    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    :ok
  end

  test "home has derived epic progress, expandable fallout and collapsed per-project orphans", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "h1", "Initiatives")
    assert has_element?(view, "a.bb-nav-active[aria-current=page]", "Initiatives")
    assert has_element?(view, "[data-bead=e]", "building")

    assert has_element?(
             view,
             "[data-bead=e] [role=progressbar][aria-valuenow='1'][aria-valuemax='2']"
           )

    refute has_element?(view, "[data-bead=f]")
    view |> element("[data-bead=e] button") |> render_click()
    assert has_element?(view, "#epics h3", "Fallout")
    assert has_element?(view, "[data-bead=f]", "bug")
    assert has_element?(view, "#toggle-unplanned[aria-expanded=false]")
    view |> element("#toggle-unplanned") |> render_click()
    refute has_element?(view, "#unplanned [data-bead=o]")
    view |> element("#toggle-project-sample") |> render_click()
    assert has_element?(view, "#unplanned [data-bead=o]")
  end

  test "filtering children retains full progress and reconciliation refreshes stages", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/")
    view |> form("#initiative-filters", filters: %{type: "bug"}) |> render_change()
    assert has_element?(view, "[data-bead=e] [role=progressbar][aria-valuemax='2']")
    view |> element("[data-bead=e] button") |> render_click()
    assert has_element?(view, "[data-bead=f]")
    refute has_element?(view, "[data-bead=a]")
    Board.Overlay.apply_event({"sample", "f"}, {:cr_opened, %{number: 1}})
    send(view.pid, :reconcile)
    assert has_element?(view, "[data-bead=e]", "shipping")
    assert has_element?(view, "[data-bead=f]", "pr_open")
  end

  test "drafts appear above epics and filters cover status, label, project and stale", %{
    conn: conn
  } do
    Board.Overlay.apply_event(
      {"sample", "draft:next"},
      {:create, %{title: "Next initiative", spec_link: "docs/next.md"}}
    )

    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#drafts [data-bead='draft:next']", "idea")
    assert has_element?(view, "#drafts-panel ~ #epics-panel")
    view |> form("#initiative-filters", filters: %{status: "closed"}) |> render_change()
    refute has_element?(view, "#drafts-panel")
    assert has_element?(view, "[data-bead=e]")
    view |> form("#initiative-filters", filters: %{status: "", stale: "true"}) |> render_change()
    refute has_element?(view, "[data-bead=e]")
    Board.Overlay.apply_event({"sample", "f"}, {:dispatch, %{window: "worker"}})
    Board.Repo.query!("UPDATE sessions SET last_seen_at = NOW() - INTERVAL '3 hours'")
    send(view.pid, :reconcile)
    assert has_element?(view, "[data-bead=e]", "stale")

    view
    |> form("#initiative-filters", filters: %{stale: "false", label: "follow-up"})
    |> render_change()

    refute has_element?(view, "#drafts-panel")
    assert has_element?(view, "[data-bead=e]")

    view
    |> form("#initiative-filters", filters: %{stale: "false", project: "sample"})
    |> render_change()

    assert has_element?(view, "[data-bead=e]")
  end

  test "sub-epics expand independently and contribute to parent totals", %{conn: conn} do
    rows =
      Board.Beads.Projection.list_raw("sample") ++
        [
          b("sub", "epic", [%{depends_on_id: "e", type: "parent-child"}]),
          b("nested", "task", [%{depends_on_id: "sub", type: "parent-child"}])
        ]

    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "[data-bead=e] [aria-valuemax='3']")
    refute has_element?(view, "[data-bead=sub]")
    view |> element("[data-bead=e] button") |> render_click()
    assert has_element?(view, "[data-bead=sub] [aria-valuemax='1']")
    refute has_element?(view, "[data-bead=nested]")
    view |> element("[data-bead=sub] button") |> render_click()
    assert has_element?(view, "[data-bead=nested]")
  end

  test "finished epics are in a collapsed Done group after active epics and before Unplanned", %{
    conn: conn
  } do
    rows =
      Board.Beads.Projection.list_raw("sample") ++
        [
          b("done.10", "epic", [], "closed"),
          b("done.2", "epic", [], "closed"),
          b("shipped", "epic"),
          b("shipped.1", "task", [%{depends_on_id: "shipped", type: "parent-child"}], "closed"),
          b("ticketed", "epic"),
          b("shipping", "epic"),
          b("shipping.1", "task", [%{depends_on_id: "shipping", type: "parent-child"}])
        ]

    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    Board.Overlay.apply_event({"sample", "shipping.1"}, {:cr_opened, %{number: 1}})
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#toggle-done[aria-expanded=false]")
    assert has_element?(view, "#done-count", "3")
    assert has_element?(view, "#epics-panel + #done-panel + #unplanned-panel")
    assert ids(view, "#epics [data-kind=epic]") == ["e", "shipping", "ticketed"]
    refute has_element?(view, "[data-bead='done.2']")
    refute has_element?(view, "[data-bead=shipped]")
    view |> element("#toggle-done") |> render_click()
    assert ids(view, "#done [data-kind=epic]") == ["done.2", "done.10", "shipped"]
    assert has_element?(view, "#done [data-bead='done.2'] .bb-epic-progress", "—")
    refute has_element?(view, "#done [data-bead='done.2'] [role=progressbar]")
    view |> element("#done [data-bead=shipped] button") |> render_click()
    assert has_element?(view, "#done [data-bead='shipped.1']")
    view |> form("#initiative-filters", filters: %{q: "done.2"}) |> render_change()
    assert has_element?(view, "#done-count", "1")
    assert ids(view, "#done [data-kind=epic]") == ["done.2"]
    view |> element("#toggle-done") |> render_click()
    refute has_element?(view, "#done [data-kind=epic]")
  end

  test "observed closure and reopening move an expanded epic between active and Done", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/")
    view |> element("[data-bead=e] button") |> render_click()
    Board.Overlay.apply_event({"sample", "e"}, :bead_epic_closed)
    send(view.pid, :reconcile)
    refute has_element?(view, "#epics [data-bead=e]")
    assert has_element?(view, "#done-count", "1")
    view |> element("#toggle-done") |> render_click()
    assert has_element?(view, "#done [data-bead=e]")
    assert has_element?(view, "#done [data-bead=a]")
    Board.Overlay.apply_event({"sample", "e"}, :bead_epic_reopened)
    send(view.pid, :reconcile)
    assert has_element?(view, "#epics [data-bead=e]")
    assert has_element?(view, "#epics [data-bead=a]")
    assert has_element?(view, "#done-count", "0")
    refute has_element?(view, "#done [data-bead=e]")
  end

  test "an epic without child tickets shows a dash instead of progress", %{conn: conn} do
    rows = Board.Beads.Projection.list_raw("sample") ++ [b("empty", "epic")]
    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "[data-bead=empty] .bb-epic-progress", "—")
    refute has_element?(view, "[data-bead=empty] [role=progressbar]")
    refute has_element?(view, "[data-bead=empty] .bb-epic-progress", "0 / 0")
    refute has_element?(view, "[data-bead=empty] .bb-epic-progress", "%")
    assert has_element?(view, "[data-bead=e] [role=progressbar][aria-valuemax='2']")
  end

  test "persisted board-side links include cross-repo tickets without seeding beads edges", %{
    conn: conn
  } do
    config = Board.RuntimeState.config().config

    config =
      Map.update!(
        config,
        "repos",
        &(&1 ++ [%{"key" => "other", "path" => "/tmp/other", "enabled" => true}])
      )

    Board.Repo.query!("UPDATE board_config SET config = $1 WHERE id = 1", [config])
    Board.Beads.Projection.replace("other", Jason.encode!(b("external", "task")))

    Board.Repo.insert_all("epic_links", [
      %{repo_key: "other", bead_id: "external", epic_repo_key: "sample", epic_bead_id: "e"}
    ])

    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "[data-bead=e] [aria-valuemax='3']")
    view |> element("[data-bead=e] button") |> render_click()
    assert has_element?(view, "[data-bead=external]", "Title external")
    assert [%{"dependencies" => []}] = Board.Beads.Projection.list_raw("other")
  end

  defp ids(view, selector),
    do:
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(selector)
      |> LazyHTML.attribute("data-bead")

  defp b(id, type, edges \\ [], status \\ "open"),
    do: %{id: id, title: "Title #{id}", issue_type: type, status: status, dependencies: edges}
end
