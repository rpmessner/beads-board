defmodule Foreman.DocumentsTest do
  use ExUnit.Case, async: true
  alias Foreman.Documents

  setup do
    root = Path.join(System.tmp_dir!(), "fm-docs-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "docs"))
    File.write!(Path.join(root, "README.md"), "# Read me")
    File.write!(Path.join(root, "docs/spec.md"), "# Spec")
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  test "refuses traversal, outside symlinks, directories and oversized files", %{root: root} do
    outside = root <> "-outside.md"
    File.write!(outside, "secret")
    on_exit(fn -> File.rm!(outside) end)
    File.ln_s!(outside, Path.join(root, "docs/leak.md"))
    File.ln_s!(System.tmp_dir!(), Path.join(root, "docs/outside"))
    File.write!(Path.join(root, "docs/large.md"), String.duplicate("a", 1_048_577))

    for path <- [
          "../#{Path.basename(outside)}",
          outside,
          "docs/leak.md",
          "docs/outside/#{Path.basename(outside)}",
          "docs",
          "docs/large.md"
        ] do
      assert {:error, _} = Documents.read(root, path)
    end
  end

  test "a missing registered worktree falls back to the main checkout", %{root: root} do
    System.cmd("git", ["init", "-q", root])
    System.cmd("git", ["-C", root, "add", "."])

    System.cmd("git", [
      "-C",
      root,
      "-c",
      "user.name=Test",
      "-c",
      "user.email=test@example.com",
      "commit",
      "-qm",
      "docs"
    ])

    worktree = root <> "-worktree"
    System.cmd("git", ["-C", root, "worktree", "add", "-q", "--detach", worktree])
    File.write!(Path.join(worktree, "docs/spec.md"), "# Worktree spec")

    assert {:ok, %{content: "# Worktree spec"}} =
             Documents.read(root, Path.join(worktree, "docs/spec.md"))

    File.rm_rf!(worktree)

    assert {:ok, %{content: "# Spec", path: "docs/spec.md"}} =
             Documents.read(root, Path.join(worktree, "docs/spec.md"))
  end

  test "lists README, AGENTS and nested docs only without following symlinks", %{root: root} do
    File.write!(Path.join(root, "AGENTS.md"), "Rules")
    File.mkdir_p!(Path.join(root, "docs/nested"))
    File.write!(Path.join(root, "docs/nested/adr.md"), "ADR")
    File.write!(Path.join(root, "other.md"), "Other")
    File.ln_s!(root, Path.join(root, "docs/loop"))

    assert Documents.list(root) == [
             "AGENTS.md",
             "README.md",
             "docs/nested/adr.md",
             "docs/spec.md"
           ]
  end

  test "lists documents deeper than 32 folders", %{root: root} do
    nested = Path.join(["docs" | List.duplicate("nested", 34)])
    File.mkdir_p!(Path.join(root, nested))
    relative = Path.join(nested, "decision.md")
    File.write!(Path.join(root, relative), "Decision")
    assert relative in Documents.list(root)
  end

  test "reads a document inside its configured folder", %{root: root} do
    assert {:ok, %{content: "# Spec", path: "docs/spec.md"}} =
             Documents.read(root, "docs/spec.md")
  end
end
