# MIX_ENV=acceptance PORT=4879 mix run --no-start --no-halt tools/previewbtn-acceptance.exs
# Pass "done" in a second invocation to move only the scratch ticket to Done.
update? = System.argv() == ["done"]
Application.put_env(:foreman, :role, "all")
Application.put_env(:foreman, :runtime_enabled, false)
Application.put_env(:foreman, Oban,
  Application.fetch_env!(:foreman, Oban)
  |> Keyword.merge(testing: :disabled, queues: if(update?, do: false, else: [previews: 1]), plugins: false))
Application.put_env(:foreman, ForemanWeb.Endpoint,
  Application.fetch_env!(:foreman, ForemanWeb.Endpoint)
  |> Keyword.merge(server: not update?, http: [ip: {127, 0, 0, 1}, port: 4879],
    check_origin: ["//127.0.0.1:4879"]))
{:ok, _} = Application.ensure_all_started(:ecto_sql)
config = Application.fetch_env!(:foreman, Foreman.Repo)
case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, fn repo ->
  Ecto.Migrator.run(repo, "priv/repo/migrations", :up, all: true)
end)
{:ok, _} = Application.ensure_all_started(:foreman)
key = {"preview-check", "preview-1"}
if update? do
  {:ok, %{stage: :done}} = Foreman.Overlay.apply_event(key, :bead_closed)
  IO.puts("PREVIEW_TICKET_DONE")
else
  {:ok, config} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
  config = Map.put(config, "repos", [%{"key" => "preview-check", "path" => File.cwd!(), "enabled" => true}])
  Foreman.Repo.insert_all("board_config", [%{id: 1, config: config, source: "preview acceptance",
    discovered: [], loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
  Foreman.Beads.Projection.replace("preview-check", Jason.encode!(%{id: "preview-1", title: "Worktree preview",
    status: "open", issue_type: "task", priority: 2, description: "Preview controls"}))
  Foreman.Overlay.apply_event(key, :bead_reopened)
  Foreman.Overlay.apply_event(key, :abandon)
  Foreman.Overlay.apply_event(key, :revive)
  Foreman.Overlay.apply_event(key, {:dispatch, %{window: "preview-check", workdir: File.cwd!(), branch: "fm-previewbtn"}})
  {:ok, _} = Supervisor.start_child(Foreman.Supervisor, Foreman.Previews.Poller)
  IO.puts("PREVIEW_ACCEPTANCE_READY")
end
