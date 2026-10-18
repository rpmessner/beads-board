defmodule Foreman.FsmProbe do
  use Foreman.Fsm
  initial(:off)
  state(:off, exit: [emit: :exit])
  state(:on, enter: [emit: :enter])
  state(:closed)
  group(:live, [:off, :on])
  event(:start)
  event(:stop)
  event(:quit)
  event(:pulse)
  effects([:emit])
  guard(:ready?)
  guard(:also_ready?)

  transition(:start, from: :off, to: :on, guard: :ready?, do: [emit: :first])
  transition(:start, from: :off, to: :on, guard: :also_ready?, do: [emit: :second])
  invalid(:start, from: :off)
  transition(:pulse, from: :live, to: :stay, do: [emit: :pulse])
  transition(:stop, from: :on, to: :on, do: [emit: :self])
  transition(:quit, from: :any, to: :closed)
  ignore(:any, from: :closed)
  ignore(:any, from: :any)

  def ready?(data, payload), do: data == :ready and payload == :yes
  def also_ready?(data, _payload), do: data in [:ready, :second]
end
