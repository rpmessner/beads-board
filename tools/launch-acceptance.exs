# MIX_ENV=acceptance FOREMAN_ROLE=web PORT=4784 PHX_SERVER=true mix run --no-start tools/launch-acceptance.exs
unless Mix.env() == :acceptance and System.get_env("PORT") == "4784",
  do: raise("requires isolated acceptance environment and port 4784")
config = Application.fetch_env!(:foreman, Foreman.Repo)
unless config[:database] == "foreman_acceptance_fm-launch", do: raise("wrong database")
socket = System.fetch_env!("LAUNCH_SCRATCH_SOCKET")
root = System.fetch_env!("LAUNCH_SCRATCH_REPO")
unless String.starts_with?(root, "/tmp/fm-launch-") and String.starts_with?(socket, "fm-launch-"),
  do: raise("requires scratch repo and socket")
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
Application.put_env(:foreman, :planning_tmux_socket, socket)
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4784"]))
{:ok, _} = Application.ensure_all_started(:foreman)
{:ok, defaults} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
repo = %{"key" => "scratch", "path" => root, "enabled" => true, "tickets" => "files"}
Foreman.Repo.insert_all("board_config", [%{id: 1, config: Map.put(defaults, "repos", [repo]), stores: %{}, discovered: [], source: "launch acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
rows = [
  %{id: "scratch-1", title: "Plan a scratch greeting command", status: "open", issue_type: "task"},
  %{id: "scratch-bug", title: "Diagnose a scratch greeting mismatch", status: "open", issue_type: "bug"},
  %{id: "scratch-e", title: "Published epic", status: "open", issue_type: "epic"},
  %{id: "scratch-child", title: "Planned child", status: "open", issue_type: "task", dependencies: [%{depends_on_id: "scratch-e", type: "parent-child"}]}
]
Foreman.Beads.Projection.replace("scratch", Enum.map_join(rows, "\n", &Jason.encode!/1))
unless Foreman.Overlay.get({"scratch", "draft:greeting"}), do: Foreman.Overlay.apply_event({"scratch", "draft:greeting"}, {:create, %{title: "Scratch greeting specification", spec_link: "docs/greeting.md"}})
Foreman.RuntimeState.record("scratch", {:ok, :changed})
{:ok, _} = Foreman.SessionMonitor.start_link([])
IO.puts("LAUNCH_ACCEPTANCE_READY")
Process.sleep(:infinity)
