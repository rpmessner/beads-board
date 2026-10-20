defmodule Foreman.DocumentSourceReadsTest do
  use Foreman.DataCase, async: false
  alias Foreman.{DocumentSources, ScratchDocs, WorktreeDocs}

  setup do
    f = WorktreeDocs.fixture()
    on_exit(fn -> File.rm_rf!(f.base) end)
    other = Path.join(f.base, "other-configured")
    File.mkdir_p!(other)
    ScratchDocs.configure(%{"sample" => f.root, "other" => other})

    Foreman.Beads.Projection.replace(
      "sample",
      Enum.map_join(~w(any-ticket session history ticket), "\n", fn id ->
        Jason.encode!(%{id: id, title: id, issue_type: "task", status: "open"})
      end)
    )

    Map.put(f, :source, DocumentSources.token(f.tree))
  end

  test "each read requires a current record on a ticket of that repo", f do
    assert {:error, :refused} = DocumentSources.open("sample", "docs/report.md", f.source)

    assert {:ok, _} =
             Foreman.Overlay.apply_event(
               {"sample", "any-ticket"},
               {:dispatch, %{window: "build", workdir: f.tree}}
             )

    assert {:ok, %{content: "# Worktree report", source: source}} =
             DocumentSources.open("sample", "docs/report.md", f.source)

    assert source == f.source
    assert {:error, :refused} = DocumentSources.open("other", "docs/report.md", f.source)
    assert {:error, :refused} = DocumentSources.open("unknown", "docs/report.md", f.source)
    Repo.delete_all(from s in "sessions", where: s.repo_key == "sample")
    # History alone still authorizes it.
    assert {:ok, _} = DocumentSources.open("sample", "docs/report.md", f.source)
    Repo.update_all(from(e in "stage_events", where: e.repo_key == "sample"), set: [payload: %{}])
    assert {:error, :refused} = DocumentSources.open("sample", "docs/report.md", f.source)
  end

  test "session-only worktree and history-only workdir both authorize reads", f do
    Foreman.Overlay.apply_event(
      {"sample", "session"},
      {:dispatch, %{window: "build", worktree: f.tree}}
    )

    Repo.update_all(from(e in "stage_events", where: e.repo_key == "sample"), set: [payload: %{}])
    assert {:ok, _} = DocumentSources.open("sample", "docs/report.md", f.source)
    assert {:ok, _} = DocumentSources.open("sample", f.tree <> "/docs/report.md")
    Repo.delete_all(from s in "sessions", where: s.repo_key == "sample")

    Foreman.Overlay.apply_event(
      {"sample", "history"},
      {:dispatch, %{window: "history", workdir: f.tree}}
    )

    Repo.delete_all(from s in "sessions", where: s.repo_key == "sample")
    assert {:ok, _} = DocumentSources.open("sample", "docs/report.md", f.source)
  end

  test "rechecks git membership, traversal and symlinks before every read", f do
    Foreman.Overlay.apply_event(
      {"sample", "ticket"},
      {:dispatch, %{window: "build", workdir: f.tree}}
    )

    outside = ScratchDocs.write(Path.join(f.base, "outside"), %{"secret.md" => "# Secret"})
    File.ln_s!(outside, Path.join(f.tree, "escape"))
    File.ln_s!(Path.join(outside, "secret.md"), Path.join(f.tree, "linked.md"))

    for path <- [
          "../build-report/docs/report.md",
          "docs/../docs/report.md",
          "escape/secret.md",
          "linked.md",
          outside <> "/secret.md",
          "/etc/passwd.md"
        ] do
      assert {:error, _} = DocumentSources.open("sample", path, f.source)
    end

    WorktreeDocs.git!(f.root, ["worktree", "remove", "--force", f.tree])
    ScratchDocs.write(f.tree, %{"docs/report.md" => "# Impostor"})
    assert {:error, :refused} = DocumentSources.open("sample", "docs/report.md", f.source)
  end

  test "a recorded git worktree of an unconfigured repo is refused" do
    foreign = WorktreeDocs.fixture()
    on_exit(fn -> File.rm_rf!(foreign.base) end)

    Foreman.Overlay.apply_event(
      {"sample", "ticket"},
      {:dispatch, %{window: "foreign", workdir: foreign.tree}}
    )

    assert {:error, :refused} =
             DocumentSources.open("sample", "docs/report.md", DocumentSources.token(foreign.tree))

    assert {:error, :refused} = DocumentSources.open("sample", foreign.tree <> "/docs/report.md")
  end

  test "main wins, then removed and pruned roots fall back to main, then unavailable", f do
    Foreman.Overlay.apply_event(
      {"sample", "ticket"},
      {:dispatch, %{window: "build", workdir: f.tree}}
    )

    ScratchDocs.write(f.root, %{"docs/report.md" => "# Main"})
    assert {:error, :refused} = DocumentSources.open("sample", "docs/report.md", "wt-forged")

    assert {:ok, %{content: "# Main", source: :main, worktree: nil}} =
             DocumentSources.open("sample", "docs/report.md", f.source)

    File.rm_rf!(f.tree)
    WorktreeDocs.git!(f.root, ["worktree", "prune"])

    assert {:ok, %{content: "# Main", source: :main}} =
             DocumentSources.open("sample", "docs/report.md", f.source)

    File.rm!(Path.join(f.root, "docs/report.md"))
    assert {:error, :refused} = DocumentSources.open("sample", "docs/report.md", f.source)
  end
end
