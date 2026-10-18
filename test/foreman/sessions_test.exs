defmodule Foreman.SessionsTest do
  use Foreman.DataCase, async: false
  alias Foreman.Sessions

  setup do
    socket = "fm-sessions-#{System.unique_integer([:positive])}"
    dir = Path.join(System.tmp_dir!(), socket)
    File.mkdir_p!(dir)

    {_, 0} =
      System.cmd("tmux", [
        "-L",
        socket,
        "-f",
        "/dev/null",
        "start-server",
        ";",
        "set-option",
        "-g",
        "exit-empty",
        "off"
      ])

    System.cmd("git", ["init", "-q", dir])

    {:ok, config} =
      Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

    config = Map.put(config, "repos", [%{"key" => "sample", "path" => dir, "enabled" => true}])

    Foreman.Repo.insert_all("board_config", [
      %{id: 1, config: config, source: "test", discovered: [], loaded_at: DateTime.utc_now()}
    ])

    rows = [
      %{id: "x-1", title: "Unplanned", issue_type: "task", status: "open"},
      %{id: "x-2", title: "Epic", issue_type: "epic", status: "open"},
      %{
        id: "x-3",
        title: "Child",
        issue_type: "bug",
        status: "open",
        dependencies: [%{depends_on_id: "x-2", type: "parent-child"}]
      }
    ]

    Foreman.Beads.Projection.replace("sample", Enum.map_join(rows, "\n", &Jason.encode!/1))

    on_exit(fn ->
      System.cmd("tmux", ["-L", socket, "kill-server"], stderr_to_stdout: true)
      File.rm_rf!(dir)
    end)

    %{socket: socket, dir: dir, opts: [socket: socket, executable: "/bin/true"]}
  end

  test "persists launch identity and reuses its window", c do
    assert {:ok, session} = Sessions.launch({"sample", "x-1"}, c.opts)
    assert session.workdir == c.dir
    assert {:ok, _} = Ecto.UUID.cast(session.session_id)
    assert session.state in [:starting, :running, :ended]
    assert {:ok, again} = Sessions.launch({"sample", "x-1"}, c.opts)
    assert again.session_id == session.session_id
    assert again.window == session.window
    assert Sessions.get({"sample", "x-1"}).session_id == session.session_id
    assert {:error, :not_launchable} = Sessions.launch({"sample", "x-3"}, c.opts)
  end

  test "recovers a window created before the launch response was persisted", c do
    reserved =
      Foreman.Repo.insert!(%Foreman.PlanningSession{
        project: "sample",
        ticket: "x-1",
        state: :starting,
        workdir: c.dir,
        launched_at: DateTime.utc_now()
      })

    assert {:ok, window} = Foreman.SessionTmux.launch(reserved, "flow", c.opts)
    assert {:ok, recovered} = Sessions.launch({"sample", "x-1"}, c.opts)
    assert recovered.session_id == reserved.session_id
    assert recovered.window == window
    System.cmd("tmux", ["-L", c.socket, "kill-window", "-t", window])
    assert :ok = Sessions.reconcile(c.opts)
    assert Sessions.get({"sample", "x-1"}).state == :parked
  end

  test "a manually closed window parks the existing conversation instead of launching another",
       c do
    assert {:ok, session} = Sessions.launch({"sample", "x-1"}, c.opts)
    System.cmd("tmux", ["-L", c.socket, "kill-window", "-t", session.window])
    assert {:error, :session_parked} = Sessions.launch({"sample", "x-1"}, c.opts)
    assert Sessions.get({"sample", "x-1"}).state == :parked
  end

  test "an unresolved parent is not an unplanned ticket" do
    raw = %{
      id: "x-4",
      title: "Missing parent",
      issue_type: "task",
      status: "open",
      dependencies: [%{depends_on_id: "missing", type: "parent-child"}]
    }

    Foreman.Beads.Projection.replace("sample", Jason.encode!(raw))
    refute Sessions.launchable?(Sessions.target({"sample", "x-4"}))
  end

  test "a failed tmux launch retains a retryable identity", c do
    bad = Keyword.put(c.opts, :socket, "missing/path")
    assert {:error, _} = Sessions.launch({"sample", "x-1"}, bad)
    reserved = Sessions.get({"sample", "x-1"})
    assert reserved.state == :starting
    assert reserved.error != nil
    assert {:ok, session} = Sessions.launch({"sample", "x-1"}, c.opts)
    assert session.session_id == reserved.session_id
    assert session.error == nil
  end

  test "preview refuses before recording or contacting tmux", c do
    previous = System.get_env("PREVIEW")
    System.put_env("PREVIEW", "1")

    on_exit(fn ->
      if previous, do: System.put_env("PREVIEW", previous), else: System.delete_env("PREVIEW")
    end)

    assert Sessions.launch({"sample", "x-1"}, c.opts) == {:error, "refused in preview"}
    assert Sessions.get({"sample", "x-1"}) == nil
    assert {"", 0} = System.cmd("tmux", ["-L", c.socket, "list-sessions"], stderr_to_stdout: true)
  end

  test "only unplanned tickets and idea/draft epics can launch" do
    assert Sessions.launchable?(%{type: "task", status: "open", parent: nil})
    assert Sessions.launchable?(%{type: "decision", status: "open", parent: nil})
    assert Sessions.launchable?(%{type: "chore", status: "open", parent: nil})
    assert Sessions.launchable?(%{type: "bug", status: "open", parent: nil})
    assert Sessions.launchable?(%{type: "feature", status: "open", parent: nil})
    refute Sessions.launchable?(%{type: "task", status: "open", parent: "epic"})
    refute Sessions.launchable?(%{type: "task", status: "closed", parent: nil})
    for stage <- [:idea, :draft], do: assert(Sessions.launchable?(%{type: "epic", stage: stage}))

    for stage <- [:speccing, :spec_approved, :ticketed, :done, :abandoned],
        do: refute(Sessions.launchable?(%{type: "epic", stage: stage}))

    refute Sessions.launchable?(nil)
  end
end
