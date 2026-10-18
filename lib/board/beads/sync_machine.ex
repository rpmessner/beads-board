defmodule Board.Beads.SyncMachine do
  @moduledoc "Persisted read-health transitions; projection is retained on every failure."
  use Board.Fsm, observed_never_invalid: true
  initial(:waiting)
  state(:waiting)
  state(:synced)
  state(:deferred)
  state(:unreachable)
  event(:success, source: :observed)
  event(:defer, source: :observed)
  event(:failure, source: :observed)
  effects([:save])
  transition(:success, from: :any, to: :synced, do: [save: :success])
  transition(:defer, from: :any, to: :deferred, do: [save: :failure])
  transition(:failure, from: :any, to: :unreachable, do: [save: :failure])
end
