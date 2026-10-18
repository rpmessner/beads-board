# Explicitly authorized scratch-only run:
# FOREMAN_LIVE_MERGE_APPROVED=rpmessner/foreman-scratch MIX_ENV=test PORT=4769 FOREMAN_ROLE=web mix run --no-start tools/merge-live-acceptance.exs
# This transport records only response projections, never headers or credentials.
defmodule MergeLiveAcceptance do
  @remote "rpmessner/foreman-scratch"
  @fixtures "test/fixtures/forge/live-merge"

  def proxy(conn, token) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    payload = Jason.decode!(body)

    kind =
      case {conn.method, conn.request_path, payload} do
        {"POST", "/graphql",
         %{"variables" => %{"owner" => "rpmessner", "name" => "foreman-scratch"}}} ->
          "list"

        {"PUT", "/repos/#{@remote}/pulls/1/merge", %{"merge_method" => "merge", "sha" => sha}}
        when is_binary(sha) ->
          "merge"

        {"PATCH", "/repos/#{@remote}/pulls/2", %{"base" => "main"}} ->
          "retarget"

        _ ->
          raise "Request outside the authorized scratch acceptance scope"
      end

    {:ok, response} =
      Req.request(
        method: String.downcase(conn.method) |> String.to_existing_atom(),
        url: "https://api.github.com" <> conn.request_path,
        auth: {:bearer, token},
        json: payload,
        retry: false,
        redirect: false,
        receive_timeout: 15_000
      )

    projection =
      case kind do
        "list" ->
          scrub(response.body)

        "merge" ->
          Map.take(response.body, ["sha", "merged"])

        "retarget" ->
          %{
            "number" => response.body["number"],
            "base" => Map.take(response.body["base"] || %{}, ["ref"])
          }
      end

    phase = Application.get_env(:foreman, :live_acceptance_phase, "initial")
    request = if kind == "list", do: %{"tracked_query" => payload["query"]}, else: payload
    File.mkdir_p!(@fixtures)

    File.write!(
      "#{@fixtures}/#{phase}-#{kind}.json",
      Jason.encode!(%{status: response.status, request: request, response: projection},
        pretty: true
      ) <> "\n"
    )

    conn |> Plug.Conn.put_status(response.status) |> Req.Test.json(response.body)
  end

  defp scrub(value) when is_map(value), do: Map.new(value, fn {k, v} -> {k, scrub(v)} end)
  defp scrub(value) when is_list(value), do: Enum.map(value, &scrub/1)

  defp scrub(value) when is_binary(value),
    do: String.replace(value, @remote, "fixture-owner/merge-scratch")

  defp scrub(value), do: value

  def read do
    {:ok, snapshot} =
      Foreman.Forge.GitHub.list(@remote, Keyword.put(Foreman.Forge.options(), :tracked, [1, 2]))

    Foreman.Forge.Store.replace("scratch", @remote, snapshot)

    IO.inspect(
      Enum.map(
        snapshot["change_requests"],
        &Map.take(&1, ["number", "head_sha", "target_branch", "mergeable", "state"])
      ), label: "LIVE_SNAPSHOT")
  end

  def loop do
    receive do
      {:notification, _, _, "merge_live_acceptance", command} ->
        case String.split(command, ":", parts: 2) do
          ["phase", phase] when phase in ["moved", "merge", "retarget", "observed"] ->
            Application.put_env(:foreman, :live_acceptance_phase, phase)

          ["read"] ->
            read()

          ["drain"] ->
            IO.inspect(Oban.drain_queue(queue: :external_writes, with_limit: 1), label: "DRAIN")
        end

        IO.puts("LIVE_COMMAND #{command}")
        loop()
    end
  end
end

unless System.get_env("FOREMAN_LIVE_MERGE_APPROVED") == "rpmessner/foreman-scratch",
  do: raise("Explicit scratch approval required")

unless System.get_env("PORT") == "4769", do: raise("Acceptance requires isolated port 4769")

config =
  Application.fetch_env!(:foreman, Foreman.Repo)
  |> Keyword.put(:database, "foreman_merge_live_acceptance")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)

Application.put_env(:foreman, Foreman.Repo, config)
Application.put_env(:foreman, :runtime_enabled, false)
Application.put_env(:foreman, :forge_adapter, Foreman.Forge.GitHub)

Application.put_env(
  :foreman,
  ForemanWeb.Endpoint,
  Application.fetch_env!(:foreman, ForemanWeb.Endpoint)
  |> Keyword.put(:server, true)
  |> Keyword.put(:check_origin, false)
)

{:ok, _} = Application.ensure_all_started(:ecto_sql)

case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end

{:ok, _, _} =
  Ecto.Migrator.with_repo(
    Foreman.Repo,
    &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true)
  )

{:ok, _} = Application.ensure_all_started(:foreman)
{token, 0} = System.cmd("gh", ["auth", "token"])
token = String.trim(token)

Application.put_env(:foreman, :forge_options,
  token: token,
  plug: fn conn -> MergeLiveAcceptance.proxy(conn, token) end
)

{:ok, defaults} =
  Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

repo = %{
  "key" => "scratch",
  "path" => "/tmp/bb-scratch-no-beads",
  "enabled" => true,
  "forge" => "github",
  "github" => "rpmessner/foreman-scratch"
}

Foreman.Repo.insert_all(
  "board_config",
  [
    %{
      id: 1,
      config: Map.put(defaults, "repos", [repo]),
      source: "authorized live acceptance",
      discovered: [],
      loaded_at: DateTime.utc_now()
    }
  ], on_conflict: {:replace, [:config]}, conflict_target: [:id])

beads = [
  %{id: "bb-live", title: "Live merge acceptance", status: "open", issue_type: "epic"},
  %{
    id: "bb-live.1",
    title: "Guarded merge",
    status: "open",
    issue_type: "task",
    dependencies: [%{depends_on_id: "bb-live", type: "parent-child"}]
  }
]

Foreman.Beads.Projection.replace("scratch", Enum.map_join(beads, "\n", &Jason.encode!/1))
Foreman.RuntimeState.record("scratch", {:ok, :changed})
MergeLiveAcceptance.read()

{:ok, notifications} =
  Postgrex.Notifications.start_link(
    Keyword.take(config, [:username, :password, :hostname, :database])
  )

{:ok, _} = Postgrex.Notifications.listen(notifications, "merge_live_acceptance")
IO.puts("MERGE_LIVE_ACCEPTANCE_READY")
MergeLiveAcceptance.loop()
