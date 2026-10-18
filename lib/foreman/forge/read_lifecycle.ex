defmodule Foreman.Forge.ReadLifecycle do
  @moduledoc "Per-repository read lifecycle. Oban owns execution; only complete reads publish."
  use Foreman.Fsm
  initial(:idle)
  state(:idle)
  state(:reading)
  state(:fresh)
  state(:failed)
  event(:start)
  event(:succeeded)
  event(:failed)
  effects([:fetch, :publish, :retain])
  guard(:due?)

  transition(:start,
    from: [:idle, :fresh, :failed],
    to: :reading,
    guard: :due?,
    do: [fetch: :snapshot]
  )

  transition(:succeeded, from: :reading, to: :fresh, do: [publish: :snapshot])
  transition(:failed, from: :reading, to: :failed, do: [retain: :snapshot])
  ignore([:start, :succeeded, :failed], from: :any)

  def due?(%{elapsed: elapsed, manual: manual, rate_limited: limited}, _) do
    elapsed >= 120 or (manual and not limited and elapsed >= 10)
  end
end
