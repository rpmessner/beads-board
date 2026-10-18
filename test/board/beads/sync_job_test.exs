defmodule Board.Beads.SyncJobTest do
  use Board.DataCase, async: false
  alias Board.Beads.{Projection, Store, SyncJob}

  setup do
    root = Path.join(System.tmp_dir!(), "board-sync-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, ".beads/embeddeddolt/test/.dolt/noms"))
    File.write!(Path.join(root, ".beads/metadata.json"), ~s({"dolt_mode":"embedded"}))
    File.write!(Path.join(root, ".beads/embeddeddolt/test/.dolt/noms/LOCK"), "")
    File.write!(Path.join(root, "export.jsonl"), File.read!("test/fixtures/beads/export.jsonl"))
    File.write!(Path.join(root, "bd"), "#!/bin/sh\nexec /bin/cat export.jsonl\n")
    File.chmod!(Path.join(root, "bd"), 0o755)
    path = System.get_env("PATH")
    System.put_env("PATH", root <> ":" <> path)

    on_exit(fn ->
      System.put_env("PATH", path)
      File.rm_rf!(root)
    end)

    repo = %{"key" => "sync", "path" => root, "enabled" => true}

    Repo.insert_all("board_config", [
      %{id: 1, config: %{"repos" => [repo]}, source: root, loaded_at: DateTime.utc_now()}
    ])

    %{root: root, repo: repo}
  end

  test "executes one complete export and hash skips repeated bytes", %{repo: repo} do
    assert {:ok, :changed} = SyncJob.sync(repo)
    assert length(Projection.list_raw("sync")) == 2
    assert {:ok, :unchanged} = SyncJob.sync(repo)
  end

  test "bad export retains the previous projection", %{root: root, repo: repo} do
    assert {:ok, :changed} = SyncJob.sync(repo)
    File.write!(Path.join(root, "export.jsonl"), "{")
    assert {:error, {:invalid_export, 1}} = SyncJob.sync(repo)
    assert length(Projection.list_raw("sync")) == 2
  end

  test "physical aliases share identity; server mode never exports", %{root: root, repo: repo} do
    link = root <> "-alias"
    File.ln_s!(root, link)
    on_exit(fn -> File.rm!(link) end)
    assert {:ok, physical, identity} = Store.resolve(root)
    assert {:ok, ^physical, ^identity} = Store.resolve(link)
    File.write!(Path.join(root, ".beads/metadata.json"), ~s({"dolt_mode":"server"}))
    assert {:error, :server_mode} = SyncJob.sync(repo)
    assert Projection.list_raw("sync") == []
  end

  test "server mode in project config cannot bypass embedded metadata", %{root: root, repo: repo} do
    File.write!(Path.join(root, ".beads/config.yaml"), "dolt.mode: server\n")
    assert {:error, :server_mode} = SyncJob.sync(repo)
    assert Projection.list_raw("sync") == []
    File.write!(Path.join(root, ".beads/config.yaml"), "dolt.mode: embedded # explicit\n")
    assert {:ok, :changed} = SyncJob.sync(repo)
  end

  test "one physical export updates every configured alias", %{root: root, repo: repo} do
    link = root <> "-projection-alias"
    File.ln_s!(root, link)
    on_exit(fn -> File.rm!(link) end)
    alias_repo = %{repo | "key" => "alias", "path" => link}
    Repo.update_all("board_config", set: [config: %{"repos" => [repo, alias_repo]}])

    File.write!(
      Path.join(root, "bd"),
      "#!/bin/sh\nprintf x >> calls\nexec /bin/cat export.jsonl\n"
    )

    assert {:ok, :changed} = SyncJob.sync(repo, [repo, alias_repo])
    assert File.read!(Path.join(root, "calls")) == "x"
    assert length(Projection.list_raw("sync")) == 2
    assert length(Projection.list_raw("alias")) == 2
  end

  test "runtime coalesces physical aliases into one Oban job", %{repo: repo} do
    alias_repo = %{repo | "key" => "alias"}
    stores = Map.new(["sync", "alias"], &{&1, %{"identity" => "same-store"}})

    Repo.update_all("board_config",
      set: [config: %{"repos" => [repo, alias_repo]}, stores: stores]
    )

    runtime = start_supervised!({Board.Runtime, []})
    _ = :sys.get_state(runtime)
    send(runtime, :tick)
    _ = :sys.get_state(runtime)
    jobs = Repo.all(from j in Oban.Job, where: j.worker == "Board.Beads.SyncJob")
    assert [%{args: %{"store" => "same-store"}}] = jobs
  end

  test "a removed configuration cannot receive a late export", %{repo: repo} do
    Repo.delete_all("board_config")
    assert {:error, :config_changed} = SyncJob.sync(repo)
    assert Projection.list_raw("sync") == []
  end

  test "health recovers on unchanged output without repeated writes" do
    Board.RuntimeState.record("sync", {:defer, :held})
    Board.RuntimeState.record("sync", {:ok, :unchanged})
    assert "synced" == Repo.one(from s in "repo_sync", where: s.key == "sync", select: s.state)
    before = Repo.one(from s in "repo_sync", where: s.key == "sync", select: s.checked_at)
    Board.RuntimeState.record("sync", {:ok, :unchanged})
    assert before == Repo.one(from s in "repo_sync", where: s.key == "sync", select: s.checked_at)
  end
end
