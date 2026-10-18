defmodule Foreman.RequestDrawer do
  @moduledoc "Notification drawer visibility; Fluxon owns focus and dialog animation."
  use Foreman.Fsm
  initial(:closed)
  state(:closed)
  state(:open)
  event(:open)
  event(:close)
  transition(:open, from: :any, to: :open)
  transition(:close, from: :any, to: :closed)
end
