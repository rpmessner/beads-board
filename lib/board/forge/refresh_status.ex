defmodule Board.Forge.RefreshStatus do
  @moduledoc "Manual refresh feedback. Snapshot reconciliation supplies completion facts."
  use Board.Fsm
  initial(:idle)
  state(:idle)
  state(:refreshing)
  event(:request)
  event(:complete)
  event(:cancel)
  effects([:status])
  transition(:request, from: :any, to: :refreshing, do: [status: :refreshing])
  transition(:complete, from: :refreshing, to: :idle, do: [status: :result])
  transition(:cancel, from: :any, to: :idle)
  ignore(:complete, from: :idle)
end
