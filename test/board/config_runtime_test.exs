defmodule Board.ConfigRuntimeTest do
  use Board.DataCase, async: false
  alias Board.Config.ReloadJob

  setup do
    root =
      Path.join(System.tmp_dir!(), "board-config-runtime-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    previous = Application.get_env(:board, :config_directory)
    Application.put_env(:board, :config_directory, root)
    Application.put_env(:board, :discovery_root, root)

    on_exit(fn ->
      Application.put_env(:board, :config_directory, previous)
      Application.delete_env(:board, :discovery_root)
      File.rm_rf!(root)
    end)

    %{root: root}
  end

  test "lost directory watchers stop through their declared lifecycle" do
    assert {:stopped, [stop: :restart]} = Board.Config.WatchMachine.step(:watching, :lost, %{})
    assert {:stopped, []} = Board.Config.WatchMachine.step(:stopped, :changed, %{})
  end

  test "watcher moves from an existing parent to the newly created config directory", %{
    root: root
  } do
    target = Path.join(root, "new-config")
    Application.put_env(:board, :config_directory, target)
    watcher = start_supervised!({Board.Config.Watcher, []})
    assert :sys.get_state(watcher).directory == root
    File.mkdir_p!(target)
    send(watcher, :reconcile)
    assert :sys.get_state(watcher).directory == target
    assert Repo.exists?(from j in Oban.Job, where: j.worker == "Board.Config.ReloadJob")
  end

  test "discovery includes nested repositories without following symlink aliases", %{root: root} do
    parent = Path.join(root, "parent")
    nested = Path.join(parent, "nested")
    File.mkdir_p!(Path.join(parent, ".beads"))
    File.mkdir_p!(Path.join(nested, ".beads"))
    File.ln_s!(parent, Path.join(root, "alias"))
    assert :ok = ReloadJob.perform(%Oban.Job{})
    assert Board.RuntimeState.config().discovered == [parent, nested]
  end

  test "a bad views edit retains the installed curated views", %{root: root} do
    path = Path.join(root, "board.toml")

    File.write!(
      path,
      "[[views]]\nkey = \"review\"\ntitle = \"Review\"\nstages = [\"in_review\"]\n"
    )

    assert :ok = ReloadJob.perform(%Oban.Job{})
    accepted = Board.RuntimeState.config()

    assert accepted.config["views"] == [
             %{"key" => "review", "title" => "Review", "stages" => ["in_review"]}
           ]

    File.write!(
      path,
      "[[views]]\nkey = \"review\"\ntitle = \"Review\"\nstatuses = [\"invented\"]\n"
    )

    assert :ok = ReloadJob.perform(%Oban.Job{})
    rejected = Board.RuntimeState.config()
    assert rejected.config == accepted.config
    assert rejected.loaded_at == accepted.loaded_at
    assert rejected.error =~ "board.toml: config.views[0].statuses[0]"
  end

  test "persists accepted config for web and retains it after a rejected edit", %{root: root} do
    File.write!(Path.join(root, "board.toml"), "[board]\nswimlanes = \"none\"\n")
    assert :ok = ReloadJob.perform(%Oban.Job{})

    assert %{config: %{"board" => %{"swimlanes" => "none"}}, error: nil} =
             Board.RuntimeState.config()

    File.write!(
      Path.join(root, "board.toml"),
      "[[columns]]\ntitle = \"No\"\nstages = [\"speccing\"]\n"
    )

    assert :ok = ReloadJob.perform(%Oban.Job{})

    assert %{config: %{"board" => %{"swimlanes" => "none"}}, error: error} =
             Board.RuntimeState.config()

    assert error =~ "speccing"
  end
end
