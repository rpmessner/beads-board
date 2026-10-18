defmodule Foreman.Initiatives.TreeTest do
  use ExUnit.Case, async: true
  alias Foreman.Initiatives.Tree

  test "planned descendants at any depth, fallout precedence, cross-repo links and sub-epic rollups" do
    beads = [
      b("e", "epic"),
      b("sub", "epic", [{"e", "parent-child"}]),
      b("a", "task", [{"sub", "parent-child"}], "closed", :done),
      b("f", "bug", [{"e", "parent-child"}, {"a", "discovered-from"}]),
      b("f2", "bug", [{"f", "discovered-from"}]),
      b("orphan"),
      %{b("external") | key: {"other", "external"}}
    ]

    links = [%{ticket: {"other", "external"}, epic: {"r", "e"}}]
    result = Tree.build(beads, links)
    assert [epic] = result.epics
    assert epic.key == {"r", "e"}
    assert epic.total == 4
    assert epic.closed == 1
    assert epic.stage == :building
    assert epic.histogram == %{queued: 3, done: 1}
    assert Enum.map(epic.fallout, & &1.id) == ["f", "f2"]
    assert Enum.sort(Enum.map(epic.planned, & &1.id)) == ["a", "external"]
    assert [sub] = epic.children
    assert sub.total == 3
    assert sub.closed == 1
    assert Enum.map(result.orphans, & &1.id) == ["orphan"]
  end

  test "bead ids sort naturally in epics, sub-epics, planned work, fallout and orphans" do
    beads = [
      b("e.10", "epic"),
      b("e.2", "epic"),
      b("e.2.10", "epic", [{"e.2", "parent-child"}]),
      b("e.2.2", "epic", [{"e.2", "parent-child"}]),
      b("t.10", "task", [{"e.2", "parent-child"}]),
      b("t.2", "task", [{"e.2", "parent-child"}]),
      b("f.2.10", "bug", [{"t.2", "discovered-from"}]),
      b("f.2.2", "bug", [{"t.2", "discovered-from"}]),
      b("o.10"),
      b("o.2.10"),
      b("o.2.2")
    ]

    tree = Tree.build(beads)
    assert Enum.map(tree.epics, & &1.id) == ["e.2", "e.10"]
    [epic | _] = tree.epics
    assert Enum.map(epic.children, & &1.id) == ["e.2.2", "e.2.10"]
    assert Enum.map(epic.planned, & &1.id) == ["t.2", "t.10"]
    assert Enum.map(epic.fallout, & &1.id) == ["f.2.2", "f.2.10"]
    assert Enum.map(tree.orphans, & &1.id) == ["o.2.2", "o.2.10", "o.10"]
  end

  test "derived stage is not vacuously shipped and closed epics stay done" do
    assert Tree.stage(:ticketed, []) == :ticketed
    assert Tree.stage(:ticketed, [b("a")]) == :ticketed
    assert Tree.stage(:ticketed, [b("a", "task", [], "open", :reported)]) == :building

    assert Tree.stage(:ticketed, [
             b("a", "task", [], "open", :committed),
             b("b", "task", [], "closed", :done)
           ]) == :shipping

    assert Tree.stage(:ticketed, [b("a", "task", [], "closed", :done)]) == :shipped
    assert Tree.stage(:done, [b("a")]) == :done
  end

  test "cycles terminate and unrelated discovered-from is not called an orphan" do
    beads = [
      b("e", "epic"),
      b("a", "task", [{"e", "parent-child"}, {"b", "parent-child"}]),
      b("b", "task", [{"a", "parent-child"}]),
      b("loose", "task", [{"missing", "discovered-from"}])
    ]

    assert %{epics: [%{total: 2}], orphans: []} = Tree.build(beads)
  end

  defp b(id, type \\ "task", edges \\ [], status \\ "open", stage \\ :queued) do
    %{
      key: {"r", id},
      id: id,
      type: type,
      status: status,
      stage: if(type == "epic", do: :ticketed, else: stage),
      edges: Enum.map(edges, fn {id, type} -> %{target: {"r", id}, type: type} end)
    }
  end
end
