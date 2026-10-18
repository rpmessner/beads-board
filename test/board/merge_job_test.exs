defmodule Board.MergeJobTest do
  use Board.DataCase, async: false
  alias Board.Merge
  alias Board.Merge.{MergeJob, RetargetJob}

  setup do
    Repo.insert_all("board_config", [
      %{
        id: 1,
        config: %{
          "repos" => [
            %{"key" => "sample", "forge" => "github", "github" => "owner/repo", "enabled" => true}
          ]
        },
        source: "test",
        discovered: [],
        loaded_at: DateTime.utc_now()
      }
    ])

    pr = %{
      "number" => 5,
      "title" => "Bottom",
      "source_branch" => "stack",
      "target_branch" => "main",
      "head_sha" => "confirmed",
      "draft" => false,
      "checks" => "none",
      "mergeable" => "mergeable",
      "state" => "open"
    }

    child = %{
      pr
      | "number" => 6,
        "title" => "Child",
        "source_branch" => "child",
        "target_branch" => "stack",
        "head_sha" => "child-sha"
    }

    snapshot = %{"default_branch" => "main", "change_requests" => [pr, child]}
    fake = start_supervised!({Board.Forge.Fake, snapshot})
    %{snapshot: snapshot, fake: fake, pr: pr}
  end

  defp enqueue(snapshot, number \\ 5) do
    {:ok, facts} = Merge.prepare(snapshot, number)
    {:ok, row} = Merge.enqueue("sample", "owner/repo", facts)
    row
  end

  test "durable audit precedes write; merge and retarget do not replay", %{
    snapshot: snapshot,
    fake: fake
  } do
    row = enqueue(snapshot)
    assert row.state == "merging"
    assert row.requested_by == "local_ui"
    assert :ok = MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert %{state: "retargeting", merge_sha: "merge-confirmed"} = Merge.get(row.id)
    assert :ok = MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert :ok = RetargetJob.run(row.id, Board.Forge.Fake, server: fake)
    assert :ok = RetargetJob.run(row.id, Board.Forge.Fake, server: fake)
    assert %{state: "merged"} = Merge.get(row.id)
    {:ok, actual} = Board.Forge.Fake.list("owner/repo", server: fake)
    assert Enum.find(actual["change_requests"], &(&1["number"] == 6))["target_branch"] == "main"
    assert {:ok, again} = Merge.enqueue("sample", "owner/repo", row.facts)
    assert again.id == row.id
  end

  test "the job refuses a top PR even when enqueued without the UI guard", %{
    snapshot: snapshot,
    fake: fake
  } do
    facts = %{
      "pr" => List.last(snapshot["change_requests"]),
      "child" => nil,
      "default_branch" => "main"
    }

    {:ok, row} = Merge.enqueue("sample", "owner/repo", facts)
    MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert %{state: "failed", error: "not_bottom", merge_sha: nil} = Merge.get(row.id)
  end

  test "a leaf completes without retarget; disabled writes never reach the forge", %{
    snapshot: snapshot,
    fake: fake
  } do
    row = enqueue(snapshot)
    MergeJob.run(row.id, Board.Test.ReadOnlyForge, [])
    assert %{state: "failed", error: "read_only"} = Merge.get(row.id)
    Repo.delete_all("merge_actions")
    leaf = %{snapshot | "change_requests" => [hd(snapshot["change_requests"])]}
    Agent.update(fake, fn _ -> leaf end)
    row = enqueue(leaf)
    MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert %{state: "merged", error: nil, merge_sha: "merge-confirmed"} = Merge.get(row.id)
    refute Repo.exists?(from j in Oban.Job, where: j.worker == "Board.Merge.RetargetJob")
  end

  test "job re-reads and refuses a moved head", %{snapshot: snapshot, fake: fake} do
    row = enqueue(snapshot)

    Agent.update(fake, fn s ->
      put_in(s, ["change_requests", Access.at(0), "head_sha"], "moved")
    end)

    assert :ok = MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert %{state: "failed", error: "head_moved", merge_sha: nil} = Merge.get(row.id)
  end

  test "all safety rules are enforced by the job, not cached UI", %{
    snapshot: snapshot,
    fake: fake
  } do
    for {field, value, reason} <- [
          {"draft", true, "draft"},
          {"checks", "pending", "checks"},
          {"mergeable", "unknown", "not_mergeable"},
          {"target_branch", "detached", "not_bottom"},
          {"state", "closed", "not_open"}
        ] do
      Repo.delete_all("merge_actions")
      row = enqueue(snapshot)

      Agent.update(fake, fn _ ->
        put_in(snapshot, ["change_requests", Access.at(0), field], value)
      end)

      assert :ok = MergeJob.run(row.id, Board.Forge.Fake, server: fake)
      assert %{state: "failed", error: ^reason, merge_sha: nil} = Merge.get(row.id)
    end

    assert {:error, :not_bottom} = Merge.prepare(snapshot, 6)
  end

  test "weaker capability re-reads immediately; absent retarget records a manual step", %{
    snapshot: snapshot,
    fake: fake
  } do
    row = enqueue(snapshot)
    MergeJob.run(row.id, Board.Test.WeakForge, server: fake, observer: self())
    assert_receive :read
    assert_receive :read
    assert_receive :merge

    assert %{state: "merged", error: "manual_retarget", merge_sha: "merge-confirmed"} =
             Merge.get(row.id)

    refute Repo.exists?(from j in Oban.Job, where: j.worker == "Board.Merge.RetargetJob")
  end

  test "ambiguous result is not automatically retried", %{snapshot: snapshot, fake: fake} do
    row = enqueue(snapshot)
    MergeJob.run(row.id, Board.Test.AmbiguousForge, server: fake, observer: self())
    assert_receive :merge
    assert %{state: "failed", error: "outcome_unknown"} = Merge.get(row.id)
    MergeJob.run(row.id, Board.Test.AmbiguousForge, server: fake, observer: self())
    refute_received :merge
  end

  test "cancelled or timed-out job reconciles durable action without replay", %{
    snapshot: snapshot
  } do
    row = enqueue(snapshot)

    Repo.update_all(from(j in Oban.Job, where: j.worker == "Board.Merge.MergeJob"),
      set: [state: "discarded"]
    )

    assert %{state: "failed", error: "outcome_unknown"} = Merge.reconcile(row)
  end

  test "a dead worker's claimed action times out even if Oban never updates or prunes its job", %{
    snapshot: snapshot
  } do
    row = enqueue(snapshot)
    Merge.claim(row.id, :merge)
    old = DateTime.add(DateTime.utc_now(), -121)
    Repo.update_all(Board.Merge.Record, set: [claimed_at: old])
    Repo.delete_all(Oban.Job)
    assert %{state: "failed", error: "outcome_unknown"} = Merge.reconcile(Merge.get(row.id))
  end

  test "losing an audit transition cannot enqueue a retarget", %{snapshot: snapshot} do
    row = enqueue(snapshot)
    Merge.advance(row, :job_timeout, Board.Forge.Fake.capabilities(), error: "outcome_unknown")
    Merge.advance(row, :merge_ok, Board.Forge.Fake.capabilities(), merge_sha: "late")
    refute Repo.exists?(from j in Oban.Job, where: j.worker == "Board.Merge.RetargetJob")
  end

  test "configuration and confirmed child changes block the write", %{
    snapshot: snapshot,
    fake: fake
  } do
    row = enqueue(snapshot)

    Agent.update(fake, fn s ->
      put_in(s, ["change_requests", Access.at(1), "target_branch"], "main")
    end)

    MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert %{state: "failed", error: "stack_changed"} = Merge.get(row.id)
    Repo.delete_all("merge_actions")
    row = enqueue(snapshot)
    Repo.update_all("board_config", set: [config: %{"repos" => []}])
    MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert %{state: "failed", error: "config_changed"} = Merge.get(row.id)
  end

  test "retarget refuses a child whose base has been moved elsewhere", %{
    snapshot: snapshot,
    fake: fake
  } do
    row = enqueue(snapshot)
    MergeJob.run(row.id, Board.Forge.Fake, server: fake)

    Agent.update(fake, fn s ->
      put_in(s, ["change_requests", Access.at(1), "target_branch"], "elsewhere")
    end)

    RetargetJob.run(row.id, Board.Forge.Fake, server: fake)

    assert %{state: "failed", error: "child_changed", merge_sha: "merge-confirmed"} =
             Merge.get(row.id)
  end

  test "partial failure retains merge evidence and never remerges", %{
    snapshot: snapshot,
    fake: fake
  } do
    row = enqueue(snapshot)
    MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    Agent.update(fake, &Map.put(&1, "retarget_error", true))
    RetargetJob.run(row.id, Board.Forge.Fake, server: fake)

    assert %{state: "failed", merge_sha: "merge-confirmed", error: "unavailable"} =
             Merge.get(row.id)

    MergeJob.run(row.id, Board.Forge.Fake, server: fake)
    assert Merge.get(row.id).merge_sha == "merge-confirmed"
  end
end
