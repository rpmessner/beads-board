# Run with FOREMAN_ROLE=web mix run tools/verify-initiatives.exs after the guarded
# sync has loaded the intended read-only repositories. No bd write is performed.
Logger.configure(level: :warning)
alias Foreman.Beads.{Command, JournalLock, Store}

snapshot = Foreman.Initiatives.snapshot()
checks = [{"form-engine", "fe-813"}, {"form-engine", "fe-lwp"}, {"foreman", "bb-c2w"}]

exports =
  for repo_key <- Enum.uniq(Enum.map(checks, &elem(&1, 0))), into: %{} do
    repo = Enum.find(snapshot.repos, &(&1["key"] == repo_key))
    {:ok, path, identity} = Store.resolve(repo["path"])
    :clear = JournalLock.check(path)

    {:ok, output} =
      Command.run(path, [System.find_executable("bd"), "export"],
        identity: identity,
        timeout: 20_000
      )

    rows = output |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)
    {repo_key, rows}
  end

# Independent reference traversal uses the bd response, not the projection or
# Tree module. A frontier walks reverse dependencies, retaining each ID once.
walk = fn walk, frontier, seen, rows ->
  found =
    Enum.filter(rows, fn row ->
      row["id"] not in seen and
        Enum.any?(row["dependencies"] || [], fn edge ->
          edge["type"] in ["parent-child", "discovered-from"] and
            edge["depends_on_id"] in frontier
        end)
    end)
    |> Enum.map(& &1["id"])

  if found == [], do: seen, else: walk.(walk, found, seen ++ found, rows)
end

results =
  for {repo, id} <- checks do
    rows = exports[repo]
    member_ids = walk.(walk, [id], [id], rows)
    members = Enum.filter(rows, &(&1["id"] in member_ids and &1["issue_type"] != "epic"))
    closed = Enum.count(members, &(&1["status"] == "closed"))
    total = length(members)

    fallout_seeds =
      Enum.filter(rows, fn row ->
        Enum.any?(
          row["dependencies"] || [],
          &(&1["type"] == "discovered-from" and &1["depends_on_id"] in member_ids)
        )
      end)
      |> Enum.map(& &1["id"])

    fallout_ids = walk.(walk, fallout_seeds, fallout_seeds, rows)

    fallout =
      Enum.filter(members, &(&1["id"] in fallout_ids)) |> Enum.map(& &1["id"]) |> Enum.sort()

    epic = Enum.find(snapshot.epics, &(&1.repo == repo and &1.id == id))

    expected_stage =
      cond do
        Enum.find(rows, &(&1["id"] == id))["status"] == "closed" -> :done
        total == 0 -> :ticketed
        total == closed -> :shipped
        closed > 0 -> :building
        true -> :ticketed
      end

    if {epic.closed, epic.total, epic.stage} != {closed, total, expected_stage},
      do: raise("Progress/stage mismatch for #{id}")

    if Enum.sort(Enum.map(epic.fallout, & &1.id)) != fallout,
      do: raise("Fallout mismatch for #{id}")

    %{repo: repo, id: id, closed: closed, total: total, stage: epic.stage, fallout: fallout}
  end

orphan = Enum.find(snapshot.orphans, &(&1.repo == "skills")) || raise("No real orphan")

true =
  orphan.edges == [] or
    Enum.all?(orphan.edges, &(&1.type not in ["parent-child", "discovered-from"]))

IO.puts(
  Jason.encode!(%{checks: results, orphan: %{repo: orphan.repo, id: orphan.id}, result: "PASS"},
    pretty: true
  )
)
