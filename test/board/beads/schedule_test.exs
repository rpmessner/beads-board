defmodule Board.Beads.ScheduleTest do
  use ExUnit.Case, async: true
  alias Board.Beads.Schedule

  test "a nominal tick enqueues even without any changed file signal" do
    snapshot = Schedule.new({123, 456}, "boot-a", 0)
    assert {active, [enqueue: {{123, 456}, {"boot-a", 1}}]} = Schedule.request(snapshot, 0)
    assert active.state == :active
    assert active.next_at == 3_000
  end

  test "ticks, pings and sweeps cannot build a catch-up queue while a read is active" do
    {active, _} = Schedule.new(:store, "a", 0) |> Schedule.request(0)

    for now <- [1, 3_000, 6_000, 300_000] do
      assert {^active, []} = Schedule.request(active, now)
    end

    assert {idle, []} = Schedule.finish(active, {"a", 1})
    assert {_, [enqueue: {:store, {"a", 2}}]} = Schedule.request(idle, 303_000)
  end

  test "a ping after a fast completion cannot shorten the nominal interval" do
    {active, _} = Schedule.new(:store, "a", -10_000) |> Schedule.request(-10_000)
    {idle, []} = Schedule.finish(active, {"a", 1})
    assert {^idle, []} = Schedule.request(idle, -7_001)
    assert {_, [enqueue: {:store, {"a", 2}}]} = Schedule.request(idle, -7_000)
  end

  test "late completions from earlier jobs or previous owner boots do not release a flight" do
    {active, _} = Schedule.new(:store, "a", 0) |> Schedule.request(0)
    {idle, _} = Schedule.finish(active, {"a", 1})
    {new_active, _} = Schedule.request(idle, 3_000)
    assert {^new_active, []} = Schedule.finish(new_active, {"a", 1})
    assert {^new_active, []} = Schedule.finish(new_active, {"old-boot", 2})
    assert {^new_active, []} = Schedule.finish(new_active, nil)
  end

  test "disabling holds admission until cancellation has actually finished" do
    {active, _} = Schedule.new(:store, "a", 0) |> Schedule.request(0)
    assert {draining, [cancel: {:store, {"a", 1}}]} = Schedule.disable(active)
    assert draining.state == :draining
    assert {^draining, []} = Schedule.request(draining, 30_000)
    assert {^draining, []} = Schedule.disable(draining)
    assert {disabled, []} = Schedule.finish(draining, {"a", 1})
    assert disabled.state == :disabled
    assert {^disabled, []} = Schedule.request(disabled, 60_000)
    {enabled, []} = Schedule.enable(disabled)
    assert {_, [enqueue: {:store, {"a", 2}}]} = Schedule.request(enabled, 63_000)
  end

  test "re-enabling during cancellation still waits for the old child to be reaped" do
    {active, _} = Schedule.new(:store, "a", 0) |> Schedule.request(0)
    {draining, _} = Schedule.disable(active)
    {enabled, []} = Schedule.enable(draining)
    assert {^enabled, []} = Schedule.request(enabled, 30_000)
    {idle, []} = Schedule.finish(enabled, {"a", 1})
    assert {_, [enqueue: {:store, {"a", 2}}]} = Schedule.request(idle, 33_000)
  end
end
