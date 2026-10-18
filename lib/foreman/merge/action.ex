defmodule Foreman.Merge.Action do
  @moduledoc "Confirmation and durable merge lifecycle. Effects are interpreted by the UI and jobs."
  use Foreman.Fsm
  initial(:idle)
  state(:idle)
  state(:confirming)
  state(:merging)
  state(:retargeting)
  state(:merged)
  state(:failed)
  event(:request)
  event(:cancel)
  event(:confirm)
  event(:merge_ok)
  event(:merge_failed)
  event(:retarget_ok)
  event(:retarget_failed)
  event(:job_timeout)
  effects([:enqueue, :verify, :status])
  guard(:mergeable_now?)
  guard(:native_guard?)
  guard(:head_unchanged?)
  guard(:retarget_child?)
  guard(:has_child?)

  transition(:request, from: [:idle, :failed, :merged], to: :confirming, guard: :mergeable_now?)
  transition(:request, from: [:idle, :failed, :merged], to: :stay, do: [status: :refused])
  transition(:cancel, from: :confirming, to: :idle)

  transition(:confirm,
    from: :confirming,
    to: :merging,
    guard: :native_guard?,
    do: [enqueue: :merge]
  )

  transition(:confirm,
    from: :confirming,
    to: :merging,
    guard: :head_unchanged?,
    do: [verify: :head, enqueue: :merge]
  )

  transition(:confirm, from: :confirming, to: :stay, do: [status: :head_moved])

  transition(:merge_ok,
    from: :merging,
    to: :retargeting,
    guard: :retarget_child?,
    do: [enqueue: :retarget]
  )

  transition(:merge_ok,
    from: :merging,
    to: :merged,
    guard: :has_child?,
    do: [status: :manual_retarget]
  )

  transition(:merge_ok, from: :merging, to: :merged)
  transition(:retarget_ok, from: :retargeting, to: :merged)
  transition([:merge_failed, :job_timeout], from: :merging, to: :failed, do: [status: :failed])

  transition([:retarget_failed, :job_timeout],
    from: :retargeting,
    to: :failed,
    do: [status: :manual_retarget]
  )

  invalid(
    [
      :request,
      :cancel,
      :confirm,
      :merge_ok,
      :merge_failed,
      :retarget_ok,
      :retarget_failed,
      :job_timeout
    ],
    from: :any
  )

  def mergeable_now?(d, _), do: d.eligible && d.capabilities.write
  def head_unchanged?(d, _), do: d.head_unchanged && d.capabilities.write
  def native_guard?(d, p), do: head_unchanged?(d, p) && d.capabilities.head_guard
  def has_child?(d, _), do: not is_nil(d.child)

  def retarget_child?(d, p),
    do: has_child?(d, p) && d.capabilities.retarget && d.capabilities.write
end
