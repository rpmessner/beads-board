defmodule Foreman.Documents.Viewer do
  @moduledoc "URL-driven document selection; loading is synchronous and read-only."
  use Foreman.Fsm
  initial(:empty)
  state(:empty)
  state(:ready)
  state(:unavailable)
  event(:loaded)
  event(:missing)
  event(:empty)
  transition(:loaded, from: :any, to: :ready)
  transition(:missing, from: :any, to: :unavailable)
  transition(:empty, from: :any, to: :empty)
end
