defmodule Foreman.Beads.ReadTest do
  use ExUnit.Case, async: true
  alias Foreman.Beads.Read

  test "the first effect is passive journal observation, never an export" do
    read = Read.new("/tmp/synthetic-repo", "read-1")
    assert {checking, [check_lock: {"read-1", "/tmp/synthetic-repo"}]} = Read.start(read)
    assert checking.state == :checking
  end

  test "only a reaped successful export reaches projection, then publishes its result" do
    {checking, _} = Read.new("/tmp/synthetic-repo", "read-1") |> Read.start()

    assert {exporting, [export: {"read-1", "/tmp/synthetic-repo", 20_000}]} =
             Read.lock_checked(checking, "read-1", :clear)

    assert {projecting, [project: {"read-1", "fixture JSONL"}]} =
             Read.reaped(exporting, "read-1", {:ok, "fixture JSONL"})

    assert {finished, [finished: {"read-1", {:ok, :unchanged}}]} =
             Read.projected(projecting, "read-1", {:ok, :unchanged})

    assert finished.outcome == {:ok, :unchanged}
    assert finished.state == :finished
  end

  test "timeout keeps ownership until reap and discards even successful late stdout" do
    {checking, _} = Read.new("/tmp/synthetic-repo", "read-1") |> Read.start()
    {exporting, _} = Read.lock_checked(checking, "read-1", :clear)

    assert {cancelling, [cancel_export: {"read-1", :timeout}]} =
             Read.cancel(exporting, "read-1", :timeout)

    assert cancelling.state == :cancelling
    assert cancelling.outcome == nil
    assert {^cancelling, []} = Read.cancel(cancelling, "read-1", :timeout)

    assert {finished, [finished: {"read-1", {:error, :timeout}}]} =
             Read.reaped(cancelling, "read-1", {:ok, "late output"})

    assert finished.state == :finished
  end

  test "a failed command emits no projection effect" do
    {checking, _} = Read.new("/tmp/synthetic-repo", "read-1") |> Read.start()
    {exporting, _} = Read.lock_checked(checking, "read-1", :clear)
    error = {:error, {:exit, 1}}
    assert {finished, [finished: {"read-1", ^error}]} = Read.reaped(exporting, "read-1", error)
    assert finished.outcome == error
  end

  test "late messages cannot start exports, project data or finish a different read" do
    {checking, _} = Read.new("/tmp/synthetic-repo", "read-2") |> Read.start()
    assert {^checking, []} = Read.lock_checked(checking, "read-1", :clear)
    assert {^checking, []} = Read.lock_checked(checking, "read-1", {:defer, :held})
    {exporting, _} = Read.lock_checked(checking, "read-2", :clear)
    assert {^exporting, []} = Read.reaped(exporting, "read-1", {:ok, ""})
    assert {^exporting, []} = Read.cancel(exporting, "read-1", :timeout)
    assert {^exporting, []} = Read.projected(exporting, "read-2", {:ok, :unchanged})
  end

  test "cancel before opening has no subprocess to reap; duplicate results are harmless" do
    {checking, _} = Read.new("/tmp/synthetic-repo", "read-1") |> Read.start()

    assert {finished, [finished: {"read-1", {:error, :disabled}}]} =
             Read.cancel(checking, "read-1", :disabled)

    assert {^finished, []} = Read.lock_checked(finished, "read-1", :clear)
    assert {^finished, []} = Read.start(finished)
  end

  test "projection failure finishes without replacing the previous outcome with success" do
    {checking, _} = Read.new("/tmp/synthetic-repo", "read-1") |> Read.start()
    {exporting, _} = Read.lock_checked(checking, "read-1", :clear)
    {projecting, _} = Read.reaped(exporting, "read-1", {:ok, "bad JSONL"})
    error = {:error, :malformed_export}

    assert {finished, [finished: {"read-1", ^error}]} =
             Read.projected(projecting, "read-1", error)

    assert {^finished, []} = Read.projected(finished, "read-1", {:ok, :updated})
  end

  test "a held or indeterminate journal defers without opening or projecting" do
    {checking, _} = Read.new("/tmp/synthetic-repo", "read-1") |> Read.start()

    for reason <- [:held, :indeterminate] do
      assert {finished, [finished: {"read-1", {:defer, ^reason}}]} =
               Read.lock_checked(checking, "read-1", {:defer, reason})

      assert finished.state == :finished
      assert finished.outcome == {:defer, reason}
    end
  end
end
