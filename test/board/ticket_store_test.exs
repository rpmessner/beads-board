defmodule Board.TicketStoreTest do
  use ExUnit.Case, async: false
  alias Board.{TicketFile, TicketStore}
  import Mimic

  setup do
    root = Path.join(System.tmp_dir!(), "board-files-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "tickets"))
    {_, 0} = System.cmd("git", ["init", "-q", root])
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  def ticket(id, attrs \\ %{}) do
    %{
      facts:
        Map.merge(
          %{
            "id" => id,
            "title" => "Ticket",
            "type" => "task",
            "status" => "open",
            "priority" => 2,
            "parent" => nil,
            "blocked_by" => [],
            "related" => [],
            "discovered_from" => nil,
            "labels" => [],
            "created" => "2026-10-18",
            "closed" => nil,
            "close_reason" => nil
          },
          attrs
        ),
      body: ""
    }
  end

  def put(root, id, attrs \\ %{}) do
    File.write!(Path.join([root, "tickets", id <> ".md"]), TicketFile.print(ticket(id, attrs)))
  end

  for {name, attrs, reason} <- [
        {"schema", %{"priority" => 9}, "priority"},
        {"filename", %{"id" => "bb-other"}, "filename"},
        {"missing parent", %{"parent" => "bb-gone"}, "parent"},
        {"missing blocker", %{"blocked_by" => ["bb-gone"]}, "blocker"},
        {"dependency cycle", %{"blocked_by" => ["bb-abc"]}, "cycle"},
        {"parent cycle", %{"parent" => "bb-abc"}, "cycle"}
      ] do
    test "check reports #{name} with its file", %{root: root} do
      put(root, "bb-abc", unquote(Macro.escape(attrs)))
      assert [%{file: "tickets/bb-abc.md", reason: reason} | _] = TicketStore.check(root)
      assert reason =~ unquote(reason)
    end
  end

  test "rejects an epic blocking its own descendant", %{root: root} do
    put(root, "bb-abc", %{"type" => "epic"})
    put(root, "bb-abc.1", %{"parent" => "bb-abc"})
    put(root, "bb-abc.1.1", %{"parent" => "bb-abc.1", "blocked_by" => ["bb-abc"]})
    assert [%{reason: reason}] = TicketStore.check(root)
    assert reason =~ "epic"
  end

  @tag timeout: 2_000
  test "shared dependency paths do not cause exponential graph traversal", %{root: root} do
    for n <- 1..36 do
      blockers = for previous <- [n - 1, n - 2], previous > 0, do: "bb-a#{previous}"
      put(root, "bb-a#{n}", %{"blocked_by" => blockers})
    end

    assert TicketStore.check(root) == []
  end

  test "valid graph and arbitrary prose are accepted", %{root: root} do
    put(root, "bb-abc", %{"type" => "epic"})
    put(root, "bb-abc.1", %{"parent" => "bb-abc"})
    put(root, "bb-abc.2", %{"parent" => "bb-abc", "blocked_by" => ["bb-abc.1"]})
    assert TicketStore.check(root) == []
    assert {:ok, tickets} = TicketStore.load(root)
    assert map_size(tickets) == 3
  end

  test "stale snapshots never overwrite hand edits or newly created files", %{root: root} do
    put(root, "bb-abc")
    {:ok, before} = TicketStore.load(root)
    changed = put_in(before, ["bb-abc", :facts, "title"], "CLI edit")
    put(root, "bb-abc", %{"title" => "Hand edit"})
    assert {:error, reason} = TicketStore.save(root, before, changed)
    assert reason =~ "changed"
    assert File.read!(Path.join([root, "tickets", "bb-abc.md"])) =~ "Hand edit"
    {:ok, before} = TicketStore.load(root)
    put(root, "bb-new")

    assert {:error, _} =
             TicketStore.save(root, before, Map.put(before, "bb-new", ticket("bb-new")))
  end

  test "check reports a symlinked ticket as an error instead of crashing", %{root: root} do
    File.write!(Path.join(root, "hand.md"), "do not read")
    File.ln_s!(Path.join(root, "hand.md"), Path.join([root, "tickets", "bb-abc.md"]))
    assert [%{file: "tickets/bb-abc.md", reason: reason}] = TicketStore.check(root)
    assert reason =~ "regular ticket file"
  end

  test "symlinked ticket directories are refused rather than writing outside checkout", %{
    root: root
  } do
    target = Path.join(root, "elsewhere")
    File.rename!(Path.join(root, "tickets"), target)
    File.ln_s!(target, Path.join(root, "tickets"))
    assert {:error, _} = TicketStore.load(root)
    assert {:error, _} = TicketStore.save(root, %{}, %{"bb-abc" => ticket("bb-abc")})
    assert File.ls!(target) == []
  end

  test "a hand edit after the last preflight read is restored, not overwritten", %{root: root} do
    put(root, "bb-abc")
    {:ok, before} = TicketStore.load(root)
    changed = put_in(before, ["bb-abc", :facts, "title"], "CLI edit")

    expect(File, :rename, fn source, destination ->
      File.write!(source, TicketFile.print(ticket("bb-abc", %{"title" => "Late hand edit"})))
      Mimic.call_original(File, :rename, [source, destination])
    end)

    assert {:error, reason} = TicketStore.save(root, before, changed)
    assert reason =~ "changed while writing"
    assert File.read!(Path.join([root, "tickets", "bb-abc.md"])) =~ "Late hand edit"
    refute File.exists?(Path.join([root, ".git", ".board-write-lock"]))
  end

  test "an editor saving during publication wins and originals remain recoverable", %{root: root} do
    put(root, "bb-abc")
    {:ok, before} = TicketStore.load(root)
    changed = put_in(before, ["bb-abc", :facts, "title"], "CLI edit")

    expect(File, :ln, 2, fn source, destination ->
      if String.contains?(source, "/prepared/") do
        File.write!(destination, TicketFile.print(ticket("bb-abc", %{"title" => "Editor won"})))
      end

      Mimic.call_original(File, :ln, [source, destination])
    end)

    assert {:error, reason} = TicketStore.save(root, before, changed)
    assert reason =~ "without replacing"
    assert File.read!(Path.join([root, "tickets", "bb-abc.md"])) =~ "Editor won"

    recovery = Path.join([root, ".git", ".board-write-lock"])
    assert reason =~ recovery
    assert File.read!(Path.join([recovery, "originals", "bb-abc.md"])) == before["bb-abc"].source
    assert [%{reason: check_reason}] = TicketStore.check(root)
    assert check_reason =~ recovery
    {_, 0} = System.cmd("git", ["-C", root, "add", "tickets"])
    {staged, 0} = System.cmd("git", ["-C", root, "diff", "--cached", "--name-only"])
    assert staged == "tickets/bb-abc.md\n"
  end

  test "an in-place edit through an open descriptor during publication is retained", %{root: root} do
    put(root, "bb-abc")
    path = Path.join([root, "tickets", "bb-abc.md"])
    {:ok, before} = TicketStore.load(root)
    changed = put_in(before, ["bb-abc", :facts, "title"], "CLI edit")

    File.open!(path, [:read, :write], fn descriptor ->
      expect(File, :ln, 2, fn source, destination ->
        if String.contains?(source, "/prepared/") do
          :ok = :file.pwrite(descriptor, 0, "HAND EDIT")
        end

        Mimic.call_original(File, :ln, [source, destination])
      end)

      assert {:error, reason} = TicketStore.save(root, before, changed)
      assert reason =~ "changed"

      assert File.read!(Path.join([root, ".git", ".board-write-lock", "originals", "bb-abc.md"])) =~
               "HAND EDIT"
    end)
  end

  test "readers and check refuse an in-flight or recovery snapshot", %{root: root} do
    put(root, "bb-abc")
    File.mkdir!(Path.join([root, ".git", ".board-write-lock"]))
    assert {:error, {:busy, reason}} = TicketStore.load(root)
    assert reason =~ "write"
    assert [%{file: "tickets", reason: reason}] = TicketStore.check(root)
    assert reason =~ "write"
  end

  test "a gitfile checkout uses its own git dir, not a tracked directory", %{root: root} do
    checkout = Path.join(root, "separate")
    git_dir = Path.join(root, "admin")
    {_, 0} = System.cmd("git", ["init", "-q", "--separate-git-dir", git_dir, checkout])
    assert :ok = TicketStore.save(checkout, %{}, %{"bb-abc" => ticket("bb-abc")})
    lock = Path.join(git_dir, ".board-write-lock")
    File.mkdir!(lock)
    assert {:error, {:busy, reason}} = TicketStore.load(checkout)
    assert reason =~ lock
    assert [%{reason: reason}] = TicketStore.check(checkout)
    assert reason =~ lock
    refute File.exists?(Path.join([checkout, "tickets", ".board-write-lock"]))
  end

  test "linked worktree recovery is isolated from the main checkout", %{root: root} do
    checkout = Path.join(root, "linked")

    {_, 0} =
      System.cmd("git", ["-C", root, "worktree", "add", "--orphan", "-b", "scratch", checkout],
        stderr_to_stdout: true
      )

    assert :ok = TicketStore.save(checkout, %{}, %{"bb-abc" => ticket("bb-abc")})
    lock = Path.join([root, ".git", "worktrees", "linked", ".board-write-lock"])
    File.mkdir!(lock)
    assert [%{reason: reason}] = TicketStore.check(checkout)
    assert reason =~ lock
    assert TicketStore.check(root) == []
    refute File.exists?(Path.join([checkout, "tickets", ".board-write-lock"]))
  end

  test "ids retry collisions and choose the next free child number" do
    assert TicketStore.next_id("bb", "bb-abc", ["bb-abc.1", "bb-abc.3"]) == "bb-abc.2"
    counter = start_supervised!({Agent, fn -> ["abc", "xyz"] end})
    generator = fn -> Agent.get_and_update(counter, fn [id | rest] -> {id, rest} end) end
    assert TicketStore.next_id("custom", nil, ["custom-abc"], generator) == "custom-xyz"
    assert TicketStore.next_id("custom", nil, []) =~ ~r/^custom-[a-z0-9]{3}$/
  end
end
