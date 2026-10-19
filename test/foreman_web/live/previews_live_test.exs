defmodule ForemanWeb.PreviewsLiveTest do
  use ForemanWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "orphan inventory can stop a vanished worktree", %{conn: conn} do
    Process.put(:devserve_previews, [
      %{
        "unit" => "devserve-lost.service",
        "worktree" => "/vanished/preview",
        "state" => "running",
        "missing" => true,
        "url" => "http://127.0.0.1:4888"
      }
    ])

    Foreman.Previews.reconcile(Foreman.FakeDevserve)
    [orphan] = Foreman.Previews.orphans()
    {:ok, view, _} = live(conn, "/previews")
    assert has_element?(view, "#stop-preview-#{orphan.id}")
    view |> element("#stop-preview-#{orphan.id}") |> render_click()
    assert Foreman.Previews.get(orphan.id).state == :stopping
    Foreman.Previews.reconcile(Foreman.FakeDevserve)
    send(view.pid, :reconcile)
    refute has_element?(view, "#stop-preview-#{orphan.id}")
    assert has_element?(view, "#no-orphan-previews")
  end
end
