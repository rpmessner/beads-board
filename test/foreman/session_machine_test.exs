defmodule Foreman.SessionMachineTest do
  use ExUnit.Case, async: true
  alias Foreman.SessionMachine, as: M

  test "other claims are invalid and stale observations are ignored" do
    for state <- [:starting, :running, :ended, :parked] do
      assert M.step(state, :launch, %{}) == {:error, {:invalid, state, :launch}}
    end

    for {state, event} <- [
          {:new, :started},
          {:running, :started},
          {:ended, :started},
          {:parked, :started},
          {:new, :exited},
          {:starting, :exited},
          {:ended, :exited},
          {:parked, :exited},
          {:new, :window_gone},
          {:parked, :window_gone}
        ] do
      assert M.step(state, event, %{}) == {state, []}
    end
  end

  test "launch, pane start, exit and window loss follow the declared lifecycle" do
    assert M.step(:new, :launch, %{}) == {:starting, [open: :window]}
    assert M.step(:starting, :started, %{}) == {:running, []}
    assert M.step(:running, :exited, %{}) == {:ended, []}

    for state <- [:starting, :running, :ended] do
      assert M.step(state, :window_gone, %{}) == {:parked, []}
    end
  end
end
