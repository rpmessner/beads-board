defmodule Foreman.TicketFiles.Reader do
  @moduledoc "Worker-owned, non-recursive inotify reader with 60-second reconciliation."
  use GenServer, restart: :temporary
  alias Foreman.TicketFiles
  alias Foreman.TicketFiles.ReaderMachine
  alias Foreman.Beads.Projection
  alias Foreman.Repo

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  def rescan(pid), do: send(pid, :rescan)

  @impl true
  def init(opts) do
    repo = Keyword.fetch!(opts, :repo)

    root =
      case TicketFiles.main_checkout(repo["path"]) do
        {:ok, root} -> root
        _ -> repo["path"]
      end

    directory = Path.join(root, "tickets")
    watched = existing_directory(directory)
    {:ok, watcher} = FileSystem.start_link(dirs: [watched], recursive: false)
    FileSystem.subscribe(watcher)
    send(self(), :rescan)
    Process.send_after(self(), :periodic, 60_000)

    {:ok,
     %{
       machine: ReaderMachine.__fsm__(:initial),
       repo: repo,
       root: root,
       watched: watched,
       identity: identity(watched),
       watcher: watcher,
       candidate: nil,
       observer: opts[:observer]
     }}
  end

  @impl true
  def handle_info({:file_event, watcher, :stop}, %{watcher: watcher} = state),
    do: advance(state, :lost)

  def handle_info({:file_event, watcher, {_path, _events}}, %{watcher: watcher} = state),
    do: advance(state, :changed)

  def handle_info(:rescan, state), do: advance(state, :changed)

  def handle_info(:periodic, state) do
    Process.send_after(self(), :periodic, 60_000)
    advance(state, :changed)
  end

  def handle_info(:sample, state) do
    target = Path.join(state.root, "tickets")
    desired = existing_directory(target)

    if desired != state.watched or identity(desired) != state.identity do
      advance(state, :lost)
    else
      snapshot = TicketFiles.snapshot(state.root)
      event = if snapshot == state.candidate, do: :stable, else: :unstable
      advance(%{state | candidate: snapshot}, event)
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp existing_directory(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} -> path
      _ -> existing_directory(Path.dirname(path))
    end
  end

  defp identity(path) do
    case File.stat(path) do
      {:ok, stat} -> {stat.major_device, stat.inode}
      _ -> nil
    end
  end

  defp advance(state, event) do
    {machine, effects} = ReaderMachine.step(state.machine, event, %{})

    Enum.reduce(effects, {:noreply, %{state | machine: machine}}, fn
      {:timer, kind}, {:noreply, state} ->
        Process.send_after(self(), :sample, if(kind == :retry, do: 500, else: 100))
        {:noreply, state}

      {:publish, :snapshot}, {:noreply, state} ->
        result = publish(state.repo, state.candidate)
        if state.observer, do: send(state.observer, {:ticket_files, result})
        state = %{state | candidate: nil}

        case result do
          {:ok, {:defer, _}} ->
            advance(state, :retry)

          _ ->
            {:noreply, state}
        end

      {:stop, :restart}, {:noreply, state} ->
        {:stop, :shutdown, state}
    end)
  end

  def publish(repo, snapshot) do
    Repo.transaction(fn ->
      # Config locking prevents a retiring reader from overwriting the new source.
      %{rows: rows} = Repo.query!("SELECT config FROM board_config WHERE id = 1 FOR SHARE")

      active =
        Enum.any?(rows, fn [config] ->
          Enum.any?(
            config["repos"],
            &(&1["key"] == repo["key"] and &1["path"] == repo["path"] and &1["enabled"] and
                &1["tickets"] == "files")
          )
        end)

      if active do
        Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
          "foreman:projection:" <> repo["key"]
        ])

        current =
          with {:ok, root} <- TicketFiles.main_checkout(repo["path"]),
               do: TicketFiles.snapshot(root)

        outcome =
          case snapshot do
            {:ok, _} when snapshot != current ->
              {:defer, :changed}

            {:ok, snapshot} ->
              {raw, errors} = TicketFiles.decode(snapshot, Projection.list_raw(repo["key"]))
              result = Projection.replace(repo["key"], Enum.map_join(raw, "\n", &Jason.encode!/1))

              case {result, errors} do
                {{:ok, _}, [_ | _]} -> {:warning, errors}
                _ -> result
              end

            {:error, "tickets: write in progress or recovery required"} ->
              {:defer, :writing}

            {:error, error} ->
              {:error, error}
          end

        Foreman.RuntimeState.record(repo["key"], outcome)
        outcome
      else
        {:error, :config_changed}
      end
    end)
  end
end
