defmodule Board.RequestMachineTest do
  use ExUnit.Case, async: true
  alias Board.Request, as: Machine

  test "every request transition and its effects" do
    for {from, event, kind, to, effects} <- [
          {:new, :ask, "decision", :pending, [record: :request, notify: :pending]},
          {:pending, :approve, "push", :approved, [enqueue: :job]},
          {:pending, :answer, "decision", :answered, [record: :answer, notify: :asker]},
          {:pending, :decline, "decision", :declined, [record: :note, notify: :asker]},
          {:pending, :withdraw, "decision", :withdrawn, []},
          {:pending, :facts_changed, "decision", :superseded, [notify: :asker]},
          {:approved, :start, "push", :executing, [audit: :intent]},
          {:executing, :succeeded, "push", :done, [audit: :result, notify: :asker]},
          {:executing, :failed, "push", :failed, [audit: :reason, notify: :asker]},
          {:executing, :orphaned, "push", :failed, [audit: :unknown, notify: :asker]}
        ] do
      assert Machine.step(from, event, %{kind: kind}) == {to, effects}
    end
  end

  test "wrong kind claims are invalid" do
    assert {:error, _} = Machine.step(:pending, :approve, %{kind: "decision"})
    assert {:error, _} = Machine.step(:pending, :answer, %{kind: "push"})
  end

  test "all other declared pairs reject claims and ignore observations" do
    valid =
      MapSet.new([
        {:new, :ask},
        {:pending, :approve},
        {:pending, :answer},
        {:pending, :decline},
        {:pending, :withdraw},
        {:pending, :facts_changed},
        {:approved, :start},
        {:executing, :succeeded},
        {:executing, :failed},
        {:executing, :orphaned}
      ])

    for state <- Machine.__fsm__(:states),
        {event, source} <- Machine.__fsm__(:sources),
        not MapSet.member?(valid, {state, event}) do
      result = Machine.step(state, event, %{kind: "decision"})

      if source == :observed,
        do: assert(result == {state, []}),
        else: assert(match?({:error, _}, result))
    end
  end
end
