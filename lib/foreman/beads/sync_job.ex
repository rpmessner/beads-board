defmodule Foreman.Beads.SyncJob do
  @moduledoc "Executes Read effects under physical-store admission. All failures are board-local."
  use Oban.Worker,
    queue: :external_reads,
    max_attempts: 1,
    unique: [period: :infinity, fields: [:worker, :args], keys: [:store], states: :incomplete]

  alias Foreman.Beads.{Command, JournalLock, Projection, Read, Store}
  alias Foreman.Repo
  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"key" => key}}) do
    snapshot = Foreman.RuntimeState.config()
    repo = snapshot && Enum.find(snapshot.config["repos"], &(&1["key"] == key and &1["enabled"]))

    if repo && repo["tickets"] != "files" do
      identity = get_in(snapshot.stores, [key, "identity"])

      aliases =
        Enum.filter(snapshot.config["repos"], fn candidate ->
          candidate["enabled"] and candidate["tickets"] != "files" and
            (candidate["key"] == key or
               (identity && get_in(snapshot.stores, [candidate["key"], "identity"]) == identity))
        end)

      outcome = sync(repo, aliases)

      unless outcome == {:error, :config_changed} do
        Repo.transaction(fn ->
          Enum.each(active_aliases(aliases), &Foreman.RuntimeState.record(&1["key"], outcome))
        end)
      end

      Logger.info("beads sync #{key}: #{inspect(outcome)}")
    end

    :ok
  end

  def sync(repo, aliases \\ nil) do
    aliases = aliases || [repo]

    with {:ok, path, identity} <- Store.resolve(repo["path"]) do
      aliases =
        Enum.filter(aliases, fn candidate ->
          case Store.resolve(candidate["path"]) do
            {:ok, _, ^identity} -> true
            _ -> false
          end
        end)

      Repo.transaction(
        fn ->
          %{rows: [[admitted]]} =
            Repo.query!("SELECT pg_try_advisory_xact_lock(hashtextextended($1, 0))", [
              "foreman:read:" <> identity
            ])

          if admitted do
            token = make_ref()

            Read.new(path, token)
            |> Read.start()
            |> execute(aliases, identity)
          else
            {:defer, :busy}
          end
        end,
        timeout: 30_000
      )
      |> case do
        {:ok, outcome} -> outcome
        {:error, _} -> {:error, :database}
      end
    end
  end

  defp execute({read, effects}, context, identity) do
    Enum.reduce(effects, read.outcome, fn
      {:check_lock, {token, path}}, _ ->
        execute(Read.lock_checked(read, token, JournalLock.check(path)), context, identity)

      {:export, {token, path, timeout}}, _ ->
        result =
          Command.run(path, [System.find_executable("bd") || "bd", "export"],
            timeout: timeout,
            identity: identity
          )

        case result do
          {:error, :timeout} ->
            {cancelled, _} = Read.cancel(read, token, :timeout)
            execute(Read.reaped(cancelled, token, result), context, identity)

          {:error, :busy} ->
            execute(Read.reaped(read, token, {:error, :busy}), context, identity)

          _ ->
            execute(Read.reaped(read, token, result), context, identity)
        end

      {:project, {token, output}}, _ ->
        execute(Read.projected(read, token, project_current(context, output)), context, identity)

      {:finished, {_token, outcome}}, _ ->
        outcome
    end)
  end

  defp project_current(aliases, output) do
    results = Enum.map(active_aliases(aliases), &Projection.replace(&1["key"], output))

    cond do
      results == [] -> {:error, :config_changed}
      error = Enum.find(results, &match?({:error, _}, &1)) -> error
      {:ok, :changed} in results -> {:ok, :changed}
      true -> {:ok, :unchanged}
    end
  end

  defp active_aliases(aliases) do
    %{rows: rows} = Repo.query!("SELECT config FROM board_config WHERE id = 1 FOR SHARE")
    active = Enum.flat_map(rows, fn [config] -> config["repos"] end)

    Enum.filter(aliases, fn repo ->
      Enum.any?(
        active,
        &(&1["key"] == repo["key"] and &1["path"] == repo["path"] and &1["enabled"] and
            &1["tickets"] != "files")
      )
    end)
  end
end
