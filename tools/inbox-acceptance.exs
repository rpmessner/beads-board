# MIX_ENV=acceptance BOARD_ROLE=web PORT=4771 PHX_SERVER=true mix run --no-halt tools/inbox-acceptance.exs
# Inherit BOARD_TOKEN_FILE. No installed service, reader or beads store is touched.
if Mix.env() != :acceptance or
     Board.Repo.config()[:database] != "beads_board_acceptance_#{Path.basename(File.cwd!())}",
  do: raise("acceptance requires its checkout-local database")

endpoint = Application.fetch_env!(:board, BoardWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4771"])
BoardWeb.Endpoint.config_change([{BoardWeb.Endpoint, endpoint}], [])
{:ok, config} = Board.Config.parse_layers([{"defaults", File.read!("priv/board.defaults.toml")}])
config = Map.put(config, "repos", [%{"key" => "scratch", "path" => Path.expand("tmp/scratch"), "enabled" => true, "forge" => "none"}])
Board.Repo.insert_all("board_config", [%{id: 1, config: config, stores: %{}, discovered: [], source: "inbox acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Board.Beads.Projection.replace("scratch", Jason.encode!(%{id: "scratch-1", title: "Build-time layout decision", status: "open", issue_type: "task", priority: 2}))
IO.puts("INBOX_ACCEPTANCE_READY")
