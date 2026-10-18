defmodule Board.AgentCatalog do
  @moduledoc "Resolves stable identities from the shared config and observed bead prefixes."
  import Ecto.Query
  alias Board.Repo

  def resolve(%{"id" => id} = request, repos) when is_binary(id) and byte_size(id) > 0 do
    prefix = id |> String.split("-", parts: 2) |> hd()
    matches = Enum.filter(repos, &(prefix in &1["prefixes"]))
    draft? = String.starts_with?(id, "draft:") or (request["kind"] == "epic" and matches == [])
    id = if draft? and not String.starts_with?(id, "draft:"), do: "draft:" <> id, else: id

    candidates =
      cond do
        is_binary(request["project"]) ->
          Enum.filter(repos, &(&1["key"] == request["project"]))

        draft? ->
          cwd = Path.expand(request["cwd"] || "/")

          repos
          |> Enum.filter(
            &(cwd == &1["path"] or
                String.starts_with?(cwd, String.trim_trailing(&1["path"], "/") <> "/"))
          )
          |> Enum.sort_by(&byte_size(&1["path"]), :desc)
          |> Enum.take(1)

        true ->
          matches
      end

    case candidates do
      [repo] -> {:ok, {repo["key"], id}}
      [] -> {:error, :unknown_project}
      _ -> {:error, :ambiguous_prefix}
    end
  end

  def resolve(_, _), do: {:error, :invalid_id}

  def list do
    snapshot = Board.RuntimeState.config()

    for repo <- (snapshot && snapshot.config["repos"]) || [], repo["enabled"] do
      ids = Repo.all(from b in "beads", where: b.repo_key == ^repo["key"], select: b.bead_id)

      Map.put(
        repo,
        "prefixes",
        ids |> Enum.map(&(String.split(&1, "-", parts: 2) |> hd())) |> Enum.uniq()
      )
    end
  end
end
