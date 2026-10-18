defmodule Foreman.Forge.ReadMachineTest do
  use ExUnit.Case, async: true
  alias Foreman.Forge.ReadLifecycle, as: ReadMachine

  test "cadence, manual admission and rate limiting are declared guards" do
    data = %{elapsed: 10, manual: false, rate_limited: false}
    assert {:fresh, []} = ReadMachine.step(:fresh, :start, data)

    assert {:reading, [fetch: :snapshot]} =
             ReadMachine.step(:fresh, :start, %{data | elapsed: 120})

    assert {:reading, [fetch: :snapshot]} =
             ReadMachine.step(:fresh, :start, %{data | manual: true})

    assert {:failed, []} =
             ReadMachine.step(:failed, :start, %{data | manual: true, rate_limited: true})

    assert {:reading, []} = ReadMachine.step(:reading, :start, %{data | elapsed: 120})
    assert {:fresh, [publish: :snapshot]} = ReadMachine.step(:reading, :succeeded, %{})
    assert {:failed, [retain: :snapshot]} = ReadMachine.step(:reading, :failed, %{})
  end
end
