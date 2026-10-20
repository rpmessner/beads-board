# MIX_ENV=test mix run --no-start tools/docpanel-seed.exs
# Pass PREVIEW_DATABASE from devserve ls; PG* select the preview's database server.
database = System.fetch_env!("PREVIEW_DATABASE")

unless String.starts_with?(database, "foreman_preview_fm_docpanel_"),
  do: raise("requires the docpanel preview database")

config =
  Application.fetch_env!(:foreman, Foreman.Repo)
  |> Keyword.merge(
    database: database,
    pool: DBConnection.ConnectionPool,
    username: System.fetch_env!("PGUSER"),
    password: System.fetch_env!("PGPASSWORD"),
    hostname: System.fetch_env!("PGHOST"),
    port: String.to_integer(System.fetch_env!("PGPORT"))
  )

Application.put_env(:foreman, Foreman.Repo, config)
Application.put_env(:foreman, :runtime_enabled, false)
Application.put_env(:foreman, :role, "web")
{:ok, _} = Application.ensure_all_started(:foreman)

{:ok, defaults} =
  Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

root = File.cwd!()
repo = %{"key" => "docpanel", "path" => root, "enabled" => true, "forge" => "none"}

Foreman.Repo.insert_all(
  "board_config",
  [
    %{
      id: 1,
      config: Map.put(defaults, "repos", [repo]),
      source: "docpanel preview",
      discovered: [],
      loaded_at: DateTime.utc_now()
    }
  ], on_conflict: {:replace, [:config]}, conflict_target: [:id])

rows = [
  %{id: "panel-epic", title: "Document panel acceptance", issue_type: "epic", status: "open"},
  %{
    id: "panel-1",
    title: "Read documents without losing the ticket",
    issue_type: "task",
    status: "open",
    description: "Read the [approved specification](docs/specs/doc-links.md).",
    dependencies: [%{depends_on_id: "panel-epic", type: "parent-child"}]
  }
]

Foreman.Beads.Projection.replace("docpanel", Enum.map_join(rows, "\n", &Jason.encode!/1))

Foreman.Overlay.apply_event(
  {"docpanel", "panel-epic"},
  {:dispatch, %{window: "fixture", spec: "docs/specs/doc-links.md"}}
)

Foreman.Overlay.apply_event(
  {"docpanel", "panel-1"},
  {:dispatch, %{window: "fixture", brief_path: "docs/briefs/fm-docpanel.md"}}
)

Foreman.Overlay.apply_event(
  {"docpanel", "panel-1"},
  {:report,
   %{
     path: "docs/specs/doc-links.md",
     body: "Read [the spec](docs/specs/doc-links.md) and docs/machines/card_panel.md."
   }}
)

IO.puts("Seeded isolated docpanel preview")
