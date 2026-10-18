defmodule Board.Config.ReloadJob do
  @moduledoc "Serializes config installation and last-good retention in Postgres."
  use Oban.Worker,
    queue: :external_reads,
    max_attempts: 1,
    unique: [period: :infinity, states: :incomplete]

  alias Board.Config.Reload
  alias Board.Repo

  def enqueue, do: new(%{}) |> Oban.insert()

  @impl true
  def perform(_job) do
    directory = Application.fetch_env!(:board, :config_directory)

    Repo.transaction(fn ->
      Repo.query!("SELECT pg_advisory_xact_lock(83467219)")
      previous = Board.RuntimeState.config()

      {:ok, defaults} =
        Board.Config.parse_layers([
          {"defaults", File.read!(Application.app_dir(:board, "priv/board.defaults.toml"))}
        ])

      initial = Reload.new(if(previous, do: previous.config, else: defaults))
      {loading, [read: {:config, generation}]} = Reload.request(initial)
      result = Board.Config.load(directory)
      {completed, effects} = Reload.complete(loading, generation, result)
      discovered = discover(Application.get_env(:board, :discovery_root, Path.expand("~/dev")))

      row = %{
        id: 1,
        config: completed.config,
        error: completed.error,
        source: directory,
        discovered: discovered,
        stores: Map.new(completed.config["repos"], fn repo -> {repo["key"], store(repo)} end),
        loaded_at:
          if(completed.error && previous, do: previous.loaded_at, else: DateTime.utc_now())
      }

      fields = [:config, :error, :source, :discovered, :stores]

      unless previous && Map.take(previous, fields) == Map.take(row, fields) do
        Repo.insert_all("board_config", [row],
          on_conflict: {:replace, Map.keys(row) -- [:id]},
          conflict_target: [:id]
        )

        Enum.each(effects, fn {:broadcast, :config} ->
          Board.Events.broadcast(:config_changed, "config")
        end)
      end
    end)

    :ok
  end

  defp store(repo) do
    case Board.Beads.Store.resolve(repo["path"]) do
      {:ok, physical, identity} ->
        %{"identity" => identity, "path" => physical, "mode" => "embedded"}

      {:error, :server_mode} ->
        %{"identity" => "unreachable:" <> repo["key"], "mode" => "server mode"}

      _ ->
        %{"identity" => "unreachable:" <> repo["key"], "mode" => "unknown"}
    end
  end

  defp discover(root), do: walk(root, 0) |> Enum.sort()
  defp walk(_, depth) when depth > 8, do: []

  defp walk(path, depth) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} ->
        found = if File.dir?(Path.join(path, ".beads")), do: [path], else: []

        children =
          case File.ls(path) do
            {:ok, entries} ->
              entries
              |> Enum.reject(
                &(&1 in [".beads", ".git", "node_modules", "deps", "_build", ".cache"])
              )
              |> Enum.flat_map(&walk(Path.join(path, &1), depth + 1))

            _ ->
              []
          end

        found ++ children

      _ ->
        []
    end
  end
end
