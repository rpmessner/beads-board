defmodule Foreman.SessionMachineTest do
  use ExUnit.Case, async: true
  alias Foreman.SessionMachine, as: M

  test "coordinator identity selection and active-launch refusal are declared" do
    context = %{coordinator: true}

    assert M.step(:new, :coordinator_resume, context) ==
             {:starting, [identity: :new, open: :window]}

    assert M.step(:ended, :coordinator_resume, context) ==
             {:starting, [identity: :keep, open: :resume]}

    for state <- [:new, :ended] do
      assert M.step(state, :coordinator_fresh, context) ==
               {:starting, [identity: :new, open: :window]}

      assert M.step(state, :adopt, context) == {:ended, [identity: :adopt]}
    end

    for state <- [:starting, :running, :waiting],
        event <- [:coordinator_resume, :coordinator_fresh, :adopt] do
      assert M.step(state, event, context) == {:error, {:invalid, state, event}}
    end
  end

  test "the coordinator never parks, including when its window disappears" do
    for state <- [:starting, :running, :waiting, :ended] do
      assert M.step(state, :idle_timeout, %{coordinator: true}) == {state, []}

      assert M.step(state, :window_gone, %{coordinator: true}) ==
               {:ended, [clear: :waiting]}
    end
  end

  test "idle parking and same-conversation relaunch are declared" do
    for state <- [:running, :waiting, :ended] do
      assert M.step(state, :idle_timeout, %{}) == {:parked, [close: :window, clear: :waiting]}
    end

    for state <- [:parked, :ended] do
      assert M.step(state, :relaunch, %{}) == {:starting, [open: :resume]}
    end
  end

  test "the declared resume guard ignores unrelated tool completions" do
    assert M.step(:waiting, :resumed, %{resume_matches: false}) == {:waiting, []}
  end

  test "waiting and resumed observations follow declared rows and ignore stale signals" do
    for state <- [:starting, :running], do: assert(M.step(state, :waiting, %{}) == {:waiting, []})
    assert M.step(:waiting, :resumed, %{}) == {:running, [clear: :waiting]}
    assert M.step(:waiting, :exited, %{}) == {:ended, [clear: :waiting]}
    assert M.step(:waiting, :window_gone, %{}) == {:parked, [clear: :waiting]}

    for state <- [:new, :waiting, :ended, :parked],
        do: assert(M.step(state, :waiting, %{}) == {state, []})

    for state <- [:new, :starting, :running, :ended, :parked],
        do: assert(M.step(state, :resumed, %{}) == {state, []})
  end

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
    assert M.step(:running, :exited, %{}) == {:ended, [clear: :waiting]}

    for state <- [:starting, :running, :ended] do
      assert M.step(state, :window_gone, %{}) == {:parked, [clear: :waiting]}
    end
  end
end
