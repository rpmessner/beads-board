# MIX_ENV=test PORT=4781 mix run --no-start --no-halt tools/docs-acceptance.exs
root = Path.join(System.tmp_dir!(), "fm-docs-browser-#{System.os_time(:millisecond)}")
File.mkdir_p!(Path.join(root, "docs/decisions"))
File.write!(Path.join(root, "README.md"), """
# Meridian release service

A release workspace for **small teams** shipping reliable services.

## Project documents

- [Release specification](docs/spec.md)
- [Storage decision](docs/decisions/storage.md)

## Delivery checklist

- [x] Define the release boundary
- [ ] Verify rollback on staging

> Every release should leave a readable audit trail.
""")
File.write!(Path.join(root, "AGENTS.md"), "# Working agreement\n\nKeep changes small and verify the public contract.")
spec = """
# Release orchestration

## Overview

A release combines an immutable artifact, a verified environment and an explicit approval. Operators can trace every transition without leaving the workspace.[^audit]

[Storage decision](decisions/storage.md#decision) · [Project overview](../README.md)

## State transitions

| State | Event | Next state | Owner |
| --- | --- | --- | --- |
| Planned | Build verified | Ready | Builder |
| Ready | Approval recorded | Deploying | Operator |
| Deploying | Health confirmed | Released | Monitor |

## Scheduler contract

```elixir
def release(artifact, environment) do
  with :ok <- verify(artifact),
       {:ok, approval} <- authorize(environment) do
    {:ok, %{artifact: artifact, approval: approval}}
  end
end
```

## Acceptance

- [x] Artifacts are immutable
- [x] Approval is recorded before deployment
- [ ] Rollback restores the previous artifact

[^audit]: Audit events remain available after a worktree is removed.
"""
long = Enum.map_join(1..14, "\n", fn n -> "\n## Operational requirement #{n}\n\nEach deployment records the selected artifact, target environment and approval. A failed health check pauses progression and preserves the previous release. The operator can inspect evidence before retrying.\n" end)
File.write!(Path.join(root, "docs/spec.md"), spec <> long)
File.write!(Path.join(root, "docs/decisions/storage.md"), "# Storage\n\n## Decision\n\nUse PostgreSQL for durable release facts.\n\n[Specification](../spec.md)\n\nhttps://www.postgresql.org\n")
File.write!(Path.join(root, "docs/brief.md"), "# Release brief\n\nImplement the [scheduler](spec.md).")
File.write!(Path.join(root, "docs/report.md"), "# Release report\n\n- [x] Scheduler verified\n- [x] Rollback verified")
System.cmd("git", ["init", "-q", root])
System.cmd("git", ["-C", root, "add", "."])
System.cmd("git", ["-C", root, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "fixture"])
worktree = root <> "-removed"
System.cmd("git", ["-C", root, "worktree", "add", "-q", "--detach", worktree])
File.rm_rf!(worktree)
System.cmd("git", ["-C", root, "worktree", "prune"])
repo = Application.fetch_env!(:foreman, Foreman.Repo) |> Keyword.merge(database: "foreman_docs_acceptance_#{Path.basename(File.cwd!())}", pool: DBConnection.ConnectionPool)
Application.put_env(:foreman, Foreman.Repo, repo)
Application.put_env(:foreman, :runtime_enabled, false)
Application.put_env(:foreman, :role, "web")
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.merge(server: true, check_origin: ["//127.0.0.1:4781"]))
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(repo) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
{:ok, _} = Application.ensure_all_started(:foreman)
{:ok, config} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
config = Map.put(config, "repos", [%{"key" => "meridian", "path" => root, "enabled" => true}])
Foreman.Repo.insert_all("board_config", [%{id: 1, config: config, source: "docs acceptance", discovered: [], loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Foreman.Beads.Projection.replace("meridian", Jason.encode!(%{id: "release-1", title: "Verify the release scheduler", issue_type: "task", status: "open", priority: 1, description: "# Release boundary\n\nValidate the **scheduler contract** against the [release specification](docs/spec.md).\n\n## Scheduler contract\n\n```elixir\nassert {:ok, release} = release(artifact, :staging)\n```", acceptance_criteria: "- [x] Build an immutable artifact\n- [x] Record operator approval\n- [ ] Verify rollback", design: "### State transitions\n\n| State | Event | Next state | Owner |\n| --- | --- | --- | --- |\n| Planned | Build verified | Ready | Builder |\n| Ready | Approval recorded | Deploying | Operator |\n| Deploying | Health confirmed | Released | Monitor |"}))
Foreman.Overlay.apply_event({"meridian", "release-1"}, :abandon)
Foreman.Overlay.apply_event({"meridian", "release-1"}, :revive)
Foreman.Overlay.apply_event({"meridian", "release-1"}, {:dispatch, %{window: "release-builder", brief_path: "docs/brief.md"}})
Foreman.Overlay.apply_event({"meridian", "release-1"}, {:report, %{path: Path.join(worktree, "docs/report.md")}})
Foreman.Overlay.apply_event({"meridian", "draft:release"}, {:create, %{title: "Release orchestration", spec_link: "docs/spec.md"}})
File.write!("/tmp/fm-docs-browser-root", root)
IO.puts("DOCS_ACCEPTANCE_READY")
