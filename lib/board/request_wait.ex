defmodule Board.RequestWait do
  @moduledoc "CLI polling lifecycle. Deadlines return the last authoritative snapshot."
  use Board.Fsm
  initial(:waiting)
  state(:waiting)
  state(:finished)
  event(:response)
  event(:timeout)
  effects([:reply, :poll])
  guard(:resolved?)
  transition(:response, from: :waiting, to: :finished, guard: :resolved?, do: [reply: :result])
  transition(:response, from: :waiting, to: :stay, do: [poll: :again])
  transition(:timeout, from: :waiting, to: :finished, do: [reply: :current])
  invalid([:response, :timeout], from: :any)
  def resolved?(_, body), do: body["state"] not in ["pending", "approved", "executing"]
end
