defmodule Board.Beads.ProjectionTest do
  use Board.DataCase, async: true
  alias Board.Beads.Projection

  test "unchanged bytes perform no projection writes" do
    output = File.read!("test/fixtures/beads/export.jsonl")
    assert {:ok, :changed} = Projection.replace("hash", output)
    before = Repo.one(from r in "bead_repos", where: r.key == "hash", select: r.synced_at)
    handler = "projection-sql-#{System.unique_integer([:positive])}"
    :ok = :telemetry.attach(handler, [:board, :repo, :query], &__MODULE__.query/4, self())

    try do
      assert {:ok, :unchanged} = Projection.replace("hash", output)
      refute_received {:write, _}

      assert before ==
               Repo.one(from r in "bead_repos", where: r.key == "hash", select: r.synced_at)
    after
      :telemetry.detach(handler)
    end
  end

  def query(_, _, %{query: sql}, owner) do
    if self() == owner and Regex.match?(~r/^\s*(INSERT|UPDATE|DELETE)/i, sql),
      do: send(owner, {:write, sql})
  end

  test "malformed input retains the last good projection" do
    output = File.read!("test/fixtures/beads/export.jsonl")
    assert {:ok, :changed} = Projection.replace("invalid", output)
    before = Projection.list_raw("invalid")
    assert {:error, {:invalid_export, 1}} = Projection.replace("invalid", "truncated{")
    assert Projection.list_raw("invalid") == before
  end

  test "missing beads mark overlay facts orphaned without deleting them; reappearance clears the marker" do
    now = DateTime.utc_now()
    output = File.read!("test/fixtures/beads/export.jsonl")
    assert {:ok, :changed} = Projection.replace("orphan", output)

    Repo.insert_all("tickets", [
      %{repo_key: "orphan", bead_id: "demo-1.1", stage: "building", stage_changed_at: now},
      %{repo_key: "unrelated", bead_id: "demo-1.1", stage: "reported", stage_changed_at: now}
    ])

    assert {:ok, :changed} = Projection.replace("orphan", "")
    assert %{stage: "building", orphaned_at: orphaned} = overlay("orphan")
    refute is_nil(orphaned)
    assert %{stage: "reported", orphaned_at: nil} = overlay("unrelated")
    assert {:ok, :changed} = Projection.replace("orphan", output)
    assert %{stage: "building", orphaned_at: nil} = overlay("orphan")
  end

  test "dropping the cache leaves process facts intact" do
    output = File.read!("test/fixtures/beads/export.jsonl")
    assert {:ok, :changed} = Projection.replace("rebuild", output)

    Repo.insert_all("tickets", [
      %{
        repo_key: "rebuild",
        bead_id: "demo-1.1",
        stage: "committed",
        stage_changed_at: DateTime.utc_now()
      }
    ])

    Repo.delete_all(from r in "bead_repos", where: r.key == "rebuild")
    assert Projection.list_raw("rebuild") == []
    assert %{stage: "committed", orphaned_at: nil} = overlay("rebuild")
    assert {:ok, :changed} = Projection.replace("rebuild", output)
    assert length(Projection.list_raw("rebuild")) == 2
    assert %{stage: "committed", orphaned_at: nil} = overlay("rebuild")
  end

  defp overlay(key) do
    Repo.one(
      from t in "tickets",
        where: t.repo_key == ^key,
        select: %{stage: t.stage, orphaned_at: t.orphaned_at}
    )
  end

  test "replaces only one repo's complete export and retains all raw content" do
    output = File.read!("test/fixtures/beads/export.jsonl")
    assert {:ok, :changed} = Projection.replace("demo", output)
    assert {:ok, :changed} = Projection.replace("other", output)
    assert [%{"id" => "demo-1"}, %{"notes" => "Latest note"}] = Projection.list_raw("demo")
    changed = String.replace(output, "Latest note", "New note")
    assert {:ok, :changed} = Projection.replace("demo", changed)
    assert [_, %{"notes" => "New note"}] = Projection.list_raw("demo")
    assert {:ok, :changed} = Projection.replace("demo", "")
    assert Projection.list_raw("demo") == []
    assert length(Projection.list_raw("other")) == 2
  end
end
