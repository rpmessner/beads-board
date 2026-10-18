# MIX_ENV=acceptance FOREMAN_ROLE=web PORT=4773 PHX_SERVER=true mix run --no-start tools/push-acceptance.exs
# Only the push worker writes GitHub. This harness performs read-only forge calls.
defmodule PushAcceptance do
  @remote "rpmessner/beads-board-scratch"
  @out "docs/acceptance/fm-push"

  def read(token) do
    {:ok, snapshot} = Foreman.Forge.GitHub.list(@remote, token: token)
    File.mkdir_p!(@out)
    File.write!(Path.join(@out, "forge-read.json"), Jason.encode!(snapshot, pretty: true))
    Foreman.Forge.Store.replace("scratch", @remote, snapshot)
  end

  def loop do
    receive do
    after
      250 ->
        Foreman.Requests.reconcile_pushes()
        result = Oban.drain_queue(queue: :external_writes)
        if result.success > 0 or result.failure > 0 do
          rows = Foreman.Repo.query!("SELECT event, from_state, to_state, payload, request_id::text FROM request_events ORDER BY id")
          File.write!(Path.join(@out, "audit.json"), Jason.encode!(%{columns: rows.columns, rows: rows.rows}, pretty: true))
          IO.inspect(result, label: "PUSH_DRAIN")
        end
        loop()
    end
  end
end

unless Mix.env() == :acceptance and System.get_env("PORT") == "4773",
  do: raise("requires acceptance environment and isolated port 4773")
config = Application.fetch_env!(:foreman, Foreman.Repo)
unless config[:database] == "foreman_acceptance_fm-push", do: raise("wrong database")
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4773"]))
{:ok, _} = Application.ensure_all_started(:foreman)
{token, 0} = System.cmd("gh", ["auth", "token"])
token = String.trim(token)
Application.put_env(:foreman, :forge_options, token: token)
{:ok, defaults} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
repo = %{"key" => "scratch", "path" => "/tmp/fm-push-scratch", "enabled" => true, "forge" => "github", "github" => "rpmessner/beads-board-scratch"}
Foreman.Repo.insert_all("board_config", [%{id: 1, config: Map.put(defaults, "repos", [repo]), stores: %{}, discovered: [], source: "push acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
beads = [
  %{id: "push-1", title: "Publish named branch", status: "open", issue_type: "task", priority: 2},
  %{id: "push-2", title: "Publish one-off default branch", status: "open", issue_type: "task", priority: 2},
  %{id: "push-e", title: "Epic push guard", status: "open", issue_type: "epic", priority: 2},
  %{id: "push-e.1", title: "Epic ticket", status: "open", issue_type: "task", priority: 2, dependencies: [%{depends_on_id: "push-e", type: "parent-child"}]}
]
Foreman.Beads.Projection.replace("scratch", Enum.map_join(beads, "\n", &Jason.encode!/1))
Foreman.Repo.update_all("tickets", set: [stage: "committed"])
Foreman.RuntimeState.record("scratch", {:ok, :changed})
PushAcceptance.read(token)
IO.puts("PUSH_ACCEPTANCE_READY")
PushAcceptance.loop()
