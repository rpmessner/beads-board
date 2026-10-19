defmodule Foreman.SessionMachine do
  @moduledoc "Planning session launch and observed liveness. Window loss keeps the record; no effect kills a window."
  use Foreman.Fsm, observed_never_invalid: true
  initial(:new)
  state(:new)
  state(:starting)
  state(:running)
  state(:waiting)
  state(:ended)
  state(:parked)
  event(:launch)
  event(:started, source: :observed)
  event(:waiting, source: :observed)
  event(:resumed, source: :observed)
  event(:exited, source: :observed)
  event(:window_gone, source: :observed)
  effects([:open, :clear])
  guard(:resume_matches?)
  transition(:launch, from: :new, to: :starting, do: [open: :window])
  transition(:started, from: :starting, to: :running)
  transition(:waiting, from: [:starting, :running], to: :waiting)

  transition(:resumed,
    from: :waiting,
    to: :running,
    guard: :resume_matches?,
    do: [clear: :waiting]
  )

  transition(:exited, from: [:running, :waiting], to: :ended, do: [clear: :waiting])

  transition(:window_gone,
    from: [:starting, :running, :waiting, :ended],
    to: :parked,
    do: [clear: :waiting]
  )

  ignore([:started, :waiting, :resumed, :exited, :window_gone], from: :any)
  invalid(:launch, from: :any)

  def resume_matches?(context, _), do: Map.get(context, :resume_matches, true)
end
