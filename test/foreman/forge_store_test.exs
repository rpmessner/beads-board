defmodule Foreman.Forge.StoreTest do
  use Foreman.DataCase, async: false
  alias Foreman.{Overlay, Forge.Store}

  setup do
    Overlay.backfill("sample", [%{bead_id: "fe-1", status: "open", issue_type: "task"}])
    :ok
  end

  test "observed opening, last closing and merging drive the ticket stage idempotently" do
    Store.replace("sample", "owner/repo", snapshot([pr(5, "open")]))
    assert %{stage: :pr_open} = Overlay.get({"sample", "fe-1"})
    before = Overlay.history({"sample", "fe-1"})
    Store.replace("sample", "owner/repo", snapshot([pr(5, "open")]))
    assert Overlay.history({"sample", "fe-1"}) == before
    Store.replace("sample", "owner/repo", snapshot([pr(5, "closed")]))
    assert %{stage: :committed} = Overlay.get({"sample", "fe-1"})
    Store.replace("sample", "owner/repo", snapshot([pr(5, "open")]))
    Store.replace("sample", "owner/repo", snapshot([pr(5, "merged")]))
    assert %{stage: :merged} = Overlay.get({"sample", "fe-1"})
    assert Repo.all(from c in "overlay_cr_links", select: c.number) == []
    assert List.last(Overlay.history({"sample", "fe-1"})).event == "cr_merged"
  end

  test "references must resolve to actual repository tickets" do
    request = Map.put(pr(5, "open"), "body", "See docs/sessions/fe-sched.md")
    Store.replace("sample", "owner/repo", snapshot([request]))

    assert [%{"bead_id" => "fe-1", "source" => "title"}] =
             hd(Store.get("sample").snapshot["change_requests"])["links"]
  end

  test "remote replacement drops obsolete open-link guard entries" do
    Store.replace("sample", "owner/old", snapshot([pr(5, "open")]))
    Store.replace("sample", "owner/new", snapshot([pr(6, "open")]))
    Store.replace("sample", "owner/new", snapshot([pr(6, "closed")]))
    assert %{stage: :committed} = Overlay.get({"sample", "fe-1"})
  end

  test "terminal observations remain linked after later open-only snapshots" do
    Store.replace("sample", "owner/repo", snapshot([pr(5, "open")]))
    Store.replace("sample", "owner/repo", snapshot([pr(5, "merged")]))
    Store.replace("sample", "owner/repo", snapshot([]))
    assert [%{"number" => 5, "state" => "merged"}] = Store.linked({"sample", "fe-1"})
  end

  test "a second open CR prevents closing from moving a ticket back" do
    Store.replace("sample", "owner/repo", snapshot([pr(5, "open"), pr(6, "open")]))
    Store.replace("sample", "owner/repo", snapshot([pr(5, "closed"), pr(6, "open")]))
    assert %{stage: :pr_open} = Overlay.get({"sample", "fe-1"})
  end

  defp snapshot(prs), do: %{"default_branch" => "main", "change_requests" => prs}

  defp pr(number, state),
    do: %{
      "number" => number,
      "state" => state,
      "title" => "Fix fe-1",
      "source_branch" => "feature",
      "body" => ""
    }
end
