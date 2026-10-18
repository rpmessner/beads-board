defmodule BoardWeb.AgentControllerTest do
  use BoardWeb.ConnCase, async: false
  alias Board.Overlay

  setup do
    path = Path.join(System.tmp_dir!(), "board-token-#{System.unique_integer([:positive])}")
    File.write!(path, "test-only-token-long\n")
    old = Application.get_env(:board, :token_file)
    Application.put_env(:board, :token_file, path)

    on_exit(fn ->
      File.rm!(path)

      if old,
        do: Application.put_env(:board, :token_file, old),
        else: Application.delete_env(:board, :token_file)
    end)

    Overlay.backfill("sample", [%{bead_id: "s-1", status: "open", issue_type: "task"}])
    :ok
  end

  test "claims return effects, reject observed events, and audit out-of-order claims", %{
    conn: conn
  } do
    conn = put_req_header(conn, "authorization", "Bearer test-only-token-long")
    path = "/api/tickets/sample/s-1/events"

    assert %{"stage" => "queued", "allowed" => allowed} =
             conn |> post(path, %{event: "review"}) |> json_response(409)

    assert "dispatch" in allowed
    assert List.last(Overlay.history({"sample", "s-1"})).outcome == "invalid"

    for event <- ~w(bead_closed cr_opened cr_merged bead_epic_closed unknown) do
      assert conn |> post(path, %{event: event}) |> json_response(422) == %{
               "error" => "claimed_events_only"
             }
    end

    assert %{
             "stage" => "dispatched",
             "effects" => [
               %{"kind" => "record", "name" => "session"},
               %{"kind" => "emit", "name" => "stage"}
             ]
           } =
             conn
             |> post(path, %{event: "dispatch", payload: %{window: "build"}, actor: "pi"})
             |> json_response(200)

    for {event, stage} <- [
          {"progress", "building"},
          {"report", "reported"},
          {"review", "in_review"},
          {"request_changes", "building"},
          {"report", "reported"},
          {"review", "in_review"},
          {"commit", "committed"},
          {"commit", "committed"},
          {"abandon", "abandoned"},
          {"revive", "queued"}
        ] do
      assert %{"stage" => ^stage} =
               conn |> post(path, %{event: event, payload: %{body: "note"}}) |> json_response(200)
    end
  end

  test "missing or empty token file fails closed", %{conn: conn} do
    File.write!(Application.fetch_env!(:board, :token_file), "")

    assert conn
           |> put_req_header("authorization", "Bearer ")
           |> get("/api/repos")
           |> json_response(401) == %{"error" => "unauthorized"}

    Application.put_env(:board, :token_file, "/missing-token")
    assert conn |> get("/api/repos") |> json_response(401) == %{"error" => "unauthorized"}
  end

  test "unknown entity returns 404 after one forced sync, or applies a newly found ticket", %{
    conn: conn
  } do
    parent = self()

    Application.put_env(:board, :agent_sync, fn repo ->
      send(parent, {:sync, repo})
      Overlay.backfill(repo, [%{bead_id: "s-found", status: "open", issue_type: "task"}])
    end)

    on_exit(fn -> Application.delete_env(:board, :agent_sync) end)
    conn = put_req_header(conn, "authorization", "Bearer test-only-token-long")

    assert conn
           |> post("/api/tickets/sample/s-absent/events", %{event: "review"})
           |> json_response(404) == %{"error" => "not_found"}

    assert_received {:sync, "sample"}
    refute_received {:sync, _}

    assert %{"stage" => "dispatched"} =
             conn
             |> post("/api/tickets/sample/s-found/events", %{event: "dispatch", session: "fresh"})
             |> json_response(200)

    refute_received {:sync, _}
  end

  test "all API reads and writes refuse missing or wrong bearer credentials", %{conn: conn} do
    assert conn |> get("/api/tickets/sample/s-1") |> json_response(401) == %{
             "error" => "unauthorized"
           }

    assert conn
           |> put_req_header("authorization", "Bearer wrong")
           |> post("/api/tickets/sample/s-1/events", %{event: "review"})
           |> json_response(401) == %{"error" => "unauthorized"}
  end
end
