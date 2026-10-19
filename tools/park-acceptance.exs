# Isolated live verification: PORT=4788 MIX_ENV=acceptance mix run --no-start tools/park-acceptance.exs
unless Mix.env() == :acceptance and System.get_env("PORT") == "4788",
  do: raise("requires acceptance on 4788")
config = Application.fetch_env!(:foreman, Foreman.Repo)
unless config[:database] == "foreman_acceptance_fm-park", do: raise("wrong database")
root = "/tmp/fm-park-live"
socket = "fm-park-live"
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
Application.put_env(:foreman, :planning_tmux_socket, socket)
Application.put_env(:foreman, :planning_idle_timeout, 120)
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4788"]))
{:ok, _} = Application.ensure_all_started(:foreman)
{:ok, defaults} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
repo = %{"key" => "scratch", "path" => root, "enabled" => true, "tickets" => "files"}
Foreman.Repo.insert_all("board_config", [%{id: 1, config: Map.put(defaults, "repos", [repo]), stores: %{}, discovered: [], source: "park acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Foreman.Beads.Projection.replace("scratch", Jason.encode!(%{id: "scratch-1", title: "Remember a scratch conversation", status: "open", issue_type: "task"}))
unless Foreman.Overlay.get({"scratch", "draft:greeting"}), do: Foreman.Overlay.apply_event({"scratch", "draft:greeting"}, {:create, %{title: "Scratch greeting specification"}})
Foreman.RuntimeState.record("scratch", {:ok, :changed})
unless Foreman.Sessions.get({"scratch", "scratch-1"}) do
  session = Foreman.Repo.insert!(%Foreman.PlanningSession{project: "scratch", ticket: "scratch-1", workdir: root, state: :starting, launched_at: DateTime.utc_now()})
  {:ok, window} = Foreman.SessionTmux.launch(session, "Remember this secret phrase for this scratch verification: amber otter 7391. Reply with that phrase only. Do not use tools or change files.", hook_executable: "/bin/true")
  Foreman.Repo.update!(Ecto.Changeset.change(session, window: window))
  {:ok, epic} = Foreman.Sessions.launch({"scratch", "draft:greeting"}, executable: "/bin/true")
  System.cmd("tmux", ["-L", socket, "kill-window", "-t", epic.window])
end
{:ok, _} = Foreman.SessionMonitor.start_link([])
IO.puts("PARK_ACCEPTANCE_READY")
Process.sleep(:infinity)
