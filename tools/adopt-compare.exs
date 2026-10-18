# Run with: mix run --no-start tools/adopt-compare.exs EXPORT.jsonl CHECKOUT
[export, root] = System.argv()
records = export |> File.read!() |> Foreman.BeadsConversion.decode()
{:ok, tickets} = Foreman.TicketStore.load(root)
[] = Foreman.TicketStore.check(root)
{:ok, comparison} = Foreman.BeadsConversion.compare(records, tickets)
edges = Enum.flat_map(records, &Map.get(&1, "dependencies", []))

IO.puts(
  Jason.encode!(
    %{
      equal: true,
      counts: comparison,
      statuses: Enum.frequencies_by(records, & &1["status"]),
      dependencies: Enum.frequencies_by(edges, & &1["type"]),
      labels: Enum.sum(Enum.map(records, &length(Map.get(&1, "labels", [])))),
      ids: Enum.sort(Map.keys(tickets)),
      check: "valid"
    },
    pretty: true
  )
)
