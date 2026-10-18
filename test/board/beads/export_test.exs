defmodule Board.Beads.ExportTest do
  use ExUnit.Case, async: true
  alias Board.Beads.Export

  defp issue(attrs) do
    Map.merge(
      %{"id" => "demo-1", "title" => "Ticket", "status" => "open", "issue_type" => "task"},
      attrs
    )
  end

  test "unknown enum strings survive without becoming atoms" do
    raw =
      issue(%{
        "status" => "future-status",
        "issue_type" => "future-type",
        "dependencies" => [%{"depends_on_id" => "demo-2", "type" => "future-edge"}]
      })

    assert {:ok, %{beads: [bead]}} = Export.decode(Jason.encode!(raw))
    assert bead.status == {:unknown, "future-status"}
    assert bead.issue_type == {:unknown, "future-type"}
    assert [%{type: {:unknown, "future-edge"}}] = bead.edges
  end

  test "malformed records reject the whole export, never a partial deletion snapshot" do
    good = Jason.encode!(issue(%{"id" => "demo-first"}))

    invalid = [
      "{",
      "null",
      "[]",
      "42",
      Jason.encode!(issue(%{"id" => ""})),
      Jason.encode!(issue(%{"status" => 42})),
      Jason.encode!(issue(%{"labels" => false})),
      Jason.encode!(issue(%{"dependencies" => [%{"depends_on_id" => "demo-2"}]})),
      Jason.encode!(issue(%{"comments" => [%{"author" => "agent", "text" => 42}]})),
      Jason.encode!(issue(%{"updated_at" => "yesterday"})),
      Jason.encode!(issue(%{"_type" => "future-record"}))
    ]

    for bad <- invalid do
      assert {:error, {:invalid_export, 2}} = Export.decode(good <> "\n" <> bad)
    end

    assert {:error, {:invalid_export, 2}} = Export.decode(good <> "\n" <> good)
  end

  test "empty export is valid and hash identifies original bytes" do
    assert {:ok, %{beads: [], sha256: hash}} = Export.decode("")
    assert hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    assert {:ok, %{beads: [], sha256: other_hash}} = Export.decode("\n")
    refute other_hash == hash
  end

  test "normalizes a complete export including notes, comments, edges and unknown fields" do
    output = File.read!("test/fixtures/beads/export.jsonl")
    assert {:ok, %{beads: [epic, ticket], sha256: hash}} = Export.decode(output)
    assert byte_size(hash) == 64
    assert epic.bead_id == "demo-1"
    assert epic.status == :open
    assert epic.issue_type == :epic
    assert epic.labels == ["foundation"]
    assert epic.raw["future_field"] == %{"kept" => true}
    assert ticket.status == :in_progress
    assert ticket.notes == "Latest note"
    assert ticket.created_at == ~U[2026-10-17 12:00:00Z]
    assert ticket.closed_at == nil
    assert ticket.labels == []

    assert Enum.map(ticket.edges, &{&1.to_bead_id, &1.type}) ==
             [{"demo-1", :parent_child}, {"demo-2", :blocks}]

    assert [%{author: "builder", body: "Working on it"}] = ticket.comments
  end
end
