defmodule Foreman.Beads.JournalLockTest do
  use ExUnit.Case, async: true
  alias Foreman.Beads.JournalLock

  setup do
    repo = Path.join(System.tmp_dir!(), "foreman-lock-#{System.unique_integer([:positive])}")
    journal = Path.join(repo, ".beads/embeddeddolt/demo/.dolt/noms/LOCK")
    File.mkdir_p!(Path.dirname(journal))
    File.write!(journal, "")
    on_exit(fn -> File.rm_rf!(repo) end)
    %{repo: repo, journal: journal}
  end

  test "an existing but unheld journal lock permits a read", %{repo: repo} do
    assert :clear = JournalLock.check(repo)
  end

  test "missing or unreadable lock evidence always defers", %{repo: repo, journal: journal} do
    assert {:defer, :indeterminate} =
             JournalLock.check(repo, locks_path: Path.join(repo, "absent"))

    File.rm!(journal)
    assert {:defer, :indeterminate} = JournalLock.check(repo)
    assert {:defer, :indeterminate} = JournalLock.check(Path.join(repo, "absent"))
    refute File.exists?(journal)
  end

  test "malformed proc evidence defers rather than assuming unlocked", %{repo: repo} do
    proc = Path.join(repo, "proc-locks")
    File.write!(proc, "unrecognized lock format\n")
    assert {:defer, :indeterminate} = JournalLock.check(repo, locks_path: proc)
  end

  test "store symlinks are indeterminate, never followed", %{repo: repo, journal: journal} do
    target = Path.join(repo, "other-lock")
    File.rename!(journal, target)
    File.ln_s!(target, journal)
    assert {:defer, :indeterminate} = JournalLock.check(repo)
  end

  test "every database must have a determinable journal", %{repo: repo} do
    second = Path.join(repo, ".beads/embeddeddolt/second/.dolt/noms")
    File.mkdir_p!(second)
    assert {:defer, :indeterminate} = JournalLock.check(repo)
    File.write!(Path.join(second, "LOCK"), "")
    assert :clear = JournalLock.check(repo)
  end

  test "inode alone does not identify a lock on another device", %{repo: repo, journal: journal} do
    inode = File.stat!(journal).inode
    proc = Path.join(repo, "proc-locks")
    File.write!(proc, "7: FLOCK ADVISORY WRITE 123 0000:0000:#{inode} 0 EOF\n")
    assert :clear = JournalLock.check(repo, locks_path: proc)
  end

  test "a real held journal flock defers until released, without removing the lock file",
       context do
    script = """
    import fcntl, sys
    with open(sys.argv[1], 'rb') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        print('held', flush=True)
        sys.stdin.readline()
    """

    port =
      Port.open(
        {:spawn_executable, System.find_executable("python3")},
        [:binary, :exit_status, args: ["-c", script, context.journal]]
      )

    try do
      assert_receive {^port, {:data, "held\n"}}, 5_000
      assert {:defer, :held} = JournalLock.check(context.repo)
      Port.command(port, "release\n")
      assert_receive {^port, {:exit_status, 0}}, 5_000
      assert :clear = JournalLock.check(context.repo)
      assert File.exists?(context.journal)
    after
      if Port.info(port), do: Port.close(port)
    end
  end
end
