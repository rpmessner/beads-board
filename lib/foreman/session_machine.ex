defmodule Foreman.SessionMachine do
  @moduledoc "Planning session launch and observed liveness. Window loss keeps the record; no effect kills a window."
  use Foreman.Fsm, observed_never_invalid: true
  initial(:new)
  state(:new)
  state(:starting)
  state(:running)
  state(:ended)
  state(:parked)
  event(:launch)
  event(:started, source: :observed)
  event(:exited, source: :observed)
  event(:window_gone, source: :observed)
  effects([:open])
  transition(:launch, from: :new, to: :starting, do: [open: :window])
  transition(:started, from: :starting, to: :running)
  transition(:exited, from: :running, to: :ended)
  transition(:window_gone, from: [:starting, :running, :ended], to: :parked)
  ignore([:started, :exited, :window_gone], from: :any)
  invalid(:launch, from: :any)
end
