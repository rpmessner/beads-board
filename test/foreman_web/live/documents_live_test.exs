defmodule ForemanWeb.DocumentsLiveTest do
  use ForemanWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    root = Path.join(System.tmp_dir!(), "fm-docs-live-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "docs"))
    File.write!(Path.join(root, "README.md"), "# Project\n\n[Spec](docs/spec.md)")
    File.write!(Path.join(root, "docs/spec.md"), "# Spec\n\n- [x] Complete")
    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, config} =
      Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

    config = Map.put(config, "repos", [%{"key" => "sample", "path" => root, "enabled" => true}])

    Foreman.Repo.insert_all("board_config", [
      %{id: 1, config: config, source: "test", discovered: [], loaded_at: DateTime.utc_now()}
    ])

    %{root: root}
  end

  test "recorded artifacts survive a removed and pruned worktree", %{conn: conn, root: root} do
    old = root <> "-removed/docs/spec.md"

    Foreman.Overlay.apply_event(
      {"sample", "draft:docs"},
      {:create, %{title: "Docs", spec_link: old}}
    )

    {:ok, view, _} = live(conn, Foreman.Markdown.viewer_path("sample", old))
    assert has_element?(view, "#document-content h1", "Spec")
    render_patch(view, Foreman.Markdown.viewer_path("sample", root <> "-unknown/docs/spec.md"))
    assert has_element?(view, "#document-status", "Document unavailable")
  end

  test "project viewer lists documents and renders the selected path", %{conn: conn} do
    {:ok, view, _} = live(conn, "/documents/sample")
    assert has_element?(view, "#document-content h1", "Project")
    assert has_element?(view, "#document-files a", "docs/spec.md")
    assert has_element?(view, "#document-content a[href='/documents/sample?path=docs%2Fspec.md']")
    view |> element("#document-files a", "docs/spec.md") |> render_click()
    assert has_element?(view, "#document-content input[type=checkbox][disabled][checked]")
    assert_patch(view, "/documents/sample?path=docs%2Fspec.md")
    render_patch(view, "/documents/sample?path=..%2Fsecret.md")
    assert has_element?(view, "#document-status", "Document unavailable")
    refute has_element?(view, "#document-content")
  end
end
