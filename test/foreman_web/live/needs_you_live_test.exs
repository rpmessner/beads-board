defmodule ForemanWeb.NeedsYouLiveTest do
  use ForemanWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Foreman.Requests

  setup do
    Foreman.Beads.Projection.replace(
      "sample",
      Jason.encode!(%{id: "s-1", title: "A ticket", issue_type: "task", status: "open"})
    )

    {:ok, request} =
      Requests.ask({"sample", "s-1"}, "decision", %{
        "actor" => "pi",
        "session" => "build",
        "facts" => %{
          "question" => "Which layout?",
          "options" => ["Wide", "Compact"],
          "recommendation" => "Compact"
        }
      })

    %{request: request}
  end

  test "answer records free text and updates live count in two tabs", %{
    conn: conn,
    request: request
  } do
    {:ok, view, _} = live(conn, "/needs-you")
    {:ok, other, _} = live(conn, "/")
    assert has_element?(view, "#pending-requests #request-#{request.id}")
    assert has_element?(view, "#request-#{request.id} [data-recommended=true]")
    assert has_element?(other, "#needs-you-count", "1")

    view
    |> form("#decision-#{request.id}", decision: %{note: "A different layout"})
    |> render_submit(%{"action" => "answer"})

    assert Requests.get(request.id).outcome == %{"answer" => "A different layout"}
    refute has_element?(view, "#recent-requests p.text-foreground-softer", "A different layout")
    refute has_element?(view, "#pending-requests #request-#{request.id}")
    send(other.pid, {:notification, :foreman_events, %{"kind" => "requests_changed"}})
    refute has_element?(other, "#needs-you-count")
    assert page_title(view) == "foreman"
  end

  test "decline note reaches the stored outcome and never creates a job", %{
    conn: conn,
    request: request
  } do
    {:ok, view, _} = live(conn, "/needs-you")
    assert page_title(view) == "(1) foreman"

    view
    |> form("#decision-#{request.id}", decision: %{note: "Not now"})
    |> render_submit(%{"action" => "decline"})

    assert %{state: "declined", note: "Not now"} = Requests.get(request.id)
    assert has_element?(view, "#recent-outcomes:not([open])")
    assert Foreman.Repo.aggregate(Oban.Job, :count) == 0
  end

  test "one Note field supplies both actions and an option answer retains its note", %{
    conn: conn,
    request: request
  } do
    {:ok, view, _} = live(conn, "/needs-you")
    assert has_element?(view, "#decision-#{request.id} textarea[name='decision[note]']")
    refute has_element?(view, "#request-#{request.id} input[type=text]")
    refute has_element?(view, "#request-#{request.id} textarea[name='decision[answer]']")
    assert has_element?(view, "#decision-actions-#{request.id} #submit-answer-#{request.id}")
    assert has_element?(view, "#decision-actions-#{request.id} #submit-decline-#{request.id}")

    view
    |> form("#decision-#{request.id}", decision: %{choice: "Compact", note: "Keep the shortcuts"})
    |> render_submit(%{"action" => "answer"})

    assert %{state: "answered", outcome: %{"answer" => "Compact"}, note: "Keep the shortcuts"} =
             Requests.get(request.id)
  end

  test "ticket Requests tab lists only that ticket's asks", %{conn: conn, request: request} do
    {:ok, view, _} = live(conn, "/?ticket=sample:s-1&tab=requests")
    assert has_element?(view, "#ticket-requests-tab[aria-selected=true]")
    assert has_element?(view, "#ticket-requests #ticket_requests-#{request.id}")
  end
end
