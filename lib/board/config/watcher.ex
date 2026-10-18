defmodule Board.Config.Watcher do
  @moduledoc "Non-recursive directory hints, with periodic recovery and supervised watcher replacement."
  use GenServer
  alias Board.Config.{ReloadJob, WatchMachine}
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_) do
    target = Application.fetch_env!(:board, :config_directory)
    directory = existing_parent(target)
    watcher = watch(directory)
    Process.send_after(self(), :reconcile, 30_000)

    {:ok,
     %{
       machine: WatchMachine.__fsm__(:initial),
       target: target,
       directory: directory,
       watcher: watcher
     }}
  end

  @impl true
  def handle_info({:file_event, watcher, {_path, _events}}, %{watcher: watcher} = state),
    do: advance(state, :changed)

  def handle_info({:file_event, watcher, :stop}, %{watcher: watcher} = state),
    do: advance(state, :lost)

  def handle_info({:file_event, _, _}, state), do: {:noreply, state}

  def handle_info(:reconcile, state) do
    Process.send_after(self(), :reconcile, 30_000)
    advance(state, :reconcile)
  end

  defp advance(state, event) do
    desired = existing_parent(state.target)

    {machine, effects} =
      WatchMachine.step(state.machine, event, Map.put(state, :desired, desired))

    Enum.reduce(effects, {:noreply, %{state | machine: machine}}, fn
      {:watch, :replace}, {:noreply, state} ->
        GenServer.stop(state.watcher, :normal)
        {:noreply, %{state | watcher: watch(desired), directory: desired}}

      {:reload, :config}, result ->
        ReloadJob.enqueue()
        result

      {:stop, :restart}, {:noreply, state} ->
        {:stop, :watcher_stopped, state}
    end)
  end

  defp watch(directory) do
    {:ok, watcher} = FileSystem.start_link(dirs: [directory], recursive: false)
    FileSystem.subscribe(watcher)
    watcher
  end

  defp existing_parent(path) do
    if File.dir?(path), do: path, else: existing_parent(Path.dirname(path))
  end
end
