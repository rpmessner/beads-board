# MIX_ENV=acceptance PORT=4785 FOREMAN_ROLE=web mix run --no-start tools/merge-request-acceptance.exs
# Fake forge only. PostgreSQL NOTIFY is test-harness control, not an app API.
defmodule MergeAcceptance do
  def loop(fake, baseline) do
    receive do
      {:notification, _, _, "merge_acceptance", command} ->
        case command do
          "reset" ->
            Foreman.Repo.delete_all("request_events")
            Foreman.Repo.delete_all(Foreman.Requests.Request)
            Foreman.Repo.delete_all(Foreman.Merge.Record)
            Foreman.Repo.delete_all(Oban.Job)
            Agent.update(fake, fn _ -> baseline end)
            Foreman.Forge.Store.replace("sample", "scratch/merge", baseline)
          "move" -> Agent.update(fake, &put_in(&1, ["change_requests", Access.at(0), "head_sha"], "moved-head"))
          "fail" -> Agent.update(fake, &Map.put(&1, "merge_error", true))
          "retarget-fail" -> Agent.update(fake, &Map.put(&1, "retarget_error", true))
          "drain" -> IO.inspect(Oban.drain_queue(queue: :external_writes, with_limit: 1), label: "DRAIN")
          "read" ->
            {:ok, snapshot} = Foreman.Forge.Fake.list("scratch/merge", server: fake)
            Foreman.Forge.Store.replace("sample", "scratch/merge", snapshot)
        end
        Foreman.Requests.reconcile_merges()
        IO.puts("ACCEPTANCE_COMMAND #{command}")
        loop(fake, baseline)
    end
  end
end

config = Application.fetch_env!(:foreman, Foreman.Repo)
  |> Keyword.put(:database, "foreman_acceptance_fm-mergereq")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
Application.put_env(:foreman, Foreman.Repo, config)
Application.put_env(:foreman, :runtime_enabled, false)
Application.put_env(:foreman, :forge_adapter, Foreman.Forge.Fake)
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:server, true) |> Keyword.put(:check_origin, false))
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
{:ok, _} = Application.ensure_all_started(:foreman)
for table <- ~w(request_events approval_requests overlay_effects agent_notes stage_events sessions overlay_cr_links epic_links tickets epics beads bead_repos forge_snapshots) do
  Foreman.Repo.delete_all(table)
end
{:ok, defaults} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
repo = %{"key" => "sample", "path" => "/tmp/merge-no-beads-store", "enabled" => true, "forge" => "github", "github" => "scratch/merge"}
Foreman.Repo.insert_all("board_config", [%{id: 1, config: Map.put(defaults, "repos", [repo]), source: "fake acceptance", discovered: [], loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Foreman.Repo.delete_all(Foreman.Merge.Record)
Foreman.Repo.delete_all(Oban.Job)
beads = [%{id: "bb-demo", title: "Merge safety", status: "open", issue_type: "epic"}, %{id: "bb-demo.1", title: "Guarded merge", status: "open", issue_type: "task", dependencies: [%{depends_on_id: "bb-demo", type: "parent-child"}]}]
Foreman.Beads.Projection.replace("sample", Enum.map_join(beads, "\n", &Jason.encode!/1))
Foreman.RuntimeState.record("sample", {:ok, :changed})
pr = %{"number" => 5, "title" => "Guarded merge (bb-demo.1)", "body" => "", "source_branch" => "pr/merge", "target_branch" => "main", "head_sha" => "0123456789abcdef0123456789abcdef01234567", "draft" => false, "checks" => "success", "mergeable" => "mergeable", "state" => "open", "url" => "https://github.com/scratch/merge/pull/5"}
child = %{pr | "number" => 6, "title" => "Retarget follow-up", "source_branch" => "pr/child", "target_branch" => "pr/merge", "head_sha" => "abcdef0123456789abcdef0123456789abcdef01", "url" => "https://github.com/scratch/merge/pull/6"}
baseline = %{"default_branch" => "main", "change_requests" => [pr, child]}
{:ok, fake} = Foreman.Forge.Fake.start_link(baseline)
Application.put_env(:foreman, :forge_options, server: fake)
Foreman.Forge.Store.replace("sample", "scratch/merge", baseline)
{:ok, notifications} = Postgrex.Notifications.start_link(Keyword.take(config, [:username, :password, :hostname, :database]))
{:ok, _} = Postgrex.Notifications.listen(notifications, "merge_acceptance")
IO.puts("MERGE_ACCEPTANCE_READY")
MergeAcceptance.loop(fake, baseline)
