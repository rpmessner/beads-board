defmodule Board.AgentCommitTest do
  use ExUnit.Case, async: false
  alias Board.{AgentCommands, Overlay, Repo, Spool}

  setup do
    repo = "agent-commit-#{System.unique_integer([:positive])}"

    request = %{
      "request_id" => Ecto.UUID.generate(),
      "repo" => repo,
      "id" => "ticket",
      "action" => "event",
      "event" => "dispatch",
      "payload" => %{"window" => "build"}
    }

    unboxed(fn ->
      Overlay.backfill(repo, [%{bead_id: "ticket", issue_type: :task, status: :open}])
    end)

    on_exit(fn ->
      unboxed(fn ->
        Repo.query!(
          "DELETE FROM overlay_effects WHERE event_id IN (SELECT id FROM stage_events WHERE repo_key=$1)",
          [repo]
        )

        for table <- ~w(agent_notes sessions stage_events tickets),
            do: Repo.query!("DELETE FROM #{table} WHERE repo_key=$1", [repo])

        for table <- ~w(agent_receipts spooled_events),
            do:
              Repo.query!("DELETE FROM #{table} WHERE request_id=$1", [
                Ecto.UUID.dump!(request["request_id"])
              ])
      end)
    end)

    %{request: request, repo: repo}
  end

  test "simultaneous HTTP delivery and replay commit only one event and ping its repo", %{
    request: request,
    repo: repo
  } do
    Board.Events.subscribe()
    unboxed(fn -> Spool.enqueue(request) end)
    parent = self()

    for {id, fun} <- [
          {:http, fn -> AgentCommands.execute(request) end},
          {:replay, fn -> Spool.replay() end}
        ] do
      start_supervised!(
        {Task,
         fn ->
           send(parent, {:ready, self()})

           receive do
             :go -> send(parent, {:result, id, unboxed(fun)})
           end
         end},
        id: id
      )
    end

    assert_receive {:ready, a}
    assert_receive {:ready, b}
    send(a, :go)
    send(b, :go)
    assert_receive {:result, :http, {200, _}}, 3000
    assert_receive {:result, :replay, :ok}, 3000

    assert_receive {:notification, :board_events, %{"kind" => "sync_requested", "key" => ^repo}},
                   2000

    unboxed(fn ->
      assert Enum.map(Overlay.history({repo, "ticket"}), & &1.event) == ["backfill", "dispatch"]
    end)
  end

  defp unboxed(fun), do: Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fun)
end
