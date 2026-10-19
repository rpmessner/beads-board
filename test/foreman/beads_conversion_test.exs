defmodule Foreman.BeadsConversionTest do
  use ExUnit.Case, async: true
  alias Foreman.BeadsConversion, as: Conversion

  def record do
    [record] = "test/fixtures/beads-adopt.jsonl" |> File.read!() |> Conversion.decode()
    record
  end

  test "maps convoy, chore and every supported relation without losing edge multiplicity" do
    deps =
      for {kind, id} <- [
            {"tracks", "demo-b"},
            {"related", "demo-b"},
            {"tracks", "demo-c"},
            {"supersedes", "demo-old"}
          ],
          do: %{"type" => kind, "depends_on_id" => id}

    source = record() |> Map.put("issue_type", "convoy") |> Map.put("dependencies", deps)
    assert {:ok, tickets} = Conversion.convert([source])
    assert tickets["demo-a"].facts["type"] == "epic"
    assert tickets["demo-a"].facts["related"] == ["demo-b", "demo-b", "demo-c"]
    assert tickets["demo-a"].facts["supersedes"] == ["demo-old"]
    assert {:ok, %{count: 1}} = Conversion.compare([source], tickets)

    for {field, value} <- [
          {"related", ["demo-b", "demo-c"]},
          {"supersedes", []},
          {"type", "convoy"}
        ] do
      assert {:error, _} =
               Conversion.compare([source], put_in(tickets, ["demo-a", :facts, field], value))
    end

    chore = Map.put(source, "issue_type", "chore")
    assert {:ok, chores} = Conversion.convert([chore])
    assert chores["demo-a"].facts["type"] == "chore"
    assert {:ok, _} = Conversion.compare([chore], chores)
  end

  test "refuses relationships or incomplete comments that cannot be represented" do
    for record <- [
          put_in(record(), ["dependencies"], [%{"type" => "unknown", "depends_on_id" => "demo-b"}]),
          put_in(record(), ["dependencies"], [
            %{"type" => "parent-child", "depends_on_id" => "demo-b"},
            %{"type" => "parent-child", "depends_on_id" => "demo-c"}
          ]),
          Map.put(record(), "comment_count", 2)
        ] do
      assert {:error, _} = Conversion.convert([record])
    end
  end

  test "comparison ignores excluded metadata but detects each lost mapped prose field" do
    source = record()
    {:ok, tickets} = Conversion.convert([source])

    ignored =
      source
      |> Map.drop(~w(owner assignee created_by updated_at custom _type))
      |> Map.update!("comments", fn comments -> Enum.map(comments, &Map.delete(&1, "id")) end)
      |> Map.update!("dependencies", fn deps ->
        Enum.map(deps, &Map.put(&1, "metadata", "not mapped"))
      end)

    assert {:ok, _} = Conversion.compare([ignored], tickets)

    for field <- ~w(description acceptance_criteria design notes) do
      assert {:error, _} = Conversion.compare([Map.delete(source, field)], tickets)
    end

    for field <- ~w(created_at author text) do
      changed =
        Map.update!(source, "comments", fn [comment] ->
          [Map.put(comment, field, "2025-01-01 changed")]
        end)

      assert {:error, _} = Conversion.compare([changed], tickets)
    end
  end

  test "empty mapped prose round trips through the file codec and comparison" do
    source =
      record()
      |> Map.drop(~w(description acceptance_criteria design notes comments comment_count))

    {:ok, tickets} = Conversion.convert([source])
    {:ok, parsed} = tickets["demo-a"] |> Foreman.TicketFile.print() |> Foreman.TicketFile.parse()
    assert parsed.body == ""
    assert {:ok, _} = Conversion.compare([source], %{"demo-a" => parsed})
  end

  test "comparison detects changed fields, bodies, comments and missing tickets" do
    records = [record()]
    {:ok, tickets} = Conversion.convert(records)
    assert {:ok, %{count: 1, comments: 1}} = Conversion.compare(records, tickets)

    for key <- Foreman.TicketFile.keys() do
      changed = put_in(tickets, ["demo-a", :facts, key], "wrong")
      assert {:error, _} = Conversion.compare(records, changed)
    end

    assert {:error, _} = Conversion.compare(records, %{})
    assert {:error, _} = Conversion.compare(records, put_in(tickets, ["demo-a", :body], "lost"))
  end

  test "conversion contains only mapped facts and sections, without provenance" do
    assert {:ok, %{"demo-a" => ticket}} = Conversion.convert([record()])

    assert ticket.facts == %{
             "id" => "demo-a",
             "title" => "A",
             "type" => "bug",
             "status" => "closed",
             "priority" => 1,
             "created" => "2026-01-02",
             "closed" => "2026-01-03",
             "close_reason" => "Fixed",
             "parent" => "demo-c",
             "blocked_by" => ["demo-b"],
             "related" => ["demo-d"],
             "supersedes" => [],
             "discovered_from" => "demo-e",
             "labels" => ["a", "z"]
           }

    assert ticket.body =~ "## Acceptance\n- [x] Done"
    assert ticket.body =~ "- 2026-01-03 Alice: First\n  second"
    assert ticket.body =~ "Old note"
    assert ticket.body =~ "## Design\nKeep the seam small"

    assert ticket.body ==
             "Build it\n\n## Acceptance\n- [x] Done\n\n## Design\nKeep the seam small\n\n## Notes\nOld note\n\n- 2026-01-03 Alice: First\n  second\n"

    refute Foreman.TicketFile.print(ticket) =~ "## Beads provenance"
  end
end
