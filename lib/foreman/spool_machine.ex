defmodule Foreman.SpoolMachine do
  @moduledoc "Delivery lifecycle; application and terminal receipt share one DB transaction."
  use Foreman.Fsm
  initial(:pending)
  state(:pending)
  state(:applied)
  state(:rejected)
  event(:accept, source: :claimed)
  event(:reject, source: :claimed)
  event(:retry, source: :claimed)
  effects([:save])
  transition(:accept, from: :pending, to: :applied, do: [save: :receipt])
  transition(:reject, from: :pending, to: :rejected, do: [save: :receipt])
  ignore(:retry, from: :pending)
  ignore([:accept, :reject, :retry], from: [:applied, :rejected])
end
