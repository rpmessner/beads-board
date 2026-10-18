defmodule Foreman.Beads.ScheduleMachine do
  @moduledoc "Admission and draining for one physical store, not one config key."
  use Foreman.Fsm, observed_never_invalid: true

  initial(:idle)
  state(:idle)
  state(:active)
  state(:draining)
  state(:disabled)

  event(:request, source: :observed)
  event(:finished, source: :observed)
  event(:disable, source: :observed)
  event(:enable, source: :observed)
  effects([:enqueue, :cancel])
  guard(:due?)
  guard(:current?)

  transition(:request, from: :idle, to: :active, guard: :due?, do: [enqueue: :read])
  ignore(:request, from: :any)

  transition(:finished, from: :active, to: :idle, guard: :current?)
  transition(:finished, from: :draining, to: :disabled, guard: :current?)
  ignore(:finished, from: :any)

  transition(:disable, from: :idle, to: :disabled)
  transition(:disable, from: :active, to: :draining, do: [cancel: :read])
  ignore(:disable, from: :any)

  transition(:enable, from: :disabled, to: :idle)
  transition(:enable, from: :draining, to: :active)
  ignore(:enable, from: :any)

  def due?(%{next_at: next_at}, now) when is_integer(now), do: now >= next_at
  def due?(_, _), do: false

  def current?(%{epoch: epoch, generation: generation}, {epoch, generation}), do: true
  def current?(_, _), do: false
end
