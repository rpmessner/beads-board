defmodule Foreman.Forge.SyncJob do
  @moduledoc "Worker-only, serialized reads. Revalidates config before publishing late responses."
  use Oban.Worker,
    queue: :external_reads,
    max_attempts: 1,
    unique: [period: :infinity, fields: [:worker, :args], keys: [:key], states: :incomplete]

  alias Foreman.Forge.Store
  alias Foreman.Forge.ReadLifecycle, as: ReadMachine
  alias Foreman.Repo

  def enqueue(key, manual \\ false), do: new(%{key: key, manual: manual}) |> Oban.insert()
  @impl true
  def perform(%Oban.Job{args: %{"key" => key} = args}) do
    sync(
      key,
      Foreman.Forge.adapter(),
      Keyword.put(Foreman.Forge.options(), :manual, args["manual"] == true)
    )

    :ok
  end

  def sync(key, adapter, opts) do
    Repo.transaction(
      fn ->
        %{rows: [[admitted]]} =
          Repo.query!("SELECT pg_try_advisory_xact_lock(hashtextextended($1, 0))", [
            "foreman:forge:" <> key
          ])

        repo = configured(key)

        if admitted && repo do
          old = Store.get(key)

          tracked =
            if old && old.remote == repo["github"],
              do:
                Enum.filter(old.snapshot["change_requests"] || [], &(&1["state"] == "open"))
                |> Enum.map(& &1["number"]),
              else: []

          current = if old && old.remote == repo["github"], do: old
          {_, effects} = admission(current, Keyword.get(opts, :manual, false))

          if effects == [fetch: :snapshot] do
            result = adapter.list(repo["github"], Keyword.put(opts, :tracked, tracked))
            # Shared config lock ensures removal/repointing cannot race this publication.
            Repo.query!("SELECT id FROM board_config WHERE id = 1 FOR SHARE")

            if configured(key) == repo do
              case result do
                {:ok, snapshot} ->
                  {:fresh, [publish: :snapshot]} = ReadMachine.step(:reading, :succeeded, %{})
                  Store.replace(key, repo["github"], snapshot)

                {:error, reason} ->
                  {:failed, [retain: :snapshot]} = ReadMachine.step(:reading, :failed, %{})
                  Store.failed(key, repo["github"], reason)
              end
            end
          end
        end

        :ok
      end,
      timeout: 25_000
    )
  end

  def configured(key) do
    case Foreman.RuntimeState.config() do
      nil ->
        nil

      row ->
        Enum.find(
          row.config["repos"],
          &(&1["key"] == key && &1["enabled"] && &1["forge"] == "github" &&
              is_binary(&1["github"]))
        )
    end
  end

  def due?(row, manual \\ false), do: elem(admission(row, manual), 1) == [fetch: :snapshot]

  defp admission(row, manual) do
    state =
      cond do
        is_nil(row) -> :idle
        row.state == "failed" -> :failed
        true -> :fresh
      end

    elapsed =
      if row && row.attempted_at,
        do: NaiveDateTime.diff(NaiveDateTime.utc_now(), row.attempted_at),
        else: 120

    ReadMachine.step(state, :start, %{
      elapsed: elapsed,
      manual: manual,
      rate_limited: row != nil && row.error == "rate_limited"
    })
  end
end
