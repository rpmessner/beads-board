defmodule Foreman.DocumentSourcesTest do
  use ExUnit.Case, async: true
  alias Foreman.{DocumentSources, WorktreeDocs}

  setup do
    fixture = WorktreeDocs.fixture()
    on_exit(fn -> File.rm_rf!(fixture.base) end)
    fixture
  end

  test "rejects unrecorded worktrees, recorded non-worktrees, traversal and symlinks", f do
    other = Foreman.ScratchDocs.write(Path.join(f.base, "other"), %{"secret.md" => "# Secret"})
    invalid = %{f.ticket | sessions: [%{details: %{"workdir" => other}}]}
    empty = %{f.ticket | sessions: []}
    File.ln_s!(other, Path.join(f.tree, "escape"))
    File.ln_s!(Path.join(other, "secret.md"), Path.join(f.tree, "linked.md"))
    File.ln_s!(f.tree, Path.join(f.base, "alias"))

    for path <- [
          "../build-report/docs/report.md",
          "docs/../docs/report.md",
          "escape/secret.md",
          "linked.md",
          other <> "/secret.md",
          "/etc/passwd.md"
        ] do
      assert DocumentSources.resolve(path, "sample", f.repos, f.ticket) == nil
    end

    assert DocumentSources.resolve("secret.md", "sample", f.repos, invalid) == nil
    assert DocumentSources.resolve(f.tree <> "/docs/report.md", "sample", f.repos, empty) == nil
    refute DocumentSources.worktree?(f.root, Path.join(f.base, "alias"))
    refute DocumentSources.worktree?(other, f.tree)
  end

  test "main wins for relative and worktree-absolute mentions, including a removed tree", f do
    Foreman.ScratchDocs.write(f.root, %{"docs/report.md" => "# Main"})

    for path <- ["docs/report.md", f.tree <> "/docs/report.md"] do
      assert DocumentSources.resolve(path, "sample", f.repos, f.ticket) ==
               {"sample", "docs/report.md", :main}
    end

    File.rm_rf!(f.tree)
    WorktreeDocs.git!(f.root, ["worktree", "prune"])

    assert DocumentSources.resolve(f.tree <> "/docs/report.md", "sample", f.repos, f.ticket) ==
             {"sample", "docs/report.md", :main}

    File.rm!(Path.join(f.root, "docs/report.md"))
    assert DocumentSources.resolve("docs/report.md", "sample", f.repos, f.ticket) == nil
  end

  test "history workdir and worktree values are allowed in deterministic recorded order", f do
    ticket = %{f.ticket | sessions: [], history: [%{payload: %{"worktree" => f.tree}}]}

    assert {"sample", "docs/report.md", _} =
             DocumentSources.resolve("docs/report.md", "sample", f.repos, ticket)

    ticket = %{ticket | history: [%{payload: %{"workdir" => f.tree}}]}

    assert {"sample", "docs/report.md", _} =
             DocumentSources.resolve("docs/report.md", "sample", f.repos, ticket)
  end

  test "does not generate a source under a repo with no ticket record", f do
    foreign = Foreman.WorktreeDocs.fixture()
    on_exit(fn -> File.rm_rf!(foreign.base) end)
    repos = f.repos ++ [%{"key" => "foreign", "path" => foreign.root}]
    ticket = %{f.ticket | sessions: [%{details: %{"workdir" => foreign.tree}}]}

    assert DocumentSources.resolve(foreign.tree <> "/docs/report.md", "sample", repos, ticket) ==
             nil
  end

  test "tries recorded worktrees in order, skipping a missing document", f do
    second = Path.join(f.base, "second-build")
    WorktreeDocs.git!(f.root, ["worktree", "add", "-q", "--detach", second])
    Foreman.ScratchDocs.write(second, %{"docs/report.md" => "# Second"})
    ticket = %{f.ticket | history: [%{payload: %{"worktree" => second}}]}

    assert {"sample", "docs/report.md", first} =
             DocumentSources.resolve("docs/report.md", "sample", f.repos, ticket)

    assert first == DocumentSources.token(f.tree)
    File.rm!(Path.join(f.tree, "docs/report.md"))

    assert {"sample", "docs/report.md", next} =
             DocumentSources.resolve("docs/report.md", "sample", f.repos, ticket)

    assert next == DocumentSources.token(second)
  end

  test "resolves relative and absolute reports in a recorded git worktree", f do
    assert {"sample", "docs/report.md", source} =
             DocumentSources.resolve("docs/report.md", "sample", f.repos, f.ticket)

    assert is_binary(source)

    assert DocumentSources.resolve(f.tree <> "/docs/report.md", "sample", f.repos, f.ticket) ==
             {"sample", "docs/report.md", source}
  end
end
