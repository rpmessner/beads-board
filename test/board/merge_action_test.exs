defmodule Board.MergeActionTest do
  use ExUnit.Case, async: true
  alias Board.Merge.Action

  defp data,
    do: %{
      eligible: true,
      head_unchanged: true,
      child: 6,
      capabilities: %{write: true, head_guard: true, retarget: true}
    }

  test "confirmation, merge and retarget are explicit transitions" do
    assert {:confirming, []} = Action.step(:idle, :request, data())
    assert {:merging, [enqueue: :merge]} = Action.step(:confirming, :confirm, data())
    assert {:retargeting, [enqueue: :retarget]} = Action.step(:merging, :merge_ok, data())
    assert {:merged, []} = Action.step(:retargeting, :retarget_ok, data())
    assert {:failed, [status: :failed]} = Action.step(:merging, :job_timeout, data())
  end

  test "capabilities gate writes, weaker guard and manual retarget" do
    d = put_in(data(), [:capabilities, :write], false)
    assert {:idle, [status: :refused]} = Action.step(:idle, :request, d)
    d = put_in(data(), [:capabilities, :head_guard], false)
    assert {:merging, [verify: :head, enqueue: :merge]} = Action.step(:confirming, :confirm, d)
    d = put_in(data(), [:capabilities, :retarget], false)
    assert {:merged, [status: :manual_retarget]} = Action.step(:merging, :merge_ok, d)

    assert {:confirming, [status: :head_moved]} =
             Action.step(:confirming, :confirm, %{data() | head_unchanged: false})
  end
end
