defmodule Foreman.BlockingGraph do
  @moduledoc "Deterministic blocker-to-blocked layers. Cyclic remainder stays visible in a final layer."
  def layout(edges, tickets, beads, fallout) do
    keys =
      (Enum.map(tickets, & &1.key) ++ Enum.flat_map(edges, &[&1.from, &1.to]))
      |> Enum.uniq()
      |> Enum.sort_by(&Foreman.Beads.Id.sort_key/1)

    parents = Enum.group_by(edges, & &1.to, & &1.from)
    ranks = layers(keys, parents, %{}, 0)

    nodes =
      keys
      |> Enum.group_by(&ranks[&1])
      |> Enum.sort()
      |> Enum.flat_map(fn {column, keys} ->
        keys
        |> Enum.with_index()
        |> Enum.map(fn {key, row} ->
          ticket = Enum.find(tickets, &(&1.key == key))
          raw = Map.get(beads, key, %{})

          %{
            id: Base.url_encode64(elem(key, 0) <> "/" <> elem(key, 1), padding: false),
            key: key,
            title: raw["title"] || elem(key, 1),
            stage: ticket && ticket.stage,
            external: is_nil(ticket),
            fallout: MapSet.member?(fallout, key),
            x: 20 + column * 250,
            y: 20 + row * 110
          }
        end)
      end)

    positions = Map.new(nodes, &{&1.key, &1})

    edges =
      edges
      |> Enum.uniq()
      |> Enum.with_index()
      |> Enum.map(fn {edge, index} ->
        from = positions[edge.from]
        to = positions[edge.to]
        x1 = from.x + 190
        y1 = from.y + 40
        x2 = to.x
        y2 = to.y + 40

        %{
          id: index,
          from: edge.from,
          to: edge.to,
          path: "M #{x1} #{y1} C #{x1 + 30} #{y1}, #{x2 - 30} #{y2}, #{x2} #{y2}"
        }
      end)

    %{
      nodes: nodes,
      edges: edges,
      width: Enum.reduce(nodes, 460, &max(&1.x + 210, &2)),
      height: Enum.reduce(nodes, 120, &max(&1.y + 100, &2))
    }
  end

  defp layers([], _, ranks, _), do: ranks

  defp layers(keys, parents, ranks, depth) do
    {ready, remaining} =
      Enum.split_with(keys, fn key ->
        Enum.all?(Map.get(parents, key, []), &Map.has_key?(ranks, &1))
      end)

    case ready do
      [] ->
        Enum.reduce(remaining, ranks, &Map.put(&2, &1, depth))

      _ ->
        layers(remaining, parents, Enum.reduce(ready, ranks, &Map.put(&2, &1, depth)), depth + 1)
    end
  end
end
