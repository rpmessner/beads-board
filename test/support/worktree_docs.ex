defmodule Foreman.WorktreeDocs do
  @moduledoc false
  alias Foreman.ScratchDocs

  def fixture do
    base = ScratchDocs.dir("worktree-docs")
    root = Path.join(base, "main")
    tree = Path.join(base, "build-report")
    File.mkdir_p!(root)
    git!(root, ["init", "-q"])

    git!(root, [
      "-c",
      "user.name=Test",
      "-c",
      "user.email=test@example.invalid",
      "commit",
      "--allow-empty",
      "-qm",
      "init"
    ])

    git!(root, ["worktree", "add", "-qb", "build", tree])
    ScratchDocs.write(tree, %{"docs/report.md" => "# Worktree report"})

    ticket = %{
      repo: "sample",
      raw: %{"description" => "docs/report.md"},
      notes: [],
      sessions: [%{started_at: ~U[2026-10-20 00:00:00Z], details: %{"workdir" => tree}}],
      history: []
    }

    %{
      base: base,
      root: root,
      tree: tree,
      ticket: ticket,
      repos: [%{"key" => "sample", "path" => root}]
    }
  end

  def git!(root, args) do
    {output, 0} = System.cmd("git", ["-C", root | args], stderr_to_stdout: true)
    output
  end
end
