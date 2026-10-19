defmodule Foreman.CoordinatorCLITest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Foreman.CoordinatorCLI

  test "invalid arguments print a plain instruction and exit nonzero" do
    assert capture_io(:stderr, fn -> assert CoordinatorCLI.run(["--bad"]) == 1 end) ==
             "Coordinator not launched: use foreman coordinator [--fresh | --adopt <uuid>].\n"
  end

  test "missing tmux and unavailable service are readable nonzero refusals" do
    old = System.get_env("TMUX")
    System.delete_env("TMUX")
    on_exit(fn -> if old, do: System.put_env("TMUX", old) end)

    assert capture_io(:stderr, fn -> assert CoordinatorCLI.run([]) == 1 end) ==
             "Coordinator not launched: run this command inside tmux.\n"

    assert capture_io(:stderr, fn ->
             assert CoordinatorCLI.run(["--adopt", "1edc88cf-b665-4ce3-adc4-f1bd434c64f2"],
                      url: "https://invalid"
                    ) == 1
           end) ==
             "Coordinator not launched: foreman is unavailable; check the service and CLI authentication.\n"
  end

  test "server refusals print sentences rather than inspected transport tuples" do
    token = Path.expand("tmp/coordinator-cli-token")
    File.mkdir_p!(Path.dirname(token))
    File.write!(token, "test-only-token-long")
    old = Application.get_env(:foreman, :token_file)
    Application.put_env(:foreman, :token_file, token)

    on_exit(fn ->
      File.rm!(token)

      if old,
        do: Application.put_env(:foreman, :token_file, old),
        else: Application.delete_env(:foreman, :token_file)
    end)

    for {reason, message} <- [
          {"claude_unavailable", "claude is not on the foreman service PATH"},
          {"invalid_coordinator_pane",
           "run this command in the coordinator pane on the foreman tmux server"},
          {"coordinator_active",
           "the coordinator is still running; stop it before replacing its conversation"},
          {"session_id_in_use", "that conversation belongs to another session"},
          {"invalid_session_id", "the conversation ID must be a UUID"},
          {"invalid_coordinator_mode", "use foreman coordinator [--fresh | --adopt <uuid>]"},
          {"invalid_launch_target", "the coordinator working directory is unavailable"},
          {"tmux_unavailable", "the foreman tmux server is unavailable"},
          {"refused in preview", "this command is unavailable in a preview"},
          {"unknown_future_error", "foreman refused the coordinator request"}
        ] do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(Plug.Conn.put_status(conn, 422), %{error: reason})
      end)

      opts = [req_options: [plug: {Req.Test, __MODULE__}]]

      assert capture_io(:stderr, fn ->
               assert CoordinatorCLI.run(
                        ["--adopt", "1edc88cf-b665-4ce3-adc4-f1bd434c64f2"],
                        opts
                      ) == 1
             end) == "Coordinator not launched: #{message}.\n"
    end
  end

  test "argv chooses resume by default, fresh explicitly, or adoption without launch" do
    assert CoordinatorCLI.parse([]) == {:ok, :resume}
    assert CoordinatorCLI.parse(["--fresh"]) == {:ok, :fresh}
    id = "1edc88cf-b665-4ce3-adc4-f1bd434c64f2"
    assert CoordinatorCLI.parse(["--adopt", id]) == {:ok, {:adopt, id}}

    for args <- [["--fresh", "--adopt", id], ["--adopt", "bad"], ["extra"], ["--unknown"]] do
      assert CoordinatorCLI.parse(args) == {:error, :usage}
    end
  end
end
