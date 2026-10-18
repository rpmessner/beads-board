defmodule Foreman.RequestCommitTest do
  use ExUnit.Case, async: false
  alias Foreman.{Overlay, Repo, Requests}

  setup do
    repo = "request-race-#{System.unique_integer([:positive])}"
    key = {repo, "ticket"}

    on_exit(fn ->
      unboxed(fn ->
        Repo.query!(
          "DELETE FROM request_events WHERE request_id IN (SELECT id FROM approval_requests WHERE repo_key=$1)",
          [repo]
        )

        Repo.query!(
          "DELETE FROM overlay_effects WHERE event_id IN (SELECT id FROM stage_events WHERE repo_key=$1)",
          [repo]
        )

        for table <- ~w(approval_requests agent_notes sessions stage_events tickets),
            do: Repo.query!("DELETE FROM #{table} WHERE repo_key=$1", [repo])
      end)
    end)

    unboxed(fn ->
      Overlay.backfill(repo, [%{bead_id: "ticket", issue_type: :task, status: :open}])
    end)

    %{key: key}
  end

  test "concurrent answer and decline commit exactly one outcome", %{key: key} do
    {:ok, request} =
      unboxed(fn -> Requests.ask(key, "decision", %{"facts" => %{"question" => "Which?"}}) end)

    results =
      race([
        fn -> Requests.resolve(request.id, :answer, %{"answer" => "A"}) end,
        fn -> Requests.resolve(request.id, :decline, %{"note" => "No"}) end
      ])

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, :invalid}, &1)) == 1

    unboxed(fn ->
      assert Requests.get(request.id).state in ["answered", "declined"]

      assert %{rows: [[2]]} =
               Repo.query!("SELECT count(*) FROM request_events WHERE request_id=$1", [
                 Ecto.UUID.dump!(request.id)
               ])
    end)
  end

  test "ask racing ticket completion cannot leave a pending request", %{key: key} do
    race([
      fn -> Requests.ask(key, "decision", %{"facts" => %{"question" => "Which?"}}) end,
      fn -> Overlay.apply_event(key, :bead_closed) end
    ])

    unboxed(fn ->
      assert Overlay.get(key).stage == :done
      assert Enum.all?(Requests.for_ticket(key), &(&1.state == "superseded"))
    end)
  end

  defp race(funs) do
    parent = self()

    for {fun, index} <- Enum.with_index(funs) do
      start_supervised!(
        {Task,
         fn ->
           send(parent, {:ready, self()})

           receive do
             :go -> send(parent, {:result, unboxed(fun)})
           end
         end},
        id: index
      )
    end

    pids =
      for _ <- funs do
        assert_receive {:ready, pid}
        pid
      end

    Enum.each(pids, &send(&1, :go))

    for _ <- funs do
      assert_receive {:result, result}, 3_000
      result
    end
  end

  defp unboxed(fun), do: Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fun)
end
