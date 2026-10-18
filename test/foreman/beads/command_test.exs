defmodule Foreman.Beads.CommandTest do
  use ExUnit.Case, async: true
  alias Foreman.Beads.Command

  test "returns complete stdout only after successful exit" do
    assert {:ok, "hello"} = Command.run(System.tmp_dir!(), ["/usr/bin/printf", "hello"])

    assert {:error, :exit} =
             Command.run(System.tmp_dir!(), ["/bin/sh", "-c", "printf partial; exit 2"])
  end

  test "timeout discards partial output and reaps the child" do
    assert {:error, :timeout} =
             Command.run(System.tmp_dir!(), ["/bin/sh", "-c", "printf partial; exec sleep 10"],
               timeout: 50
             )
  end

  test "owner death retains admission until the owned child is reaped" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    identity = "owner-test-#{System.unique_integer([:positive])}"

    script =
      "import socket,os,time; s=socket.create_connection(('127.0.0.1',#{port})); s.sendall(str(os.getpid()).encode()); time.sleep(20)"

    owner =
      start_supervised!(
        {Task,
         fn ->
           Command.run("/", [System.find_executable("python3"), "-c", script], identity: identity)
         end}
      )

    {:ok, socket} = :gen_tcp.accept(listener, 5_000)
    {:ok, pid} = :gen_tcp.recv(socket, 0, 5_000)
    assert {:error, :busy} = Command.run("/", ["/usr/bin/true"], identity: identity)
    ref = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^ref, :process, ^owner, :killed}
    assert :ok = await_admission(identity, System.monotonic_time(:millisecond) + 5_000)
    refute File.exists?("/proc/" <> pid)
    :gen_tcp.close(socket)
    :gen_tcp.close(listener)
  end

  test "timeout reaps descendants of the owned command group" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)

    grandchild =
      "import socket,os,time; s=socket.create_connection(('127.0.0.1',#{port})); s.sendall(str(os.getpid()).encode()); time.sleep(20)"

    script =
      "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',#{inspect(grandchild)}]); time.sleep(20)"

    owner = self()

    start_supervised!(
      {Task,
       fn ->
         send(
           owner,
           {:result,
            Command.run("/", [System.find_executable("python3"), "-c", script], timeout: 800)}
         )
       end}
    )

    {:ok, socket} = :gen_tcp.accept(listener, 5_000)
    {:ok, pid} = :gen_tcp.recv(socket, 0, 5_000)
    assert_receive {:result, {:error, :timeout}}, 5_000
    refute File.exists?("/proc/" <> pid)
    :gen_tcp.close(socket)
    :gen_tcp.close(listener)
  end

  defp await_admission(identity, deadline) do
    case Command.run("/", ["/usr/bin/true"], identity: identity) do
      {:ok, ""} ->
        :ok

      {:error, :busy} ->
        assert System.monotonic_time(:millisecond) < deadline
        await_admission(identity, deadline)
    end
  end

  test "bounds output" do
    assert {:error, :output_limit} =
             Command.run(System.tmp_dir!(), ["/usr/bin/yes"], max_bytes: 100)
  end
end
