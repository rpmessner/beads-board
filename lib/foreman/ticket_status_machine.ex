defmodule Foreman.TicketStatusMachine do
  @moduledoc "File ticket lifecycle, independent of the board's overlay stage machine."
  use Foreman.Fsm
  initial(:open)
  state(:open)
  state(:in_progress)
  state(:closed)
  state(:deferred)
  event(:reopen)
  event(:start)
  event(:close)
  event(:defer)
  transition(:reopen, from: :any, to: :open)
  transition(:start, from: :any, to: :in_progress)
  transition(:close, from: :any, to: :closed)
  transition(:defer, from: :any, to: :deferred)
end
