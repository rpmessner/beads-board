defmodule Foreman.RuntimeState do
  @moduledoc "Postgres snapshots shared by independently deployed web and worker roles."
  import Ecto.Query
  alias Foreman.Repo

  def config do
    Repo.one(
      from c in "board_config",
        where: c.id == 1,
        select: %{
          config: c.config,
          error: c.error,
          source: c.source,
          stores: c.stores,
          discovered: c.discovered,
          loaded_at: c.loaded_at
        }
    )
  end

  def repos do
    config = config()

    health =
      Repo.all(
        from s in "repo_sync",
          select: %{key: s.key, state: s.state, reason: s.reason, succeeded_at: s.succeeded_at}
      )
      |> Map.new(&{&1.key, health_display(&1)})

    counts =
      Repo.all(from b in "beads", group_by: b.repo_key, select: {b.repo_key, count(b.bead_id)})
      |> Map.new()

    for repo <- (config && config.config["repos"]) || [] do
      Map.merge(repo, %{
        "id" => repo["key"],
        "count" => Map.get(counts, repo["key"], 0),
        "store_mode" => get_in(config.stores, [repo["key"], "mode"]) || "unknown",
        "health" =>
          Map.get(health, repo["key"], %{state: "waiting", reason: nil, succeeded_at: nil})
      })
    end
  end

  def record(key, outcome) do
    {event, reason} = health_event(outcome)
    {state, effects} = Foreman.Beads.SyncMachine.step(:waiting, event, %{})
    previous = Repo.one(from s in "repo_sync", where: s.key == ^key, select: {s.state, s.reason})

    effects =
      if previous == {Atom.to_string(state), reason} and outcome != {:ok, :changed},
        do: [],
        else: effects

    Enum.each(effects, fn {:save, kind} ->
      now = DateTime.utc_now()
      row = %{key: key, state: Atom.to_string(state), reason: reason, checked_at: now}
      row = if kind == :success, do: Map.put(row, :succeeded_at, now), else: row

      Repo.insert_all("repo_sync", [row],
        on_conflict: {:replace, Map.keys(row) -- [:key]},
        conflict_target: [:key]
      )

      Foreman.Events.broadcast(:sync_status_changed, key)
    end)
  end

  defp health_display(%{state: "warning", reason: reason} = health) do
    errors = Jason.decode!(reason)
    Map.merge(health, %{reason: Enum.join(errors, "; "), file_error_count: length(errors)})
  end

  defp health_display(health), do: health

  defp health_event({:warning, errors}), do: {:partial, Jason.encode!(errors)}
  defp health_event({:ok, _}), do: {:success, nil}
  defp health_event({:defer, reason}), do: {:defer, to_string(reason)}
  defp health_event({:error, reason}) when is_binary(reason), do: {:failure, reason}
  defp health_event({:error, reason}) when is_atom(reason), do: {:failure, to_string(reason)}
  defp health_event(_), do: {:failure, "invalid export"}
end
