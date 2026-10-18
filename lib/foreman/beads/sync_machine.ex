defmodule Foreman.Beads.SyncMachine do
  @moduledoc "Persisted read-health transitions; projection is retained on every failure."
  use Foreman.Fsm, observed_never_invalid: true
  initial(:waiting)
  state(:waiting)
  state(:synced)
  state(:deferred)
  state(:unreachable)
  state(:warning)
  event(:success, source: :observed)
  event(:defer, source: :observed)
  event(:failure, source: :observed)
  event(:partial, source: :observed)
  effects([:save])
  transition(:partial, from: :any, to: :warning, do: [save: :success])
  transition(:success, from: :any, to: :synced, do: [save: :success])
  transition(:defer, from: :any, to: :deferred, do: [save: :failure])
  transition(:failure, from: :any, to: :unreachable, do: [save: :failure])
end
