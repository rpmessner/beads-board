defmodule BoardWeb.PullRequestsLiveTest do
  use BoardWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    {:ok, config} =
      Board.Config.parse_layers([{"defaults", File.read!("priv/board.defaults.toml")}])

    repos = [
      %{
        "key" => "sample",
        "path" => "/tmp/sample",
        "enabled" => true,
        "forge" => "github",
        "github" => "rpmessner/form-engine"
      },
      %{"key" => "local", "path" => "/tmp/local", "enabled" => true, "forge" => "none"}
    ]

    Board.Repo.insert_all("board_config", [
      %{
        id: 1,
        config: Map.put(config, "repos", repos),
        source: "test",
        discovered: [],
        loaded_at: DateTime.utc_now()
      }
    ])

    beads = [
      %{id: "fe-813", title: "Looper", status: "open", issue_type: "epic"},
      %{
        id: "fe-813.2",
        title: "Meter",
        status: "open",
        issue_type: "task",
        dependencies: [%{depends_on_id: "fe-813", type: "parent-child"}]
      },
      %{
        id: "fe-813.3",
        title: "Scheduler",
        status: "open",
        issue_type: "task",
        dependencies: [%{depends_on_id: "fe-813", type: "parent-child"}]
      }
    ]

    Board.Beads.Projection.replace("sample", Enum.map_join(beads, "\n", &Jason.encode!/1))

    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, File.read!("test/fixtures/forge/form-engine.json") |> Jason.decode!())
    end)

    {:ok, snapshot} =
      Board.Forge.GitHub.list("rpmessner/form-engine",
        token: "test",
        plug: {Req.Test, __MODULE__}
      )

    Board.Forge.Store.replace("sample", "rpmessner/form-engine", snapshot)
    :ok
  end

  test "sheet tabs preserve the PR page URL and refresh hidden streams", %{conn: conn} do
    {:ok, view, _} = live(conn, "/pull-requests?project=sample&ticket=sample:fe-813.2&tab=notes")
    assert has_element?(view, "#ticket-notes-tab[aria-selected=true]")
    Board.Overlay.apply_event({"sample", "fe-813.2"}, :abandon)
    Board.Overlay.apply_event({"sample", "fe-813.2"}, :revive)
    Board.Overlay.apply_event({"sample", "fe-813.2"}, {:dispatch, %{window: "pr-tab-worker"}})
    send(view.pid, {:notification, :board_events, "sample/fe-813.2"})
    assert has_element?(view, "#ticket-sessions-panel[hidden]", "pr-tab-worker")
    view |> element("#ticket-sessions-tab") |> render_click()
    assert_patch(view, "/pull-requests?project=sample&tab=sessions&ticket=sample%3Afe-813.2")
    assert has_element?(view, "#ticket-sessions-panel:not([hidden])", "pr-tab-worker")
    render_patch(view, "/pull-requests?project=sample&ticket=sample:fe-813.2&tab=unknown")
    assert has_element?(view, "#ticket-overview-tab[aria-selected=true]")
    render_click(view, "close-ticket", %{"key" => "sample:fe-813.2"})
    assert_patch(view, "/pull-requests?project=sample")
  end

  test "stack links open the sheet; local repositories have no panel", %{conn: conn} do
    {:ok, view, _} = live(conn, "/pull-requests?project=sample")
    assert has_element?(view, "#pull-requests [data-number='5'] + [data-number='6']")
    assert has_element?(view, "#cr-sample-6 [data-parent='5']", "Waiting on #5")
    assert has_element?(view, "#merge-request-5")
    view |> element("#cr-sample-6 a[data-bead='fe-813.2']") |> render_click()
    assert_patch(view, "/pull-requests?project=sample&ticket=sample%3Afe-813.2")
    assert has_element?(view, "#ticket-sheet[data-open=true]")

    assert has_element?(
             view,
             "#ticket-crs a[href='https://github.com/rpmessner/form-engine/pull/6']"
           )

    render_patch(view, "/pull-requests?project=local")
    refute has_element?(view, "#forge-panel")
  end

  test "merge confirmation, job phases and observed close suggestion", %{conn: conn} do
    stored = Board.Forge.Store.get("sample")

    snapshot =
      put_in(stored.snapshot, ["change_requests", Access.at(0), "mergeable"], "mergeable")

    Board.Forge.Store.replace("sample", stored.remote, snapshot)
    fake = start_supervised!({Board.Forge.Fake, snapshot})
    {:ok, view, _} = live(conn, "/pull-requests?project=sample")
    view |> element("#merge-request-6") |> render_click()
    assert has_element?(view, "#merge-status", "Bottom of stack only")
    refute has_element?(view, "#merge-confirm[data-open=true]")
    view |> element("#merge-request-5") |> render_click()
    assert has_element?(view, "#merge-confirm[data-open=true]")

    assert has_element?(
             view,
             "#merge-confirm",
             snapshot["change_requests"] |> hd() |> Map.fetch!("head_sha")
           )

    assert has_element?(view, "#merge-confirm", "fe-813.3")
    assert has_element?(view, "#merge-confirm", "Retarget #6")
    view |> element("#merge-confirm-submit") |> render_click()
    assert has_element?(view, "#merge-status[data-state=merging]")
    row = Board.Merge.latest("sample")
    Board.Merge.MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    send(view.pid, :reconcile)
    assert has_element?(view, "#merge-status[data-state=retargeting]")
    Board.Merge.RetargetJob.run(row.id, Board.Forge.Fake, server: fake)
    send(view.pid, :reconcile)
    assert has_element?(view, "#merge-status[data-state=merged]")
    assert Board.Overlay.get({"sample", "fe-813.3"}).stage == :pr_open
    {:ok, observed} = Board.Forge.Fake.list(stored.remote, server: fake)
    Board.Forge.Store.replace("sample", stored.remote, observed)
    render_patch(view, "/pull-requests?project=sample&ticket=sample%3Afe-813.3")
    assert has_element?(view, "#ticket-stage", "merged")
    assert has_element?(view, "#ticket-close-suggestion", "bd close fe-813.3")
  end

  test "a head observed after opening confirmation requires a fresh confirmation", %{conn: conn} do
    stored = Board.Forge.Store.get("sample")

    snapshot =
      put_in(stored.snapshot, ["change_requests", Access.at(0), "mergeable"], "mergeable")

    Board.Forge.Store.replace("sample", stored.remote, snapshot)
    {:ok, view, _} = live(conn, "/pull-requests?project=sample")
    view |> element("#merge-request-5") |> render_click()
    moved = put_in(snapshot, ["change_requests", Access.at(0), "head_sha"], "new-head")
    Board.Forge.Store.replace("sample", stored.remote, moved)
    view |> element("#merge-confirm-submit") |> render_click()
    assert has_element?(view, "#merge-confirm[data-open=true]", "Head moved")
    assert Board.Merge.latest("sample") == nil
  end

  test "repeated request exposes the durable failure, not a confirmation that cannot run", %{
    conn: conn
  } do
    stored = Board.Forge.Store.get("sample")

    snapshot =
      put_in(stored.snapshot, ["change_requests", Access.at(0), "mergeable"], "mergeable")

    Board.Forge.Store.replace("sample", stored.remote, snapshot)
    fake = start_supervised!({Board.Forge.Fake, Map.put(snapshot, "merge_error", true)})
    {:ok, view, _} = live(conn, "/pull-requests?project=sample")
    view |> element("#merge-request-5") |> render_click()
    view |> element("#merge-confirm-submit") |> render_click()
    row = Board.Merge.latest("sample")
    Board.Merge.MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    send(view.pid, :reconcile)
    assert has_element?(view, "#merge-status[data-state=failed]")
    view |> element("#merge-request-5") |> render_click()
    refute has_element?(view, "#merge-confirm[data-open=true]")
    assert has_element?(view, "#merge-status[data-state=failed]")
  end

  test "initiatives count distinct open CRs across an epic's tickets", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    assert has_element?(view, "[data-bead='fe-813'] [data-cr-count='2']")
  end

  test "copy is limited to labels, controls and status with human timestamps", %{conn: conn} do
    {:ok, view, _} = live(conn, "/pull-requests?project=sample")
    refute has_element?(view, "main header p")
    refute has_element?(view, "#forge-panel > p")
    assert has_element?(view, "#forge-synced time[title][datetime]", "just now")
    time = DateTime.add(DateTime.utc_now(), -150)
    Board.Repo.update_all("forge_snapshots", set: [synced_at: time])
    send(view.pid, :reconcile)
    assert has_element?(view, "#forge-synced time", "2 min ago")
  end

  test "manual refresh reports completion and failure", %{conn: conn} do
    Board.Repo.update_all("forge_snapshots",
      set: [attempted_at: DateTime.add(DateTime.utc_now(), -121)]
    )

    {:ok, view, _} = live(conn, "/pull-requests?project=sample")
    view |> element("#forge-refresh") |> render_click()
    assert has_element?(view, "#flash-group", "Refreshing")
    row = Board.Forge.Store.get("sample")
    Board.Forge.Store.replace("sample", row.remote, row.snapshot)
    send(view.pid, :reconcile)
    assert has_element?(view, "#flash-group", "Updated")

    Board.Repo.update_all("forge_snapshots",
      set: [attempted_at: DateTime.add(DateTime.utc_now(), -121)]
    )

    send(view.pid, :reconcile)
    view |> element("#forge-refresh") |> render_click()
    assert has_element?(view, "#flash-group", "Refreshing")
    Board.Forge.Store.failed("sample", row.remote, :unavailable)
    send(view.pid, :reconcile)
    assert has_element?(view, "#flash-group", "Refresh failed")
    view |> element("#forge-refresh") |> render_click()
    assert has_element?(view, "#flash-group", "Refresh failed")
  end

  test "forge success and failure leave beads sidebar health unchanged", %{conn: conn} do
    Board.RuntimeState.record("sample", {:ok, :changed})
    before = Board.RuntimeState.repos() |> Enum.find(&(&1["key"] == "sample"))
    row = Board.Forge.Store.get("sample")
    Board.Forge.Store.failed("sample", row.remote, :unavailable)
    Board.Forge.Store.replace("sample", row.remote, row.snapshot)
    after_read = Board.RuntimeState.repos() |> Enum.find(&(&1["key"] == "sample"))
    assert before["health"] == after_read["health"]
    {:ok, view, _} = live(conn, "/pull-requests?project=sample")
    refute has_element?(view, "#sidebar-project-sample", "down")
    Board.RuntimeState.record("sample", {:error, :unreachable})
    send(view.pid, :reconcile)
    assert has_element?(view, "#sidebar-project-sample", "down")
  end
end
