defmodule Board.Config do
  @moduledoc """
  TOML configuration boundary. Takes named file contents in precedence order;
  filesystem reads belong in the runtime's Oban adapter. Keys remain strings.

  Tables merge recursively. Columns and views replace in full. Repos merge by key (a local
  entry can override just `enabled`); `repos = []` clears the inherited list.
  """

  @defaults_path Path.expand("../../priv/board.defaults.toml", __DIR__)
  @external_resource @defaults_path
  @default_views @defaults_path
                 |> File.read!()
                 |> TomlElixir.decode(spec: :"1.0.0")
                 |> elem(1)
                 |> Map.fetch!("views")

  @doc "Resolve presets for snapshots saved before views were configurable."
  def views(config), do: Map.get(config, "views", @default_views)

  @doc "Read defaults and the two optional files. Call from an Oban job in the runtime."
  def load(directory, opts \\ []) do
    defaults = Application.app_dir(:board, "priv/board.defaults.toml")

    files = [
      {defaults, false},
      {Path.join(directory, "board.toml"), true},
      {Path.join(directory, "board.local.toml"), true}
    ]

    Enum.reduce_while(files, {:ok, []}, fn {path, optional?}, {:ok, layers} ->
      case File.read(path) do
        {:ok, text} ->
          {:cont, {:ok, layers ++ [{Path.basename(path), text}]}}

        {:error, :enoent} when optional? ->
          {:cont, {:ok, layers}}

        {:error, reason} ->
          {:halt, {:error, "#{Path.basename(path)}: #{:file.format_error(reason)}"}}
      end
    end)
    |> case do
      {:ok, layers} -> parse_layers(layers, opts)
      error -> error
    end
  end

  def parse_layers(layers, opts \\ []) do
    Enum.reduce_while(layers, {:ok, %{}}, fn {source, text}, {:ok, config} ->
      case TomlElixir.decode(text, spec: :"1.0.0") do
        {:ok, layer} ->
          case Board.Config.Schema.validate(layer) do
            :ok -> {:cont, {:ok, merge(config, layer)}}
            {:error, error} -> {:halt, {:error, "#{source}: #{error}"}}
          end

        {:error, _reason} ->
          {:halt, {:error, "#{source}: invalid TOML"}}
      end
    end)
    |> normalise(Keyword.get(opts, :home, System.user_home!()))
  end

  defp merge(left, right) do
    Map.merge(left, right, fn
      "repos", inherited, overrides when is_list(inherited) and is_list(overrides) ->
        merge_repos(inherited, overrides)

      _, a, b when is_map(a) and is_map(b) ->
        merge(a, b)

      _, _, b ->
        b
    end)
  end

  defp merge_repos(_, []), do: []

  defp merge_repos(inherited, overrides) do
    Enum.reduce(overrides, inherited, fn repo, repos ->
      case Enum.find_index(repos, &(&1["key"] == repo["key"])) do
        nil -> repos ++ [repo]
        index -> List.update_at(repos, index, &merge(&1, repo))
      end
    end)
  end

  defp normalise({:error, _} = error, _home), do: error

  defp normalise({:ok, config}, home) do
    with :ok <- Board.Config.Schema.validate(config, true) do
      expand(config, home)
    end
  end

  defp expand(config, home) do
    config =
      config
      |> Map.update!("columns", fn columns ->
        Enum.map(columns, &Map.put_new(&1, "collapsed", false))
      end)
      |> Map.update!("repos", fn repos ->
        Enum.map(repos, fn repo ->
          repo
          |> Map.put_new("enabled", true)
          |> Map.put_new("forge", if(repo["github"], do: "github", else: "none"))
          |> Map.put_new("color", "zinc")
          |> Map.update!("path", fn
            "~/" <> relative -> Path.expand(relative, home)
            path -> Path.expand(path)
          end)
        end)
      end)

    with :ok <- Board.Config.Schema.unique(config["repos"], "path", "repos") do
      {:ok, config}
    end
  end
end
