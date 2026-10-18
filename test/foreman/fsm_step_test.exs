Code.require_file("fsm_probe_helper.exs", __DIR__)

defmodule Foreman.FsmStepTest do
  use ExUnit.Case, async: true
  alias Foreman.FsmProbe, as: M

  test "guard order, payload and exit-row-entry effect order" do
    assert M.step(:off, {:start, :yes}, :ready) ==
             {:on, [emit: :exit, emit: :first, emit: :enter]}

    assert M.step(:off, {:start, :no}, :ready) ==
             {:on, [emit: :exit, emit: :second, emit: :enter]}

    assert M.step(:off, :start, :no) == {:error, {:invalid, :off, :start}}
  end

  test "stay and explicit self transitions do not run state effects" do
    assert M.step(:off, :pulse, nil) == {:off, [emit: :pulse]}
    assert M.step(:on, :pulse, nil) == {:on, [emit: :pulse]}
    assert M.step(:on, :stop, nil) == {:on, [emit: :self]}
  end

  test "state specificity beats event specificity even when declared later" do
    assert M.step(:on, :quit, nil) == {:closed, []}
    assert M.step(:closed, :quit, nil) == {:closed, []}
    assert M.step(:off, :stop, nil) == {:off, []}
  end

  test "unknown and malformed inputs are invalid without converting atoms" do
    for {state, event} <- [
          {:unknown, :start},
          {:off, :unknown},
          {:off, {"start", %{}}},
          {:off, []},
          {nil, nil}
        ] do
      assert M.step(state, event, nil) == {:error, {:invalid, state, event}}
    end

    assert M.step(:off, {:start, :yes}, :no) == {:error, {:invalid, :off, {:start, :yes}}}
  end

  test "introspection preserves declaration order and named groups" do
    assert M.__fsm__(:initial) == :off
    assert M.__fsm__(:states) == [:off, :on, :closed]
    assert M.__fsm__(:events) == [:start, :stop, :quit, :pulse]
    assert M.__fsm__(:groups) == %{live: [:off, :on]}
    assert length(M.__fsm__(:rows)) == 8
  end
end
