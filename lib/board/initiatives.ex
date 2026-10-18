defmodule Board.Initiatives do
  @moduledoc "Snapshot query for the initiatives home. Filters never alter rolled-up totals."
  import Ecto.Query
  alias Board.{Repo, RuntimeState}
  alias Board.Initiatives.Tree

  def snapshot(filters \\ %{}) do
    config =
      case RuntimeState.config() do
        nil -> %{"repos" => [], "columns" => [], "board" => %{}}
        row -> row.config
      end

    views = Board.Config.views(config)
    filters = Board.Initiatives.Filters.effective(filters, views)
    repos = RuntimeState.repos()
    keys = Enum.map(repos, & &1["key"])

    tickets =
      Repo.all(from t in "tickets", select: %{key: {t.repo_key, t.bead_id}, stage: t.stage})
      |> Map.new(&{&1.key, &1.stage})

    epics =
      Repo.all(
        from e in "epics",
          select: %{
            repo_key: e.repo_key,
            bead_id: e.bead_id,
            beads_epic_id: e.beads_epic_id,
            stage: e.stage,
            title: e.title,
            spec_link: e.spec_link
          }
      )

    epic_map = Map.new(epics, &{{&1.repo_key, &1.beads_epic_id || &1.bead_id}, &1})

    sessions =
      Repo.all(
        from s in "sessions",
          where: is_nil(s.ended_at),
          order_by: s.id,
          select: %{key: {s.repo_key, s.bead_id}, last_seen_at: s.last_seen_at}
      )
      |> Map.new(&{&1.key, &1.last_seen_at})

    threshold = stale_seconds(config["board"]["stale_session_after"] || "2h")

    beads =
      Repo.all(
        from b in "beads", where: b.repo_key in ^keys, select: %{repo: b.repo_key, raw: b.raw}
      )
      |> Enum.map(fn %{repo: repo, raw: raw} ->
        key = {repo, raw["id"]}
        epic = epic_map[key]

        stage =
          if epic,
            do: stage_atom(epic.stage),
            else:
              stage_atom(
                tickets[key] || if(raw["status"] == "closed", do: "done", else: "queued")
              )

        %{
          key: key,
          repo: repo,
          id: raw["id"],
          title: raw["title"],
          type: raw["issue_type"],
          status: raw["status"],
          labels: raw["labels"] || [],
          stage: stage,
          spec_link: epic && epic.spec_link,
          stale: stale?(raw, stage, sessions[key], threshold),
          edges:
            Enum.map(
              raw["dependencies"] || [],
              &%{target: {repo, &1["depends_on_id"]}, type: &1["type"]}
            )
        }
      end)

    links =
      Repo.all(
        from l in "epic_links",
          select: %{ticket: {l.repo_key, l.bead_id}, epic: {l.epic_repo_key, l.epic_bead_id}}
      )

    tree = Tree.build(beads, links)

    drafts =
      epics
      |> Enum.filter(&(is_nil(&1.beads_epic_id) and &1.repo_key in keys))
      |> Enum.map(fn e ->
        %{
          key: {e.repo_key, e.bead_id},
          repo: e.repo_key,
          id: e.bead_id,
          title: e.title,
          type: "epic",
          status: if(e.stage == "done", do: "closed", else: "open"),
          stage: stage_atom(e.stage),
          labels: [],
          stale: false,
          spec_link: e.spec_link
        }
      end)
      |> Enum.filter(&matches?(&1, filters))
      |> Enum.sort_by(&Board.Beads.Id.sort_key(&1.key))

    %{
      drafts: drafts,
      epics: Enum.filter(tree.epics, &epic_matches?(&1, filters)),
      orphans: Enum.filter(tree.orphans, &matches?(&1, filters)),
      repos: repos,
      columns: config["columns"],
      views: views,
      filters: filters,
      types: beads |> Enum.map(& &1.type) |> Enum.uniq() |> Enum.sort(),
      labels: beads |> Enum.flat_map(& &1.labels) |> Enum.uniq() |> Enum.sort()
    }
  end

  def matches?(b, filters) do
    Enum.all?(filters, fn
      {"project", value} ->
        value in ["", "all"] or b.repo == value

      {"type", value} ->
        value in ["", "all"] or b.type == value

      {"label", value} ->
        value == "" or value in b.labels

      {"status", value} ->
        value in ["", "all"] or (value == "open" and b.status != "closed") or b.status == value

      {"statuses", values} ->
        values == [] or b.status in values

      {"stages", values} ->
        values == [] or (b.type != "epic" and to_string(b.stage) in values)

      {"stale", value} ->
        value != "true" or b.stale

      {"q", value} ->
        String.contains?(
          String.downcase(b.id <> " " <> (b.title || "") <> " " <> Enum.join(b.labels, " ")),
          String.downcase(value)
        )

      _ ->
        true
    end)
  end

  defp epic_matches?(epic, filters),
    do:
      matches?(%{epic | stale: Enum.any?(epic.planned ++ epic.fallout, & &1.stale)}, filters) or
        Enum.any?(epic.planned ++ epic.fallout, &matches?(&1, filters)) or
        Enum.any?(epic.children, &epic_matches?(&1, filters))

  defp stage_atom(value),
    do:
      Enum.find(
        Board.Stage.__fsm__(:states) ++ Board.Epic.__fsm__(:states),
        &(to_string(&1) == value)
      )

  defp stale_seconds(value) do
    case Regex.run(~r/^(\d+)(s|m|h|d)$/, value) do
      [_, n, unit] ->
        String.to_integer(n) * %{"s" => 1, "m" => 60, "h" => 3600, "d" => 86400}[unit]

      _ ->
        7200
    end
  end

  defp stale?(raw, stage, last, threshold) do
    active = stage in [:dispatched, :building] or raw["status"] == "in_progress"
    active and (is_nil(last) or NaiveDateTime.diff(NaiveDateTime.utc_now(), last) > threshold)
  end
end
