defmodule Foreman.Forge.Stack do
  @moduledoc "Pure stack ordering and bead reference extraction. Cycles are detached, never roots."
  def order(prs, default) do
    prs = Enum.filter(prs, &(&1["state"] == "open")) |> Enum.sort_by(& &1["number"])
    roots = Enum.filter(prs, &(&1["target_branch"] == default))
    {ordered, seen} = walk(roots, prs, 0, false, MapSet.new(), nil)

    {rest, _} =
      walk(Enum.reject(prs, &MapSet.member?(seen, &1["number"])), prs, 0, true, seen, nil)

    ordered ++ rest
  end

  defp walk(nodes, all, depth, detached, seen, parent) do
    Enum.reduce(nodes, {[], seen}, fn pr, {rows, seen} ->
      if MapSet.member?(seen, pr["number"]) do
        {rows, seen}
      else
        seen = MapSet.put(seen, pr["number"])
        children = Enum.filter(all, &(&1["target_branch"] == pr["source_branch"]))
        {children, seen} = walk(children, all, depth + 1, detached, seen, pr["number"])
        row = Map.merge(pr, %{"depth" => depth, "detached" => detached, "parent" => parent})
        {rows ++ [row | children], seen}
      end
    end)
  end

  def links(pr, prefix) do
    regex = Regex.compile!("\\b" <> Regex.escape(prefix) <> "-[a-z0-9]+(?:\\.\\d+)*\\b")

    [{"title", "title"}, {"source_branch", "branch"}, {"body", "body"}]
    |> Enum.flat_map(fn {field, source} ->
      Regex.scan(regex, pr[field] || "")
      |> Enum.map(fn [id] -> %{"bead_id" => id, "source" => source} end)
    end)
    |> Enum.uniq_by(& &1["bead_id"])
  end
end
