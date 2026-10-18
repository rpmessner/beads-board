defmodule Board.Request do
  @moduledoc "Request lifecycle; kind guards separate decisions from executable actions."
  use Board.Fsm, observed_never_invalid: true
  initial(:new)
  state(:new)
  state(:pending)
  state(:approved)
  state(:answered)
  state(:declined)
  state(:withdrawn)
  state(:superseded)
  state(:executing)
  state(:done)
  state(:failed)
  event(:ask)
  event(:approve)
  event(:answer)
  event(:decline)
  event(:withdraw)
  event(:start)
  event(:facts_changed, source: :observed)
  event(:succeeded, source: :observed)
  event(:failed, source: :observed)
  event(:orphaned, source: :observed)
  effects([:record, :notify, :enqueue, :audit])
  guard(:decision?)
  guard(:action?)
  transition(:ask, from: :new, to: :pending, do: [record: :request, notify: :pending])
  transition(:approve, from: :pending, to: :approved, guard: :action?, do: [enqueue: :job])

  transition(:answer,
    from: :pending,
    to: :answered,
    guard: :decision?,
    do: [record: :answer, notify: :asker]
  )

  transition(:decline, from: :pending, to: :declined, do: [record: :note, notify: :asker])
  transition(:withdraw, from: :pending, to: :withdrawn)
  transition(:facts_changed, from: :pending, to: :superseded, do: [notify: :asker])
  transition(:start, from: :approved, to: :executing, do: [audit: :intent])
  transition(:succeeded, from: :executing, to: :done, do: [audit: :result, notify: :asker])
  transition(:failed, from: :executing, to: :failed, do: [audit: :reason, notify: :asker])
  transition(:orphaned, from: :executing, to: :failed, do: [audit: :unknown, notify: :asker])
  ignore([:facts_changed, :succeeded, :failed, :orphaned], from: :any)
  invalid([:ask, :approve, :answer, :decline, :withdraw, :start], from: :any)

  def decision?(%{kind: "decision"}, _), do: true
  def decision?(_, _), do: false
  def action?(%{kind: kind}, _), do: kind in ["push", "open_pr", "merge"]
  def action?(_, _), do: false
end
