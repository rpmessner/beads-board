defmodule Foreman.SessionHooksTest do
  use ExUnit.Case, async: true

  test "question tools stay input waits across the permission hook" do
    input = %{"tool_name" => "AskUserQuestion", "tool_input" => %{"questions" => []}}

    assert {:waiting, %{"reason" => "input"} = facts} =
             Foreman.SessionHooks.facts("PreToolUse", input)

    assert Foreman.SessionHooks.facts("PermissionRequest", input) == {:waiting, facts}
    assert Foreman.SessionHooks.facts("PostToolUse", input) == {:resumed, facts["tool"]}

    answered =
      put_in(input, ["tool_input", "answers"], %{"question" => "Yes"})
      |> put_in(["tool_input", "annotations"], %{})

    assert Foreman.SessionHooks.facts("PostToolUse", answered) == {:resumed, facts["tool"]}
  end

  test "API errors only report actual usage limits" do
    assert {:waiting,
            %{"reason" => "usage_limit", "provider" => "Anthropic", "reset_at" => "14:00"}} =
             Foreman.SessionHooks.facts("StopFailure", %{
               "error" => "rate_limit",
               "last_assistant_message" => "Usage limit reached; resets 14:00"
             })

    assert :activity =
             Foreman.SessionHooks.facts("StopFailure", %{"error" => "authentication_failed"})
  end

  test "CLI waiting facts preserve reason and coordinator target" do
    assert {:ok, %{request: request}} =
             Foreman.CLI.parse([
               "ask",
               "session_waiting",
               "x-1",
               "--session",
               "pi-build",
               "--reason",
               "usage_limit",
               "--window",
               "build",
               "--provider",
               "Codex",
               "--reset-at",
               "14:00"
             ])

    assert request["facts"] == %{
             "reason" => "usage_limit",
             "window" => "build",
             "provider" => "Codex",
             "reset_at" => "14:00"
           }
  end

  test "per-launch settings cover permission, input, turn completion, resumed tools and API errors without blocking Claude" do
    session = %{
      session_id: "7818e0a2-6213-40b3-87a2-39295b499fe0",
      project: "scratch",
      ticket: "x-1"
    }

    settings = Foreman.SessionHooks.settings(session, hook_executable: "/missing/foreman")
    assert Map.has_key?(settings, "hooks")

    for event <-
          ~w(PermissionRequest Stop UserPromptSubmit PreToolUse PostToolUse PostToolUseFailure StopFailure) do
      assert [%{"hooks" => [%{"type" => "command", "command" => command, "timeout" => 4}]} | _] =
               settings["hooks"][event]

      assert command =~ session.session_id
      assert command =~ "'--project' 'scratch'"
      assert {"", 0} = System.cmd("sh", ["-c", command], stderr_to_stdout: true)
    end
  end
end
