defmodule Foreman.CardPanel do
  @moduledoc """
  The Needs you ticket side panel, driven by `?ticket=repo:id`.
  Documents live in the independent `Foreman.DocumentPanel` layer.
  """
  use Foreman.Fsm
  initial(:closed)
  state(:closed)
  state(:ticket)
  event(:close)
  event(:ticket)
  transition(:close, from: :any, to: :closed)
  transition(:ticket, from: :any, to: :ticket)
end
