defmodule Foreman.Config.WatchMachine do
  @moduledoc "Directory watcher lifecycle, including absent directories and editor renames."
  use Foreman.Fsm, observed_never_invalid: true
  initial(:watching)
  state(:watching)
  state(:stopped)
  event(:lost, source: :observed)
  event(:changed, source: :observed)
  event(:reconcile, source: :observed)
  guard(:directory_moved?)
  effects([:watch, :reload, :stop])

  transition([:changed, :reconcile],
    from: :watching,
    to: :stay,
    guard: :directory_moved?,
    do: [watch: :replace, reload: :config]
  )

  transition([:changed, :reconcile], from: :watching, to: :stay, do: [reload: :config])
  transition(:lost, from: :watching, to: :stopped, do: [stop: :restart])
  ignore(:any, from: :stopped)

  def directory_moved?(%{directory: current, desired: desired}, _), do: current != desired
  def directory_moved?(_, _), do: false
end
