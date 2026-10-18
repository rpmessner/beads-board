defmodule Foreman.Beads.ReadMachine do
  @moduledoc "Read protocol: observe the lock before opening a store."
  use Foreman.Fsm, observed_never_invalid: true

  initial(:ready)
  state(:ready)
  state(:checking)
  state(:exporting)
  state(:cancelling)
  state(:projecting)
  state(:finished)
  event(:start, source: :observed)
  event(:deferred, source: :observed)
  event(:clear, source: :observed)
  event(:exported, source: :observed)
  event(:projected, source: :observed)
  event(:cancel, source: :observed)
  event(:failed, source: :observed)
  effects([:check_lock, :export, :project, :finish, :cancel_export])
  guard(:current?)
  transition(:start, from: :ready, to: :checking, do: [check_lock: :repo])
  ignore(:start, from: :any)
  transition(:deferred, from: :checking, to: :finished, guard: :current?, do: [finish: :result])
  ignore(:deferred, from: :any)
  transition(:clear, from: :checking, to: :exporting, guard: :current?, do: [export: :repo])

  transition(:exported,
    from: :exporting,
    to: :projecting,
    guard: :current?,
    do: [project: :output]
  )

  transition(:projected,
    from: :projecting,
    to: :finished,
    guard: :current?,
    do: [finish: :result]
  )

  transition(:cancel,
    from: :exporting,
    to: :cancelling,
    guard: :current?,
    do: [cancel_export: :owned]
  )

  transition(:cancel,
    from: [:ready, :checking],
    to: :finished,
    guard: :current?,
    do: [finish: :result]
  )

  transition([:exported, :failed],
    from: :cancelling,
    to: :finished,
    guard: :current?,
    do: [finish: :cancelled]
  )

  transition(:failed, from: :exporting, to: :finished, guard: :current?, do: [finish: :result])
  ignore([:clear, :exported, :projected, :cancel, :failed], from: :any)

  def current?(%{token: token}, {token, _}), do: true
  def current?(_, _), do: false
end
