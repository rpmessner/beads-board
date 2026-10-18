# PORT=4758 BOARD_ROLE=web mix run --no-start tools/forge-acceptance.exs
# Isolated Postgres target. Reads only the existing projection from the development DB.
source = Application.fetch_env!(:board, Board.Repo)
target = Keyword.put(source, :database, "beads_board_forge_acceptance")
Application.put_env(:board, Board.Repo, target)
Application.put_env(:board, :runtime_enabled, false)
Application.put_env(:board, :role, "all")
if File.exists?("/tmp/forge-read-only"), do: raise("Acceptance read path must not exist")
config_dir = Path.expand("tmp/forge-config")
File.mkdir_p!(config_dir)
File.write!(Path.join(config_dir, "board.toml"), """
[[repos]]
key = "form-engine"
path = "/tmp/forge-read-only"
forge = "github"
github = "rpmessner/form-engine"
enabled = true
""")
Application.put_env(:board, :config_directory, config_dir)
Application.put_env(:board, :discovery_root, Path.expand("tmp/no-discovery"))
Application.put_env(:board, BoardWeb.Endpoint,
  Application.fetch_env!(:board, BoardWeb.Endpoint) |> Keyword.put(:server, true))
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(target) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Board.Repo, fn repo -> Ecto.Migrator.run(repo, "priv/repo/migrations", :up, all: true) end)
{:ok, _} = Application.ensure_all_started(:board)
{:ok, connection} = Postgrex.start_link(Keyword.take(source, [:username,:password,:hostname,:database]))
%{rows: rows} = Postgrex.query!(connection, "SELECT raw FROM beads WHERE repo_key = $1", ["form-engine"])
if rows == [], do: raise("Source projection has no form-engine beads")
{:ok, config} = Board.Config.parse_layers([{"defaults", File.read!("priv/board.defaults.toml")}])
config = Map.put(config, "repos", [%{"key" => "form-engine", "path" => "/tmp/forge-read-only", "enabled" => true, "forge" => "github", "github" => "rpmessner/form-engine"}])
Board.Repo.insert_all("board_config", [%{id: 1, config: config, source: "isolated acceptance", discovered: [], loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
{:ok, _} = Board.Beads.Projection.replace("form-engine", Enum.map_join(rows, "\n", fn [raw] -> Jason.encode!(raw) end))
{:ok, _} = Supervisor.start_child(Board.Supervisor, {Board.Forge.Credentials, []})
Board.Events.subscribe()
Board.Repo.update_all("forge_snapshots", set: [attempted_at: DateTime.add(DateTime.utc_now(), -121)])
# The configured path deliberately does not exist: no bd subprocess can start.
# Runtime and Oban exercise the real forge scheduling/manual-refresh path.
{:ok, _} = Supervisor.start_child(Board.Supervisor, {Board.Runtime, []})
Board.Events.broadcast(:forge_requested, "form-engine")
receive do
  {:notification, :board_events, %{"kind" => "forge_changed"}} -> :ok
after
  30_000 -> raise("No forge worker completion within 30 seconds")
end
row = Board.Forge.Store.get("form-engine")
if row.error, do: raise("Forge acceptance read failed: #{row.error}")
ordered = Board.Forge.Stack.order(row.snapshot["change_requests"], row.snapshot["default_branch"])
IO.inspect(Enum.map(ordered, &Map.take(&1, ["number","source_branch","target_branch","links"])), label: "LIVE_FORGE_STACK")
IO.puts("FORGE_ACCEPTANCE_READY")
Process.sleep(:infinity)
