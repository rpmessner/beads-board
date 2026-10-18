defmodule Board.Beads.Id do
  @moduledoc "Natural bead-id ordering, with numeric runs compared as integers at every depth."

  def sort_key({repo, id}), do: {repo, sort_key(id)}

  def sort_key(id) when is_binary(id) do
    parts =
      Regex.scan(~r/[0-9]+|[^0-9]+/, id)
      |> Enum.map(fn [part] ->
        case Integer.parse(part) do
          {number, ""} -> {:number, number}
          _ -> {:text, part}
        end
      end)

    {parts, id}
  end
end
