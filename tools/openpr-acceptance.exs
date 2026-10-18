# MIX_ENV=acceptance FOREMAN_ROLE=web PORT=4774 PHX_SERVER=true mix run --no-start tools/openpr-acceptance.exs
# Only actual Oban request jobs may write; this transport confines API calls to scratch.
defmodule OpenPrAcceptance do
  @remote "rpmessner/beads-board-scratch"
  @out "docs/acceptance/fm-openpr"
  @ticket System.get_env("FM_OPENPR_TICKET", "openpr-1")

  def proxy(conn, token) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    payload = if body == "", do: nil, else: Jason.decode!(body)
    kind = case {conn.method, conn.request_path, payload} do
      {"POST", "/graphql", %{"variables" => %{"owner" => "rpmessner", "name" => "beads-board-scratch"}}} -> "list"
      {"GET", "/repos/" <> @remote <> "/git/ref/heads/" <> _, _} -> "branch"
      {"POST", "/repos/" <> @remote <> "/pulls", %{"head" => "acceptance/fm-openpr-" <> _, "base" => "main"}} -> "create"
      _ -> raise "Outside authorized scratch scope"
    end
    method = if conn.method == "GET", do: :get, else: :post
    opts = [method: method, url: "https://api.github.com" <> conn.request_path, auth: {:bearer, token}, retry: false, redirect: false, receive_timeout: 15_000]
    {:ok, response} = Req.request(if payload, do: Keyword.put(opts, :json, payload), else: opts)
    projection = if kind == "create", do: Map.take(response.body, ["number", "html_url", "title", "body", "head", "base", "message"]), else: response.body
    projection = if kind == "create" do
      Enum.reduce(["head", "base"], projection, fn key, acc -> Map.update(acc, key, nil, &Map.take(&1, ["ref", "sha"])) end)
    else
      projection
    end
    File.mkdir_p!(@out)
    phase = Application.get_env(:foreman, :acceptance_phase, "initial")
    File.write!("#{@out}/#{phase}-#{kind}.json", Jason.encode!(%{status: response.status, request: payload, response: projection}, pretty: true) <> "\n")
    conn |> Plug.Conn.put_status(response.status) |> Req.Test.json(response.body)
  end

  def read do
    Foreman.Repo.update_all("forge_snapshots", set: [attempted_at: NaiveDateTime.add(NaiveDateTime.utc_now(), -121)])
    {:ok, _} = Foreman.Forge.SyncJob.enqueue("scratch", true)
    %{success: 1} = Oban.drain_queue(queue: :external_reads)
    Foreman.Forge.Store.get("scratch").snapshot
  end

  def loop do
    receive do
    after
      250 ->
        result = Oban.drain_queue(queue: :external_writes, with_limit: 1)
        if result.success > 0 or result.failure > 0 do
          # Capture stage before any observed forge read.
          before = Foreman.Overlay.get({"scratch", @ticket}).stage
          Application.put_env(:foreman, :acceptance_phase, "observed")
          snapshot = read()
          after_read = Foreman.Overlay.get({"scratch", @ticket}).stage
          File.write!("#{@out}/observed-stage.json", Jason.encode!(%{before: before, after: after_read, snapshot: snapshot}, pretty: true))
          rows = Foreman.Repo.query!("SELECT event, from_state, to_state, payload, request_id::text FROM request_events ORDER BY id")
          File.write!("#{@out}/audit.json", Jason.encode!(%{columns: rows.columns, rows: rows.rows}, pretty: true))
          IO.inspect(result, label: "OPENPR_DRAIN")
        end
        loop()
    end
  end
end

unless Mix.env() == :acceptance and System.get_env("PORT") == "4774", do: raise("requires isolated acceptance port 4774")
config = Application.fetch_env!(:foreman, Foreman.Repo)
unless config[:database] == "foreman_acceptance_fm-openpr", do: raise("wrong database")
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.put(:check_origin, ["http://127.0.0.1:4774"]))
{:ok, _} = Application.ensure_all_started(:foreman)
{token, 0} = System.cmd("gh", ["auth", "token"])
token = String.trim(token)
Application.put_env(:foreman, :forge_options, token: token, plug: fn conn -> OpenPrAcceptance.proxy(conn, token) end)
{:ok, defaults} = Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])
repo = %{"key" => "scratch", "path" => "/tmp/fm-openpr-scratch", "enabled" => true, "forge" => "github", "github" => "rpmessner/beads-board-scratch"}
Foreman.Repo.insert_all("board_config", [%{id: 1, config: Map.put(defaults, "repos", [repo]), stores: %{}, discovered: [], source: "open PR acceptance", loaded_at: DateTime.utc_now()}], on_conflict: {:replace, [:config]}, conflict_target: [:id])
Foreman.Beads.Projection.replace("scratch", Jason.encode!(%{id: System.get_env("FM_OPENPR_TICKET", "openpr-1"), title: "Open named PR", status: "open", issue_type: "task", priority: 2}))
Foreman.Repo.update_all("tickets", set: [stage: "committed"])
Foreman.RuntimeState.record("scratch", {:ok, :changed})
OpenPrAcceptance.read()
IO.puts("OPENPR_ACCEPTANCE_READY")
OpenPrAcceptance.loop()
