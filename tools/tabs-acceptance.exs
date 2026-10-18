# MIX_ENV=test PORT=4766 FOREMAN_ROLE=web mix run --no-start --no-halt tools/tabs-acceptance.exs
# Separate committed-fixture DB; never reads or writes the installed board's DB.
update? = System.argv() == ["update"]
checkout = Path.basename(File.cwd!())
repo = Application.fetch_env!(:foreman, Foreman.Repo)

repo =
  Keyword.merge(repo,
    database: "foreman_tabs_acceptance_#{checkout}",
    pool: DBConnection.ConnectionPool
  )

Application.put_env(:foreman, Foreman.Repo, repo)
Application.put_env(:foreman, :runtime_enabled, false)
Application.put_env(:foreman, :role, "web")

Application.put_env(
  :foreman,
  ForemanWeb.Endpoint,
  Application.fetch_env!(:foreman, ForemanWeb.Endpoint)
  |> Keyword.put(:server, not update?)
  |> Keyword.put(:check_origin, ["//127.0.0.1:4766"])
)

{:ok, _} = Application.ensure_all_started(:ecto_sql)

case Ecto.Adapters.Postgres.storage_up(repo) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end

{:ok, _, _} =
  Ecto.Migrator.with_repo(Foreman.Repo, fn repo ->
    Ecto.Migrator.run(repo, "priv/repo/migrations", :up, all: true)
  end)

{:ok, _} = Application.ensure_all_started(:foreman)
key = {"sample", "fe-813.2"}

if update? do
  Foreman.Overlay.apply_event(key, :abandon)
  Foreman.Overlay.apply_event(key, :revive)
  Foreman.Overlay.apply_event(key, {:dispatch, %{window: "browser-live-worker"}})

  Foreman.Overlay.apply_event(
    key,
    {:report, %{body: "Browser hidden-tab update", path: "docs/sessions/bb-tabs.md"}},
    %{actor: "tab-builder"}
  )

  IO.puts("TABS_UPDATED")
else
  {:ok, config} =
    Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

  config =
    Map.put(config, "repos", [
      %{
        "key" => "sample",
        "path" => "/tmp/foreman-tabs-no-repo",
        "enabled" => true,
        "forge" => "github",
        "github" => "rpmessner/form-engine"
      }
    ])

  Foreman.Repo.insert_all(
    "board_config",
    [
      %{
        id: 1,
        config: config,
        source: "tabs acceptance",
        discovered: [],
        loaded_at: DateTime.utc_now()
      }
    ], on_conflict: {:replace, [:config]}, conflict_target: [:id])

  beads = [
    %{id: "fe-813", title: "Ticket workspace", status: "open", issue_type: "epic"},
    %{
      id: "fe-813.2",
      title: "Ticket sheet sections as tabs",
      status: "open",
      issue_type: "task",
      priority: 2,
      description: "Replace the ticket sheet's jump links with URL-driven tabs.",
      acceptance_criteria:
        "Overview · Stage history · Sessions · Agent notes\nKeyboard navigation and live updates.",
      dependencies: [%{depends_on_id: "fe-813", type: "parent-child"}]
    }
  ]

  Foreman.Beads.Projection.replace("sample", Enum.map_join(beads, "\n", &Jason.encode!/1))
  Foreman.Overlay.apply_event(key, :abandon)
  Foreman.Overlay.apply_event(key, :revive)
  Foreman.Overlay.apply_event(key, {:dispatch, %{window: "tab-builder", branch: "bb-tabs"}})

  Foreman.Overlay.apply_event(
    key,
    {:report,
     %{body: "URL selection and hidden-stream checks verified.", path: "docs/sessions/bb-tabs.md"}}
  )

  # Parse the captured forge response through the real adapter, without network access.
  Req.Test.stub(:tabs_acceptance, fn conn ->
    Req.Test.json(conn, Jason.decode!(File.read!("test/fixtures/forge/form-engine.json")))
  end)

  {:ok, snapshot} =
    Foreman.Forge.GitHub.list("rpmessner/form-engine",
      token: "fixture",
      plug: {Req.Test, :tabs_acceptance}
    )

  Foreman.Forge.Store.replace("sample", "rpmessner/form-engine", snapshot)
  IO.puts("TABS_ACCEPTANCE_READY")
end
