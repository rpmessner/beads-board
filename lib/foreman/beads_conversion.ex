defmodule Foreman.BeadsConversion do
  @moduledoc "Converts and compares the mapped ticket data; original records stay in external backups."
  def decode(text) do
    records = text |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)
    ids = Enum.map(records, & &1["id"])
    if length(ids) != length(Enum.uniq(ids)), do: raise(ArgumentError, "duplicate issue ids")
    records
  end

  def convert(records) do
    tickets =
      Map.new(records, fn record ->
        deps = Map.get(record, "dependencies", [])

        unless Enum.all?(deps, &(&1["type"] in ~w(blocks parent-child related discovered-from))),
          do: raise(ArgumentError, "unsupported dependency type")

        refs = fn type ->
          deps
          |> Enum.filter(&(&1["type"] == type))
          |> Enum.map(& &1["depends_on_id"])
          |> Enum.sort()
        end

        single = fn type ->
          case refs.(type) do
            [] -> nil
            [id] -> id
            _ -> raise ArgumentError, "multiple #{type} references cannot be represented"
          end
        end

        comments = Map.get(record, "comments", [])

        if Map.get(record, "comment_count", length(comments)) != length(comments),
          do: raise(ArgumentError, "incomplete comments for #{record["id"]}")

        facts = %{
          "id" => record["id"],
          "title" => record["title"],
          "type" => record["issue_type"],
          "status" => record["status"],
          "priority" => record["priority"],
          "created" => date(record["created_at"]),
          "closed" => date(record["closed_at"]),
          "close_reason" => record["close_reason"],
          "parent" => single.("parent-child"),
          "blocked_by" => refs.("blocks"),
          "related" => refs.("related"),
          "discovered_from" => single.("discovered-from"),
          "labels" => Enum.sort(Map.get(record, "labels", []))
        }

        case Foreman.TicketFile.validate(facts) do
          :ok -> :ok
          {:error, reason} -> raise ArgumentError, "#{record["id"]}: #{reason}"
        end

        notes =
          Enum.map_join(comments, "\n", fn c ->
            "- #{date(c["created_at"])} #{c["author"]}: " <>
              String.replace(c["text"], "\n", "\n  ")
          end)

        body =
          Enum.reject(
            [
              record["description"],
              section("Acceptance", record["acceptance_criteria"]),
              section("Design", record["design"]),
              section(
                "Notes",
                Enum.join(Enum.reject([record["notes"], notes], &(&1 in [nil, ""])), "\n\n")
              )
            ],
            &(&1 in [nil, ""])
          )
          |> Enum.join("\n\n")

        {:ok, ticket} =
          Foreman.TicketFile.parse(Foreman.TicketFile.print(%{facts: facts, body: body}))

        {facts["id"], ticket}
      end)

    if map_size(tickets) != length(records), do: raise(ArgumentError, "duplicate issue ids")
    {:ok, tickets}
  rescue
    e in [ArgumentError, KeyError, FunctionClauseError] -> {:error, Exception.message(e)}
  end

  def compare(records, tickets) do
    with {:ok, expected} <- convert(records) do
      actual = Map.new(tickets, fn {id, ticket} -> {id, Map.take(ticket, [:facts, :body])} end)

      if actual == expected and Enum.all?(records, &same_facts?(&1, tickets[&1["id"]])) do
        {:ok,
         %{
           count: length(records),
           comments: Enum.sum(Enum.map(records, &length(Map.get(&1, "comments", []))))
         }}
      else
        {:error, "comparison differs: counts, fields, dependencies or prose"}
      end
    end
  end

  # Independent reverse projection catches a converter that assigns an edge to the wrong field.
  defp same_facts?(_record, nil), do: false

  defp same_facts?(record, %{facts: facts}) do
    edges =
      Enum.flat_map(
        [
          {"blocks", facts["blocked_by"]},
          {"related", facts["related"]},
          {"parent-child", List.wrap(facts["parent"])},
          {"discovered-from", List.wrap(facts["discovered_from"])}
        ],
        fn {kind, ids} -> Enum.map(ids, &{kind, &1}) end
      )
      |> Enum.sort()

    source_edges =
      Map.get(record, "dependencies", [])
      |> Enum.map(&{&1["type"], &1["depends_on_id"]})
      |> Enum.sort()

    fields = [
      {"id", "id"},
      {"title", "title"},
      {"issue_type", "type"},
      {"status", "status"},
      {"priority", "priority"},
      {"close_reason", "close_reason"}
    ]

    edges == source_edges and
      Enum.all?(fields, fn {source, target} -> record[source] == facts[target] end) and
      Enum.sort(Map.get(record, "labels", [])) == Enum.sort(facts["labels"]) and
      date(record["created_at"]) == facts["created"] and
      date(record["closed_at"]) == facts["closed"]
  end

  defp date(nil), do: nil
  defp date(value), do: String.slice(value, 0, 10)
  defp section(_, value) when value in [nil, ""], do: nil
  defp section(name, value), do: "## #{name}\n" <> value
end
