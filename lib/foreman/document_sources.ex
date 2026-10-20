defmodule Foreman.DocumentSources do
  @moduledoc """
  Board document resolution. Source tokens identify recorded roots, never grant access.
  Main wins over ticket worktrees. Reads re-query board records and revalidate git membership.
  The CLI's broader `--doc` worktree lookup is deliberately not used here.
  """
  import Ecto.Query
  alias Foreman.{CardText, Documents, Repo}

  def token(root), do: "wt-" <> Base.url_encode64(:crypto.hash(:sha256, root), padding: false)

  def recorded(%{document_roots: roots}), do: roots

  def recorded(ticket) do
    (Enum.flat_map(ticket.sessions, &paths(&1.details)) ++
       Enum.flat_map(ticket.history, &paths(&1.payload)))
    |> Enum.filter(&(Path.type(&1) == :absolute and ".." not in Path.split(&1)))
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
  end

  defp paths(map) when is_map(map) do
    Enum.flat_map(map, fn
      {key, value} when key in ["workdir", "worktree"] and is_binary(value) -> [value]
      {_, value} -> paths(value)
    end)
  end

  defp paths(list) when is_list(list), do: Enum.flat_map(list, &paths/1)
  defp paths(_), do: []

  defp recorded_for_repo(repo) do
    sessions = Repo.all(from s in "sessions", where: s.repo_key == ^repo, select: s.details)
    history = Repo.all(from e in "stage_events", where: e.repo_key == ^repo, select: e.payload)

    recorded(%{
      sessions: Enum.map(sessions, &%{details: &1}),
      history: Enum.map(history, &%{payload: &1})
    })
  end

  @doc "A mention as `{repo, relative_path, :main | source_token}`. Ticket worktrees only."
  def resolve(path, key, repos, ticket) when is_binary(path) do
    if ".." not in Path.split(path) do
      path = if String.starts_with?(path, "~/"), do: Path.expand(path), else: path
      roots = recorded(ticket)
      main = CardText.resolve(path, key, repos)

      if main do
        {repo, relative} = main
        {repo, Path.relative_to(Path.expand(relative, "/"), "/"), :main}
      else
        repos
        |> Enum.filter(&(&1["key"] == key))
        |> Enum.find_value(fn repo ->
          Enum.find_value(roots, fn root ->
            if worktree?(repo["path"], root) or File.lstat(root) == {:error, :enoent} do
              relative = relative(path, root)

              if relative do
                cond do
                  Documents.document?(repo["path"], relative) ->
                    {repo["key"], relative, :main}

                  worktree?(repo["path"], root) and Documents.document?(root, relative) ->
                    {repo["key"], relative, token(root)}

                  true ->
                    nil
                end
              end
            end
          end)
        end)
      end
    end
  end

  def resolve(_, _, _, _), do: nil

  @doc "Authorize a panel/viewer read from current board records, not caller-supplied roots."
  def open(repo_key, path, source \\ nil) do
    repo = Enum.find(CardText.repos(), &(&1["key"] == repo_key))

    with %{} <- repo,
         true <- is_binary(path) and ".." not in Path.split(path) do
      roots = recorded_for_repo(repo_key)
      do_open(repo, path, source, roots)
    else
      _ -> {:error, :refused}
    end
  end

  defp do_open(repo, path, source, roots) when source in [nil, ""] do
    ticket = %{sessions: Enum.map(roots, &%{details: %{"workdir" => &1}}), history: []}

    case resolve(path, repo["key"], [repo], ticket) do
      {_, relative, :main} ->
        read(repo["path"], relative, :main)

      {_, relative, token} ->
        do_open(repo, relative, token, roots)

      nil ->
        if Foreman.Overlay.document_reference?(repo["key"], path),
          do: Documents.read_recorded(repo["path"], path) |> with_source(:main),
          else: {:error, :refused}
    end
  end

  defp do_open(repo, path, source, roots) do
    with root when is_binary(root) <- Enum.find(roots, &(token(&1) == source)),
         true <- worktree?(repo["path"], root) or File.lstat(root) == {:error, :enoent},
         relative when is_binary(relative) <- relative(path, root) do
      cond do
        Documents.document?(repo["path"], relative) -> read(repo["path"], relative, :main)
        worktree?(repo["path"], root) -> read(root, relative, source, Path.basename(root))
        true -> {:error, :refused}
      end
    else
      _ -> {:error, :refused}
    end
  end

  defp read(root, path, source, label \\ nil) do
    if Documents.document?(root, path),
      do: Documents.read(root, path) |> with_source(source, label),
      else: {:error, :refused}
  end

  defp with_source(result, source, label \\ nil)

  defp with_source({:ok, doc}, source, label),
    do: {:ok, Map.merge(doc, %{source: source, worktree: label})}

  defp with_source(error, _, _), do: error

  defp relative(path, root) do
    if Path.type(path) == :absolute do
      if String.starts_with?(path, root <> "/"), do: Path.relative_to(path, root)
    else
      Path.relative_to(Path.expand(path, "/"), "/")
    end
  end

  @doc "Exact, extant, non-symlinked git worktree of this configured repo."
  def worktree?(main, root) do
    with true <- Path.expand(main) != root,
         true <- directory?(root),
         {output, 0} <-
           System.cmd("git", ["-C", main, "worktree", "list", "--porcelain", "-z"],
             stderr_to_stdout: true
           ),
         true <- ("worktree " <> root) in String.split(output, <<0>>),
         {top, 0} <-
           System.cmd("git", ["-C", root, "rev-parse", "--show-toplevel"], stderr_to_stdout: true),
         true <- String.trim(top) == root,
         {main_common, 0} <- common_dir(main),
         {tree_common, 0} <- common_dir(root) do
      String.trim(main_common) == String.trim(tree_common)
    else
      _ -> false
    end
  end

  defp common_dir(root),
    do:
      System.cmd("git", ["-C", root, "rev-parse", "--path-format=absolute", "--git-common-dir"],
        stderr_to_stdout: true
      )

  defp directory?(root) do
    root
    |> Path.split()
    |> Enum.scan(&Path.join(&2, &1))
    |> Enum.all?(fn part -> match?({:ok, %{type: :directory}}, File.lstat(part)) end)
  end
end
