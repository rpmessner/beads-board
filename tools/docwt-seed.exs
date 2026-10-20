# MIX_ENV=test PREVIEW_DATABASE=<owned docwt preview> mix run --no-start tools/docwt-seed.exs
# Only this preview is touched. Scratch git repos under /tmp remain for browser verification.
database = System.fetch_env!("PREVIEW_DATABASE")
unless String.starts_with?(database, "foreman_preview_fm_docwt_"),
  do: raise("requires the docwt preview database")

config = Application.fetch_env!(:foreman, Foreman.Repo)
Application.put_env(:foreman, Foreman.Repo,
  Keyword.merge(config, database: database, pool: DBConnection.ConnectionPool))
Application.put_env(:foreman, :runtime_enabled, false)
Application.put_env(:foreman, :role, "web")
{:ok, _} = Application.ensure_all_started(:foreman)

base = Path.join(System.tmp_dir!(), "foreman-docwt-browser")
root = Path.join(base, "main")
tree = Path.join(base, "fm-review-build")
File.mkdir_p!(root)
git = fn dir, args ->
  {output, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
  output
end
unless File.exists?(Path.join(root, ".git")) do
  git.(root, ["init", "-q"])
  git.(root, ["-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "init"])
end
unless File.exists?(tree) do
  git.(root, ["worktree", "prune"])
  git.(root, ["worktree", "add", "-q", "--detach", tree])
end
File.mkdir_p!(Path.join(tree, "docs/sessions"))
File.write!(Path.join(tree, "docs/sessions/review.md"), """
# Build review

## Verification

The worktree report is ready for review.

- [x] Resolver authorization
- [x] Document panel
- [x] Viewer source round-trip

| Check | Result |
| --- | --- |
| Main checkout | Not present |
| Recorded worktree | Available |
""")

{:ok, defaults} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
repo = %{"key" => "docwt", "path" => root, "enabled" => true, "forge" => "none"}
Foreman.Repo.insert_all("board_config", [%{id: 1, config: Map.put(defaults, "repos", [repo]), source: "docwt preview", discovered: [], loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Foreman.Beads.Projection.replace("docwt", Jason.encode!(%{id: "wt-1", title: "Review the unmerged worktree report", issue_type: "task", status: "open", description: "Review docs/sessions/review.md before merging."}))
Foreman.Overlay.apply_event({"docwt", "wt-1"}, {:dispatch, %{window: "fm-review-build", workdir: tree, report: "docs/sessions/review.md"}})
Foreman.Overlay.apply_event({"docwt", "wt-1"}, {:report, %{path: "docs/sessions/review.md"}})
IO.puts("Seeded isolated docwt preview with scratch worktree #{Path.basename(tree)}")
