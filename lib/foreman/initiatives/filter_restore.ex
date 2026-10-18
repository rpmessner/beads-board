defmodule Foreman.Initiatives.FilterRestore do
  @moduledoc "Browser memory may seed the first bare route only; subsequent URLs are authoritative."
  use Foreman.Fsm

  initial(:initial)
  state(:initial)
  state(:url)
  event(:params)
  guard(:restore?)
  effects([:restore])

  transition(:params, from: :initial, to: :url, guard: :restore?, do: [restore: nil])
  transition(:params, from: :initial, to: :url)
  transition(:params, from: :url, to: :url)

  def restore?(remembered, params),
    do: params == %{} and is_map(remembered) and map_size(remembered) > 0
end
