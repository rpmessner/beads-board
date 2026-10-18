defmodule Board.OverlayCommitTest do
  use ExUnit.Case, async: false
  alias Board.{Overlay, Repo}

  setup do
    repo = "overlay-commit-#{System.unique_integer([:positive])}"
    key = {repo, "ticket"}

    unboxed(fn ->
      Overlay.backfill(repo, [%{bead_id: "ticket", issue_type: :task, status: :open}])
    end)

    on_exit(fn ->
      unboxed(fn ->
        Repo.query!(
          "DELETE FROM overlay_effects WHERE event_id IN (SELECT id FROM stage_events WHERE repo_key=$1)",
          [repo]
        )

        for table <- ~w(agent_notes sessions overlay_cr_links stage_events tickets),
            do: Repo.query!("DELETE FROM #{table} WHERE repo_key=$1", [repo])
      end)
    end)

    %{key: key, wire_key: repo <> "/ticket"}
  end

  test "notifications arrive only with committed facts and rollback sends nothing", %{
    key: key,
    wire_key: wire
  } do
    Board.Events.subscribe()

    unboxed(fn ->
      assert {:error, :abort} =
               Repo.transaction(fn ->
                 assert {:ok, %{stage: :dispatched}} =
                          Overlay.apply_event(key, {:dispatch, %{window: "rolled-back"}})

                 refute_receive {:notification, :board_events, %{"key" => ^wire}}, 50
                 Repo.rollback(:abort)
               end)
    end)

    refute_receive {:notification, :board_events, %{"key" => ^wire}}, 50
    unboxed(fn -> assert %{stage: :queued} = Overlay.get(key) end)
    unboxed(fn -> Overlay.apply_event(key, {:dispatch, %{window: "committed"}}) end)

    assert_receive {:notification, :board_events, %{"kind" => "overlay_changed", "key" => ^wire}},
                   2000

    unboxed(fn -> assert %{stage: :dispatched} = Overlay.get(key) end)
  end

  test "simultaneous identical claims serialize: one applies, one logs invalid", %{key: key} do
    parent = self()

    for n <- 1..2 do
      run = fn ->
        send(parent, {:ready, self()})

        receive do
          :go ->
            unboxed(fn ->
              send(parent, {:result, Overlay.apply_event(key, {:dispatch, %{window: "same"}})})
            end)
        end
      end

      start_supervised!({Task, run}, id: n)
    end

    assert_receive {:ready, a}
    assert_receive {:ready, b}
    send(a, :go)
    send(b, :go)
    assert_receive {:result, first}, 2000
    assert_receive {:result, second}, 2000
    assert Enum.count([first, second], &match?({:ok, _}, &1)) == 1
    assert Enum.count([first, second], &match?({:error, %{stage: :dispatched}}, &1)) == 1
    unboxed(fn -> assert length(Overlay.history(key)) == 3 end)
  end

  defp unboxed(fun), do: Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fun)
end
