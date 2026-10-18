defmodule Foreman.Initiatives.Disclosure do
  @moduledoc "Expandable epic and Unplanned rows. Each row owns an instance."
  use Foreman.Fsm
  initial(:collapsed)
  state(:collapsed)
  state(:expanded)
  event(:toggle)
  transition(:toggle, from: :collapsed, to: :expanded)
  transition(:toggle, from: :expanded, to: :collapsed)
end
