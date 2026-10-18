# MIX_ENV=acceptance FOREMAN_ROLE=web PORT=4783 PHX_SERVER=true mix run --no-halt tools/drawer-acceptance.exs
if Mix.env() != :acceptance or
     Foreman.Repo.config()[:database] != "foreman_acceptance_#{Path.basename(File.cwd!())}",
  do: raise("acceptance requires its checkout-local database")

endpoint = Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4783"])
ForemanWeb.Endpoint.config_change([{ForemanWeb.Endpoint, endpoint}], [])
{:ok, config} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
config = Map.put(config, "repos", [%{"key" => "scratch", "path" => Path.expand("tmp/drawer-scratch"), "enabled" => true, "forge" => "none"}])
File.mkdir_p!("tmp/drawer-scratch/docs")
File.write!("tmp/drawer-scratch/docs/guide.md", "# Scratch guide\n\nDrawer acceptance fixture.\n")
Foreman.Repo.insert_all("board_config", [%{id: 1, config: config, stores: %{}, discovered: [], source: "drawer acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Foreman.Beads.Projection.replace("scratch", Jason.encode!(%{id: "scratch-1", title: "Layout decision", status: "open", issue_type: "task", priority: 2}))
IO.puts("DRAWER_ACCEPTANCE_READY")
