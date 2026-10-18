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

  test "ticket rows open a URL sheet and closing retains filters and expansion", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?project=sample&type=bug")
    view |> element("[data-bead=e] button") |> render_click()
    view |> element("[data-bead=f] a") |> render_click()
    path = assert_patch(view)
    assert URI.decode_query(URI.parse(path).query)["ticket"] == "sample:f"
    assert has_element?(view, "#ticket-sheet[data-open=true]")
    assert has_element?(view, "#ticket-title", "f")
    assert has_element?(view, "#ticket-actions")
    view |> element("#ticket-close") |> render_click()
    closed = assert_patch(view)
    assert URI.decode_query(URI.parse(closed).query)["type"] == "bug"
    refute has_element?(view, "#ticket-sheet[data-open=true]")
    assert has_element?(view, "[data-bead=f]")
  end

  test "direct sheet URLs and live updates retain their underlying page", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?ticket=sample:f&project=sample")
    assert has_element?(view, "#ticket-stage", "queued")
    Board.Overlay.apply_event({"sample", "f"}, :review)
    Board.Overlay.apply_event({"sample", "f"}, {:dispatch, %{window: "worker"}})
    send(view.pid, {:notification, :board_events, "sample/f"})
    assert has_element?(view, "#ticket-stage", "dispatched")
    assert has_element?(view, "#ticket-history [data-outcome=invalid]", "review")
    assert has_element?(view, "#ticket-sessions", "worker")
    render_patch(view, "/?project=sample")
    refute has_element?(view, "#ticket-sheet[data-open=true]")
    render_patch(view, "/?ticket=sample:f&project=sample")
    assert has_element?(view, "#ticket-sheet[data-open=true]")
  end

  test "epic route shows columns, fallout, history and opens a sheet", %{conn: conn} do
    {:ok, view, _} = live(conn, "/epics/sample/e?type=bug")
    assert has_element?(view, "#epic-title", "e")
    assert has_element?(view, "#epic-history", "backfill")
    assert has_element?(view, "[data-band=planned] [data-ticket=a]")
    assert has_element?(view, "[data-band=fallout] [data-ticket=f]")
    view |> element("[data-band=fallout] [data-ticket=f]") |> render_click()
    assert_patch(view, "/epics/sample/e?ticket=sample%3Af&type=bug")
    assert has_element?(view, "#ticket-sheet[data-open=true]")
    view |> element("#ticket-close") |> render_click()
    assert_patch(view, "/epics/sample/e?type=bug")
    Board.Overlay.apply_event({"sample", "f"}, {:dispatch, %{window: "worker"}})
    send(view.pid, {:notification, :board_events, "sample/f"})
    assert has_element?(view, "[data-band=fallout] [data-stage=dispatched]")
  end

  test "epic title navigation carries filters and missing routes stay usable", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?project=sample&type=bug")
    view |> element("[data-bead=e] a") |> render_click()
    assert_redirect(view, "/epics/sample/e?project=sample&type=bug")
    {:ok, missing, _} = live(conn, "/epics/sample/missing?ticket[]=bad")
    assert has_element?(missing, "#epic-not-found")
    refute has_element?(missing, "#ticket-sheet[data-open=true]")
  end

  test "epic config and own history refresh while a sheet is open", %{conn: conn} do
    {:ok, view, _} = live(conn, "/epics/sample/e?ticket=sample:f")

    config =
      Board.RuntimeState.config().config
      |> Map.put("columns", [%{"title" => "Everything", "stages" => ["queued", "done"]}])

    Board.Repo.query!("UPDATE board_config SET config = $1", [config])
    Board.Overlay.apply_event({"sample", "e"}, :bead_epic_closed)
    send(view.pid, {:notification, :board_events, "sample/e"})
    assert has_element?(view, "#epic-columns h3", "Everything")
    assert has_element?(view, "#epic-history", "bead_epic_closed")
    assert has_element?(view, "#ticket-sheet[data-open=true]")

    rows =
      Board.Beads.Projection.list_raw("sample")
      |> Enum.map(fn raw ->
        if raw["id"] == "f", do: Map.put(raw, "title", "Updated fallout"), else: raw
      end)

    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    send(view.pid, {:notification, :board_events, "sample"})
    assert has_element?(view, "#ticket-title", "Updated fallout")
    assert has_element?(view, "[data-ticket=f]", "Updated fallout")
  end

  test "a late close callback cannot dismiss a different selected ticket", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?ticket=sample:f")
    render_patch(view, "/?ticket=sample:a")
    render_click(view, "close-ticket", %{"key" => "sample:f"})
    assert has_element?(view, "#ticket-title", "Title a")
    assert has_element?(view, "#ticket-sheet[data-open=true]")
  end

  test "history uses relative time, human payload fields and only refusal badges", %{conn: conn} do
    Board.Overlay.apply_event({"sample", "f"}, :review, %{actor: "reviewer"})

    Board.Overlay.apply_event(
      {"sample", "f"},
      {:dispatch,
       %{
         window: "worker",
         branch: "feature",
         brief_path: "docs/brief.md",
         internal_token: "hidden-detail"
       }},
      %{actor: "builder"}
    )

    Board.Overlay.apply_event(
      {"sample", "f"},
      {:report, %{path: "docs/report.md", body: "Verified result"}}
    )

    Board.Repo.query!(
      "UPDATE stage_events SET inserted_at = NOW() - INTERVAL '2 hours 5 seconds'"
    )

    {:ok, view, _} = live(conn, "/epics/sample/e?ticket=sample:f")
    assert has_element?(view, "#epic-history time[title][datetime]", "2 h ago")
    assert has_element?(view, "#ticket-history time[title][datetime]", "2 h ago")
    assert has_element?(view, "#ticket-sessions time[title][datetime]")
    assert has_element?(view, "#ticket-history [data-outcome=invalid]", "Refused")
    assert has_element?(view, "#ticket-history [data-outcome=row]", "feature")
    assert has_element?(view, "#ticket-history [data-outcome=row]", "docs/brief.md")
    assert has_element?(view, "#ticket-history [data-outcome=row]", "builder")
    assert has_element?(view, "#ticket-history dt", "Report")
    assert has_element?(view, "#ticket-history dd", "docs/report.md")
    assert has_element?(view, "#ticket-history dd", "Verified result")
    refute has_element?(view, "#ticket-history [data-outcome=row] [data-history-outcome]")
    refute has_element?(view, "#ticket-history", "hidden-detail")
    refute has_element?(view, "#ticket-history", "record: session")
    refute has_element?(view, "#ticket-history", "emit: stage")
  end

  test "fallout omits empty cells and disappears after the last fallout edge is removed", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/epics/sample/e")

    assert view
           |> render()
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("[data-band=fallout]")
           |> Enum.count() == 1

    rows =
      Board.Beads.Projection.list_raw("sample")
      |> Enum.map(fn raw ->
        if raw["id"] == "f", do: Map.put(raw, "dependencies", []), else: raw
      end)

    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    send(view.pid, {:notification, :board_events, "sample"})
    refute has_element?(view, "[data-band=fallout]")
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

    view |> element("#sidebar-project-sample") |> render_click()

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
    {:ok, view, _} = live(conn, "/?view=all")
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
    {:ok, view, _} = live(conn, "/?view=all")
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

  test "URL filters populate controls and changes patch a shareable URL", %{conn: conn} do
    {:ok, view, _} =
      live(conn, "/?project=sample&type=bug&label=follow-up&status=open&q=Title&stale=false")

    assert has_element?(view, "#filters_type option[value=bug][selected]")
    assert has_element?(view, "#sidebar-project-sample.bb-nav-active")
    assert has_element?(view, "#filters_q[value=Title]")
    view |> form("#initiative-filters", filters: %{q: "a & b"}) |> render_change()
    path = assert_patch(view)
    assert URI.decode_query(URI.parse(path).query)["q"] == "a & b"
    assert URI.decode_query(URI.parse(path).query)["type"] == "bug"
  end

  test "returning from Settings restores this browser's filters", %{conn: conn} do
    remembered = %{
      "project" => "sample",
      "type" => "bug",
      "label" => "follow-up",
      "status" => "open",
      "q" => "Title",
      "stale" => "false"
    }

    {:ok, settings, _} = live(conn, "/settings")

    assert {:error, {:live_redirect, %{to: "/"}}} =
             settings |> element("a", "Initiatives") |> render_click()

    {:ok, view, _} = live(put_connect_params(conn, %{"initiative_filters" => remembered}), "/")
    assert has_element?(view, "#filters_type option[value=bug][selected]")

    for {key, value} <- Map.drop(remembered, ["q", "stale", "project"]) do
      assert has_element?(view, "#filters_#{key} option[value='#{value}'][selected]")
    end

    assert has_element?(view, "#initiative-filter-memory[data-filters]")
    render_patch(view, "/")
    refute has_element?(view, "#sidebar-project-sample.bb-nav-active")
    assert has_element?(view, "#filters_type option[value=''][selected]")
  end

  test "explicit URLs override remembered filters, including an explicit clear", %{conn: conn} do
    conn =
      put_connect_params(conn, %{
        "initiative_filters" => %{"project" => "sample", "type" => "bug"}
      })

    {:ok, view, _} = live(conn, "/?project=")
    refute has_element?(view, "#sidebar-project-sample.bb-nav-active")
    assert has_element?(view, "#filters_type option[value=''][selected]")
  end

  test "malformed and unknown URL values fall back to defaults", %{conn: conn} do
    {:ok, view, _} =
      live(conn, "/?project[]=sample&type=invalid&label[bad]=x&status=no&stale=yes&q[]=bad")

    for key <- ~w(type label status) do
      assert has_element?(view, "#filters_#{key} option[value=''][selected]")
    end

    assert has_element?(view, "#filters_q[value='']")
    refute has_element?(view, "#filters_stale[checked]")
    assert has_element?(view, "[data-bead=e]")
  end

  test "sidebar project patches and toggles without losing other filters or counts", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?type=bug")
    assert has_element?(view, "#sidebar-project-sample", "4")
    view |> element("#sidebar-project-sample") |> render_click()
    assert URI.decode_query(URI.parse(assert_patch(view)).query)["project"] == "sample"
    assert has_element?(view, "#sidebar-project-sample.bb-nav-active[aria-current=true]")
    assert has_element?(view, "#filters_type option[value=bug][selected]")
    assert has_element?(view, "#sidebar-project-sample", "4")
    view |> element("#sidebar-project-sample") |> render_click()
    assert URI.decode_query(URI.parse(assert_patch(view)).query)["project"] == ""
    refute has_element?(view, "#sidebar-project-sample.bb-nav-active")
    assert has_element?(view, "#filters_type option[value=bug][selected]")
  end

  test "Settings sidebar navigates to an explicit project filter", %{conn: conn} do
    {:ok, view, _} = live(conn, "/settings")
    assert has_element?(view, "#sidebar-project-sample", "4")

    assert {:error, {:live_redirect, %{to: path}}} =
             view |> element("#sidebar-project-sample") |> render_click()

    assert URI.decode_query(URI.parse(path).query)["project"] == "sample"
    {:ok, initiatives, _} = live(conn, path)
    assert has_element?(initiatives, "#sidebar-project-sample.bb-nav-active")
  end

  test "initial URL filters exclude nonmatching streamed rows", %{conn: conn} do
    Board.Beads.Projection.replace(
      "sample",
      Enum.map_join([b("e", "epic"), b("excluded", "epic")], "\n", &Jason.encode!/1)
    )

    {:ok, filtered, _} = live(conn, "/?q=Title+excluded")
    assert has_element?(filtered, "#epics [data-bead=excluded]")
    refute has_element?(filtered, "#epics [data-bead=e]")
  end

  test "curated views default to Open and selection patches while retaining search and project",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#view-open[aria-pressed=true][type=button]")
    assert has_element?(view, "#initiative-filters[phx-submit=filter]")
    assert has_element?(view, "#view-in-flight")
    assert has_element?(view, "#view-stale")
    assert has_element?(view, "#view-all")
    render_patch(view, "/?view=open&project=sample&q=Title")
    assert_patch(view)
    view |> element("#view-in-flight") |> render_click()
    params = URI.decode_query(URI.parse(assert_patch(view)).query)
    assert params["view"] == "in-flight"
    assert params["project"] == "sample"
    assert params["q"] == "Title"
    refute has_element?(view, "[data-bead=e]")
    Board.Overlay.apply_event({"sample", "f"}, {:dispatch, %{window: "worker"}})
    send(view.pid, :reconcile)
    assert has_element?(view, "[data-bead=e]")
    view |> element("[data-bead=e] button") |> render_click()
    assert has_element?(view, "[data-bead=f]")
    refute has_element?(view, "[data-bead=a]")
    view |> element("#view-all") |> render_click()
    assert has_element?(view, "[data-bead=a]")
  end

  test "Filters starts closed, counts only advanced overrides and remembers disclosure independently",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/?view=open&type=bug&label=follow-up&q=Title&project=sample")
    assert has_element?(view, "#toggle-filters[aria-expanded=false]")
    assert has_element?(view, "#advanced-filters[hidden]")
    assert has_element?(view, "#advanced-filter-count", "2")
    refute has_element?(view, "#filters_project")
    view |> element("#toggle-filters") |> render_click()
    assert has_element?(view, "#toggle-filters[aria-expanded=true]")
    refute has_element?(view, "#advanced-filters[hidden]")
    refute has_element?(view, "#advanced-filter-count")
    assert has_element?(view, "#initiative-filter-memory[data-filters-open=true]")
    view |> element("#view-stale") |> render_click()
    assert has_element?(view, "#toggle-filters[aria-expanded=true]")

    {:ok, returned, _} =
      live(put_connect_params(conn, %{"initiative_filters_open" => "true"}), "/?view=all")

    assert has_element?(returned, "#toggle-filters[aria-expanded=true]")
    {:ok, corrupt, _} = live(put_connect_params(conn, %{"initiative_filters_open" => "bad"}), "/")
    assert has_element?(corrupt, "#toggle-filters[aria-expanded=false]")
    refute has_element?(corrupt, "#advanced-filter-count")
  end

  test "legacy URLs remain unscoped and explicit overrides beat a view", %{conn: conn} do
    rows = Board.Beads.Projection.list_raw("sample") ++ [b("closed", "epic", [], "closed")]
    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    {:ok, legacy, _} = live(conn, "/?status=closed")
    refute has_element?(legacy, "#initiative-views [aria-pressed=true]")
    assert has_element?(legacy, "#done-count", "1")
    {:ok, explicit, _} = live(conn, "/?view=open&status=closed")
    assert has_element?(explicit, "#done-count", "1")
    assert has_element?(explicit, "#advanced-filter-count", "1")
    {:ok, all, _} = live(conn, "/?view=open&status=all")
    assert has_element?(all, "#done-count", "1")
    {:ok, unknown, _} = live(conn, "/?view=missing")
    assert has_element?(unknown, "#view-open[aria-pressed=true]")
    assert has_element?(unknown, "#done-count", "0")
  end

  test "reload updates curated buttons and resolves a removed selection to the new default", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/?view=in-flight")
    config = Board.RuntimeState.config().config
    config = Map.put(config, "views", [%{"key" => "everything", "title" => "Everything"}])
    Board.Repo.query!("UPDATE board_config SET config = $1 WHERE id = 1", [config])
    send(view.pid, :reconcile)
    assert has_element?(view, "#view-everything[aria-pressed=true]", "Everything")
    refute has_element?(view, "#view-in-flight")
    assert has_element?(view, "[data-bead=e]")
  end

  test "persisted pre-views configuration uses shipped presets until its next reload", %{
    conn: conn
  } do
    config = Map.delete(Board.RuntimeState.config().config, "views")
    Board.Repo.query!("UPDATE board_config SET config = $1 WHERE id = 1", [config])
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "#view-open[aria-pressed=true]")
  end

  test "advanced count includes a false-valued label and disabling the stale preset", %{
    conn: conn
  } do
    rows =
      Board.Beads.Projection.list_raw("sample") ++
        [Map.put(b("flag", "task"), :labels, ["false"])]

    Board.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))
    {:ok, view, _} = live(conn, "/?view=stale&label=false&stale=false")
    assert has_element?(view, "#advanced-filter-count", "2")
    render_patch(view, "/?view=all&status=all&stale=false")
    refute has_element?(view, "#advanced-filter-count")
  end

  test "Stale selects stale tickets without changing rollups or counting the preset as advanced",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/?view=stale")
    refute has_element?(view, "[data-bead=e]")
    refute has_element?(view, "#advanced-filter-count")
    Board.Overlay.apply_event({"sample", "f"}, {:dispatch, %{window: "worker"}})
    Board.Repo.query!("UPDATE sessions SET last_seen_at = NOW() - INTERVAL '3 hours'")
    send(view.pid, :reconcile)
    assert has_element?(view, "[data-bead=e] [aria-valuemax='2']")
    view |> element("[data-bead=e] button") |> render_click()
    assert has_element?(view, "[data-bead=f]")
    refute has_element?(view, "[data-bead=a]")
    refute has_element?(view, "#advanced-filter-count")
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
