defmodule ForemanWeb.DocumentPanelLiveTest do
  use ForemanWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Foreman.ScratchDocs

  setup do
    root =
      ScratchDocs.write(ScratchDocs.dir("document-panel"), %{"docs/spec.md" => "# Shared spec"})

    on_exit(fn -> File.rm_rf!(root) end)
    ScratchDocs.configure(%{"sample" => root})

    Foreman.Beads.Projection.replace(
      "sample",
      Jason.encode!(%{
        id: "s-1",
        title: "A ticket",
        issue_type: "task",
        status: "open",
        description: "[Spec](docs/spec.md)"
      })
    )

    %{root: root}
  end

  test "Initiatives opens the document over the retained ticket", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?ticket=sample:s-1&tab=overview&project=sample")
    href = "/documents/sample?path=docs%2Fspec.md"
    assert has_element?(view, "#ticket-overview a[href='#{href}']")
    render_hook(view, "open-doc", %{"href" => href})
    assert has_element?(view, "#panel-document h1", "Shared spec")
    assert has_element?(view, "#ticket-sheet[data-open=true] #ticket-title", "A ticket")
    path = assert_patch(view)
    assert URI.parse(path).path == "/"

    assert URI.decode_query(URI.parse(path).query) == %{
             "ticket" => "sample:s-1",
             "tab" => "overview",
             "project" => "sample",
             "doc" => "sample:docs/spec.md"
           }

    view |> element("#panel-close") |> render_click()
    assert has_element?(view, "#ticket-sheet[data-open=true] #ticket-title", "A ticket")
    refute has_element?(view, "#panel-document")
    assert_patch(view, "/?project=sample&tab=overview&ticket=sample%3As-1")
    render_hook(view, "close-document", %{})
    refute_receive {_, {:patch, _, _}}
  end

  test "refresh reopens the document and a Back URL closes only the document", %{conn: conn} do
    previous = "/?ticket=sample%3As-1&tab=notes"
    opened = previous <> "&doc=sample%3Adocs%2Fspec.md"
    {:ok, view, _} = live(conn, opened)
    assert has_element?(view, "#panel-document h1", "Shared spec")
    assert has_element?(view, "#ticket-notes-tab[aria-selected=true]")
    render_patch(view, previous)
    refute has_element?(view, "#panel-document")
    assert has_element?(view, "#ticket-sheet[data-open=true] #ticket-title")
    assert has_element?(view, "#ticket-notes-tab[aria-selected=true]")
  end

  test "missing, malformed and disallowed documents keep the ticket underneath", %{
    conn: conn,
    root: root
  } do
    File.ln_s!(Path.join(root, "docs/spec.md"), Path.join(root, "symlink.md"))

    for doc <- [
          "sample:missing.md",
          "sample:../secret.md",
          "sample:docs/../docs/spec.md",
          "sample:/etc/passwd.md",
          "sample:symlink.md",
          "unknown:docs/spec.md",
          "bad"
        ] do
      {:ok, view, _} =
        live(conn, "/?" <> URI.encode_query(%{"ticket" => "sample:s-1", "doc" => doc}))

      assert has_element?(view, "#panel-status", "Document unavailable")
      refute has_element?(view, "#panel-open-viewer")
      assert has_element?(view, "#ticket-title", "A ticket")
    end
  end

  test "a source round-trips without authorizing an unvalidated root", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?ticket=sample:s-1")

    render_hook(view, "open-doc", %{
      "href" => "/documents/sample?path=docs%2Fspec.md&source=untrusted"
    })

    assert URI.decode_query(URI.parse(assert_patch(view)).query)["doc_source"] == "untrusted"
    assert has_element?(view, "#panel-status", "Document unavailable")
    view |> element("#panel-close") |> render_click()
    assert_patch(view, "/?ticket=sample%3As-1")
  end

  test "epic spec link opens the same panel on the epic route", %{conn: conn} do
    Foreman.Beads.Projection.replace(
      "sample",
      Jason.encode!(%{id: "e-1", title: "An epic", issue_type: "epic", status: "open"})
    )

    Foreman.Overlay.apply_event(
      {"sample", "e-1"},
      {:dispatch, %{window: "spec-session", spec: "docs/spec.md"}}
    )

    {:ok, view, _} = live(conn, "/epics/sample/e-1")
    href = "/documents/sample?path=docs%2Fspec.md"
    assert has_element?(view, "#epic-documents a[href='#{href}']")
    render_hook(view, "open-doc", %{"href" => href})
    assert URI.parse(assert_patch(view)).path == "/epics/sample/e-1"
    assert has_element?(view, "#panel-document h1", "Shared spec")
    assert has_element?(view, "#epic-title", "An epic")
  end
end
