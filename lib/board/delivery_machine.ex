defmodule Board.DeliveryMachine do
  @moduledoc "One CLI delivery attempt: HTTP, optional durable fallback, then a terminal exit."
  use Board.Fsm
  initial(:sending)
  state(:sending)
  state(:spooling)
  state(:finished)
  event(:accepted, source: :claimed)
  event(:conflict, source: :claimed)
  event(:refused, source: :claimed)
  event(:unavailable, source: :claimed)
  event(:saved, source: :claimed)
  event(:failed, source: :claimed)
  effects([:reply, :persist])
  transition(:accepted, from: :sending, to: :finished, do: [reply: :ok])
  transition(:conflict, from: :sending, to: :finished, do: [reply: :conflict])
  transition(:refused, from: :sending, to: :finished, do: [reply: :warning])
  transition(:unavailable, from: :sending, to: :spooling, do: [persist: :request])
  transition(:saved, from: :spooling, to: :finished, do: [reply: :spooled])
  transition(:failed, from: :spooling, to: :finished, do: [reply: :lost])
  invalid([:accepted, :conflict, :refused, :unavailable, :saved, :failed], from: :any)
end
