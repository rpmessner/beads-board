defmodule Foreman.TicketFileTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Foreman.TicketFile

  def canonical(title \\ "A ticket") do
    "---\nid: bb-abc.1\ntitle: #{Jason.encode!(title)}\ntype: task\nstatus: open\npriority: 2\nparent: bb-abc\nblocked_by: []\nrelated: []\ndiscovered_from: null\nlabels: []\ncreated: 2026-10-18\nclosed: null\nclose_reason: null\n---\n\n## Acceptance\n- [ ] Works\n"
  end

  property "canonical parse then print is byte identity, including Unicode and YAML punctuation" do
    check all(
            title <- string(:utf8, min_length: 1),
            priority <- integer(0..4),
            type <- member_of(~w(epic feature task bug decision)),
            status <- member_of(~w(open in_progress closed deferred)),
            labels <- list_of(string(:alphanumeric, min_length: 1), max_length: 8),
            prose <- string(:alphanumeric),
            title = "Ticket " <> title
          ) do
      text =
        canonical(title)
        |> String.replace("priority: 2", "priority: #{priority}")
        |> String.replace("type: task", "type: #{type}")
        |> String.replace("status: open", "status: #{status}")
        |> String.replace("labels: []", "labels: #{Jason.encode!(Enum.sort(labels))}")
        |> String.replace("Works", "Works #{prose}")

      assert {:ok, ticket} = TicketFile.parse(text)
      assert TicketFile.print(ticket) == text
    end
  end

  for {field, value} <- [
        {"id", "../../escape"},
        {"title", "[]"},
        {"type", "chore"},
        {"status", "done"},
        {"priority", "5"},
        {"priority", "2.0"},
        {"parent", "false"},
        {"blocked_by", "[invalid]"},
        {"related", "no"},
        {"discovered_from", "wrong"},
        {"labels", "[false]"},
        {"created", "2026-02-30"},
        {"closed", "tomorrow"},
        {"close_reason", "[]"}
      ] do
    test "schema rejects #{field}: #{value}" do
      text =
        Regex.replace(~r/^#{unquote(field)}:.*$/m, canonical(), unquote(field <> ": " <> value))

      assert {:error, reason} = TicketFile.parse(text)
      assert reason =~ unquote(field)
    end
  end

  test "duplicate keys, multiple documents and nested mappings are invalid" do
    assert {:error, _} =
             TicketFile.parse(
               String.replace(canonical(), "priority: 2", "priority: 2\npriority: 3")
             )

    assert {:error, _} = TicketFile.parse("---\n---\nid: bb-abc\n---\n")

    assert {:error, _} =
             TicketFile.parse(
               String.replace(canonical(), "labels: []", "labels: {nested: value}")
             )
  end

  test "handwritten YAML lists and comments become sorted canonical lists" do
    text =
      canonical()
      |> String.replace("labels: []", "labels:\n  - zebra\n  - alpha # comment")
      |> String.replace("title: \"A ticket\"", "title: A ticket # comment")

    assert {:ok, ticket} = TicketFile.parse(text)
    printed = TicketFile.print(ticket)
    assert printed =~ ~s(labels: ["alpha","zebra"])
    assert printed =~ ~s(title: "A ticket")
    assert {:ok, reparsed} = TicketFile.parse(printed)
    assert TicketFile.print(reparsed) == printed
  end

  test "rejects malformed and unknown frontmatter without treating prose as YAML" do
    assert {:error, _} = TicketFile.parse("not frontmatter")

    assert {:error, _} =
             TicketFile.parse(String.replace(canonical(), "priority: 2", "priority: ["))

    assert {:error, reason} =
             TicketFile.parse(String.replace(canonical(), "priority: 2", "surprise: 2"))

    assert reason =~ "surprise"
  end
end
