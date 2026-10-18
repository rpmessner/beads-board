defmodule Board.Forge.StackTest do
  use ExUnit.Case, async: true
  alias Board.Forge.Stack

  test "orders default-rooted chains before detached bases and bounds cycles" do
    prs = [
      pr(6, "second", "first"),
      pr(8, "detached", "missing"),
      pr(5, "first", "main"),
      pr(9, "cycle-a", "cycle-b"),
      pr(10, "cycle-b", "cycle-a")
    ]

    assert Enum.map(Stack.order(prs, "main"), &{&1["number"], &1["depth"], &1["detached"]}) == [
             {5, 0, false},
             {6, 1, false},
             {8, 0, true},
             {9, 0, true},
             {10, 1, true}
           ]
  end

  test "links each bead using title before branch before body with exact prefix boundaries" do
    pr = %{
      "title" => "fe-813.2 and fe-lwp.15 not xfe-abc",
      "source_branch" => "feature/fe-813.2-fe-abc",
      "body" => "fe-abc fe-def fe-813.2 other-123"
    }

    assert Stack.links(pr, "fe") == [
             %{"bead_id" => "fe-813.2", "source" => "title"},
             %{"bead_id" => "fe-lwp.15", "source" => "title"},
             %{"bead_id" => "fe-abc", "source" => "branch"},
             %{"bead_id" => "fe-def", "source" => "body"}
           ]
  end

  defp pr(n, head, base),
    do: %{"number" => n, "source_branch" => head, "target_branch" => base, "state" => "open"}
end
