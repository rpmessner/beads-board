# MIX_ENV=acceptance FOREMAN_ROLE=web PORT=4771 PHX_SERVER=true mix run --no-halt tools/inbox-acceptance.exs
# Inherit FOREMAN_TOKEN_FILE. No installed service, reader or beads store is touched.
if Mix.env() != :acceptance or
     Foreman.Repo.config()[:database] != "foreman_acceptance_#{Path.basename(File.cwd!())}",
  do: raise("acceptance requires its checkout-local database")

endpoint = Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4771"])
ForemanWeb.Endpoint.config_change([{ForemanWeb.Endpoint, endpoint}], [])
{:ok, config} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
config = Map.put(config, "repos", [%{"key" => "scratch", "path" => Path.expand("tmp/scratch"), "enabled" => true, "forge" => "none"}])
Foreman.Repo.insert_all("board_config", [%{id: 1, config: config, stores: %{}, discovered: [], source: "inbox acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Foreman.Beads.Projection.replace("scratch", Jason.encode!(%{id: "scratch-1", title: "Build-time layout decision", status: "open", issue_type: "task", priority: 2}))
IO.puts("INBOX_ACCEPTANCE_READY")
