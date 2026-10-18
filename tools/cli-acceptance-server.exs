# MIX_ENV=acceptance FOREMAN_ROLE=web PORT=4759 PHX_SERVER=true \
# FOREMAN_TOKEN_FILE=$PWD/tmp/cli-token mix run --no-halt tools/cli-acceptance-server.exs
# First run MIX_ENV=acceptance mix ecto.create and mix ecto.migrate.
# No reader or bd process is started. Unit-test databases are never used.
if Mix.env() != :acceptance or
     Foreman.Repo.config()[:database] != "foreman_acceptance_#{Path.basename(File.cwd!())}",
  do: raise("acceptance requires MIX_ENV=acceptance and its dedicated database")
endpoint = Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4759"])
ForemanWeb.Endpoint.config_change([{ForemanWeb.Endpoint, endpoint}], [])
{:ok, config} = Foreman.Config.load("tmp/cli-config")
config = Map.put(config, "repos", [%{"key" => "scratch", "path" => Path.expand("tmp/scratch"), "enabled" => true, "color" => "violet", "forge" => "none"}])
Foreman.Repo.insert_all("board_config", [%{id: 1, config: config, stores: %{}, discovered: [], source: "CLI acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
rows = [
  %{id: "scratch-epic", title: "Agent CLI acceptance", status: "open", issue_type: "epic"},
  %{id: "scratch-1", title: "Live agent workflow", status: "open", issue_type: "task", dependencies: [%{depends_on_id: "scratch-epic", type: "parent-child"}]},
  %{id: "scratch-2", title: "Refused out-of-order claim", status: "open", issue_type: "task", dependencies: [%{depends_on_id: "scratch-epic", type: "parent-child"}]}
]
Foreman.Beads.Projection.replace("scratch", Enum.map_join(rows, "\n", &Jason.encode!/1))
Supervisor.start_child(Foreman.Supervisor, Foreman.SpoolWorker)
IO.puts("CLI acceptance ready")
