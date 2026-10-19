# Isolated server: MIX_ENV=acceptance PORT=4786 PHX_SERVER=true mix run --no-start tools/waiting-acceptance.exs
unless Mix.env() == :acceptance and System.get_env("PORT") == "4786", do: raise("isolated port required")
config = Application.fetch_env!(:foreman, Foreman.Repo)
unless config[:database] == "foreman_acceptance_fm-waiting", do: raise("scratch database required")
socket = System.fetch_env!("WAITING_SCRATCH_SOCKET")
root = System.fetch_env!("WAITING_SCRATCH_REPO")
unless String.starts_with?(socket, "fm-waiting-") and String.starts_with?(root, "/tmp/fm-waiting-"), do: raise("scratch targets required")
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
Application.put_env(:foreman, :planning_tmux_socket, socket)
Application.put_env(:foreman, :external_tmux_socket, System.fetch_env!("WAITING_EXTERNAL_SOCKET"))
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4786"]))
{:ok, _} = Application.ensure_all_started(:foreman)
{:ok, defaults} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
repo = %{"key" => "scratch", "path" => root, "enabled" => true, "tickets" => "files"}
Foreman.Repo.insert_all("board_config", [%{id: 1, config: Map.put(defaults, "repos", [repo]), stores: %{}, discovered: [], source: "waiting acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
rows = [%{id: "scratch-1", title: "Permission hook probe", status: "open", issue_type: "task"}, %{id: "scratch-pi", title: "Provider limit probe", status: "open", issue_type: "task"}]
Foreman.Beads.Projection.replace("scratch", Enum.map_join(rows, "\n", &Jason.encode!/1))
Foreman.RuntimeState.record("scratch", {:ok, :changed})
{:ok, _} = Foreman.SessionMonitor.start_link([])
IO.puts("WAITING_ACCEPTANCE_READY")
Process.sleep(:infinity)
