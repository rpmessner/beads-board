# MIX_ENV=test PORT=4766 BOARD_ROLE=web mix run --no-start --no-halt tools/tabs-acceptance.exs
# Separate committed-fixture DB; never reads or writes the installed board's DB.
update? = System.argv() == ["update"]
checkout = Path.basename(File.cwd!())
repo = Application.fetch_env!(:board, Board.Repo)

repo =
  Keyword.merge(repo,
    database: "beads_board_tabs_acceptance_#{checkout}",
    pool: DBConnection.ConnectionPool
  )

Application.put_env(:board, Board.Repo, repo)
Application.put_env(:board, :runtime_enabled, false)
Application.put_env(:board, :role, "web")

Application.put_env(
  :board,
  BoardWeb.Endpoint,
  Application.fetch_env!(:board, BoardWeb.Endpoint)
  |> Keyword.put(:server, not update?)
  |> Keyword.put(:check_origin, ["//127.0.0.1:4766"])
)

{:ok, _} = Application.ensure_all_started(:ecto_sql)

case Ecto.Adapters.Postgres.storage_up(repo) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end

{:ok, _, _} =
  Ecto.Migrator.with_repo(Board.Repo, fn repo ->
    Ecto.Migrator.run(repo, "priv/repo/migrations", :up, all: true)
  end)

{:ok, _} = Application.ensure_all_started(:board)
key = {"sample", "fe-813.2"}

if update? do
  Board.Overlay.apply_event(key, :abandon)
  Board.Overlay.apply_event(key, :revive)
  Board.Overlay.apply_event(key, {:dispatch, %{window: "browser-live-worker"}})

  Board.Overlay.apply_event(
    key,
    {:report, %{body: "Browser hidden-tab update", path: "docs/sessions/bb-tabs.md"}},
    %{actor: "tab-builder"}
  )

  IO.puts("TABS_UPDATED")
else
  {:ok, config} =
    Board.Config.parse_layers([{"defaults", File.read!("priv/board.defaults.toml")}])

  config =
    Map.put(config, "repos", [
      %{
        "key" => "sample",
        "path" => "/tmp/board-tabs-no-repo",
        "enabled" => true,
        "forge" => "github",
        "github" => "rpmessner/form-engine"
      }
    ])

  Board.Repo.insert_all(
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

  Board.Beads.Projection.replace("sample", Enum.map_join(beads, "\n", &Jason.encode!/1))
  Board.Overlay.apply_event(key, :abandon)
  Board.Overlay.apply_event(key, :revive)
  Board.Overlay.apply_event(key, {:dispatch, %{window: "tab-builder", branch: "bb-tabs"}})

  Board.Overlay.apply_event(
    key,
    {:report,
     %{body: "URL selection and hidden-stream checks verified.", path: "docs/sessions/bb-tabs.md"}}
  )

  # Parse the captured forge response through the real adapter, without network access.
  Req.Test.stub(:tabs_acceptance, fn conn ->
    Req.Test.json(conn, Jason.decode!(File.read!("test/fixtures/forge/form-engine.json")))
  end)

  {:ok, snapshot} =
    Board.Forge.GitHub.list("rpmessner/form-engine",
      token: "fixture",
      plug: {Req.Test, :tabs_acceptance}
    )

  Board.Forge.Store.replace("sample", "rpmessner/form-engine", snapshot)
  IO.puts("TABS_ACCEPTANCE_READY")
end
