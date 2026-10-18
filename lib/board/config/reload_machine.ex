defmodule Board.Config.ReloadMachine do
  @moduledoc "Single-flight reload: rejected results retain the last good configuration."
  use Board.Fsm, observed_never_invalid: true

  initial(:valid)
  state(:valid)
  state(:loading)
  state(:invalid)

  event(:reload, source: :observed)
  event(:accepted, source: :observed)
  event(:rejected, source: :observed)
  effects([:read, :install, :reject, :broadcast])
  guard(:current_generation?)

  transition(:reload, from: [:valid, :invalid], to: :loading, do: [read: :config])
  ignore(:reload, from: :loading)

  transition(:accepted,
    from: :loading,
    to: :valid,
    guard: :current_generation?,
    do: [install: :config, broadcast: :config]
  )

  transition(:rejected,
    from: :loading,
    to: :invalid,
    guard: :current_generation?,
    do: [reject: :config, broadcast: :config]
  )

  ignore([:accepted, :rejected], from: :any)

  def current_generation?(%{generation: generation}, {generation, _}), do: true
  def current_generation?(_, _), do: false
end
