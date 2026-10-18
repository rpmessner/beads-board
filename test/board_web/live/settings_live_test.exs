defmodule BoardWeb.SettingsLiveTest do
  use BoardWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  use Oban.Testing, repo: Board.Repo

  test "renders persisted config and requests a worker reload", %{conn: conn} do
    {:ok, config} =
      Board.Config.parse_layers([{"defaults", File.read!("priv/board.defaults.toml")}])

    config =
      Map.put(config, "repos", [%{"key" => "sample", "path" => "/tmp/sample", "enabled" => true}])

    Board.Repo.insert_all("board_config", [
      %{
        id: 1,
        config: config,
        source: "/tmp/settings",
        discovered: ["/tmp/unconfigured"],
        loaded_at: DateTime.utc_now()
      }
    ])

    {:ok, view, _} = live(conn, "/settings")
    assert has_element?(view, "#repo-sample")
    assert has_element?(view, "#discovered-repos pre", "[[repos]]")
    assert has_element?(view, "#enabled-sample[disabled]")
    view |> element("#reload-config") |> render_click()
    assert_enqueued(worker: Board.Config.ReloadJob)
    Board.Repo.query!("UPDATE board_config SET error = 'bad TOML' WHERE id = 1")
    send(view.pid, :reconcile)
    assert has_element?(view, "#config-error", "last good config")
    assert has_element?(view, "#repo-sample")
  end
end
