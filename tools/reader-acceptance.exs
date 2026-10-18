# MIX_ENV=test PORT=4779 mix run --no-start --no-halt tools/reader-acceptance.exs
# Only this worktree's acceptance database and a newly-created temporary git repo.
root = Path.join(System.tmp_dir!(), "fm-reader-browser-#{System.os_time(:millisecond)}")
File.mkdir_p!(Path.join(root, "tickets"))
System.cmd("git", ["init", "-q", root])
config_dir = Path.join(root, "config")
File.mkdir_p!(config_dir)
File.write!(Path.join(config_dir, "foreman.toml"), "[[repos]]\nkey = \"reader\"\npath = #{Jason.encode!(root)}\nprefix = \"demo\"\ntickets = \"files\"\nforge = \"none\"\n")
File.write!(Path.join(root, "tickets/demo-abc.md"), "---\nid: demo-abc\ntitle: Browser initial\ntype: task\nstatus: open\npriority: 2\nparent: null\nblocked_by: []\nrelated: []\ndiscovered_from: null\nlabels: []\ncreated: 2026-10-18\nclosed: null\nclose_reason: null\n---\n\n## Acceptance\n- [x] First\n- [ ] Second\n")
repo = Application.fetch_env!(:foreman, Foreman.Repo) |> Keyword.merge(database: "foreman_reader_acceptance_#{Path.basename(File.cwd!())}", pool: DBConnection.ConnectionPool)
Application.put_env(:foreman, Foreman.Repo, repo)
Application.put_env(:foreman, :runtime_enabled, true)
Application.put_env(:foreman, :role, "all")
Application.put_env(:foreman, :config_directory, config_dir)
Application.put_env(:foreman, :discovery_root, root)
Application.put_env(:foreman, ForemanWeb.Endpoint, Application.fetch_env!(:foreman, ForemanWeb.Endpoint) |> Keyword.merge(server: true, check_origin: ["//127.0.0.1:4779"]))
{:ok, _} = Application.ensure_all_started(:ecto_sql)
case Ecto.Adapters.Postgres.storage_up(repo) do
  :ok -> :ok
  {:error, :already_up} -> :ok
end
{:ok, _, _} = Ecto.Migrator.with_repo(Foreman.Repo, &Ecto.Migrator.run(&1, "priv/repo/migrations", :up, all: true))
{:ok, _} = Application.ensure_all_started(:foreman)
Foreman.Config.ReloadJob.perform(nil)
File.write!("/tmp/fm-reader-browser-root", root)
IO.puts("READER_ACCEPTANCE_READY #{root}")
