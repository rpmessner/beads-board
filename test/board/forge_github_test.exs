defmodule Board.ForgeGitHubTest do
  use ExUnit.Case, async: true
  alias Board.Forge.GitHub

  test "a single read observes a tracked merged PR as well as open PRs" do
    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      query = Jason.decode!(body)["query"]
      assert query =~ "pr3: pullRequest(number:3)"
      refute query =~ "mutation"
      Req.Test.json(conn, fixture("form-engine-tracked.json"))
    end)

    assert {:ok, snapshot} =
             GitHub.list("rpmessner/form-engine",
               token: "test",
               tracked: [3],
               plug: {Req.Test, __MODULE__}
             )

    assert Enum.find(snapshot["change_requests"], &(&1["number"] == 3))["state"] == "merged"
  end

  test "incomplete pagination, missing tracked PRs and GraphQL errors never publish partial data" do
    for response <- [
          put_in(
            fixture("form-engine.json"),
            ["data", "repository", "pullRequests", "pageInfo", "hasNextPage"],
            true
          ),
          %{
            "errors" => [%{"message" => "private upstream details"}],
            "data" => fixture("form-engine.json")["data"]
          }
        ] do
      Req.Test.stub(__MODULE__, &Req.Test.json(&1, response))

      assert {:error, reason} =
               GitHub.list("owner/repo", token: "test", plug: {Req.Test, __MODULE__})

      assert reason in [:incomplete, :graphql]
    end

    Req.Test.stub(__MODULE__, &Req.Test.json(&1, fixture("form-engine.json")))

    assert {:error, :incomplete} =
             GitHub.list("owner/repo", token: "test", tracked: [3], plug: {Req.Test, __MODULE__})
  end

  test "GraphQL rate-limit errors use the same cooldown as HTTP rate limiting" do
    Req.Test.stub(
      __MODULE__,
      &Req.Test.json(&1, %{"errors" => [%{"type" => "RATE_LIMITED", "message" => "limited"}]})
    )

    assert {:error, :rate_limited} =
             GitHub.list("owner/repo", token: "test", plug: {Req.Test, __MODULE__})
  end

  test "malformed CR identity is rejected rather than published" do
    response =
      update_in(fixture("form-engine.json"), ["data", "repository", "pullRequests", "nodes"], fn [
                                                                                                   first
                                                                                                   | rest
                                                                                                 ] ->
        [Map.put(first, "number", nil) | rest]
      end)

    Req.Test.stub(__MODULE__, &Req.Test.json(&1, response))

    assert {:error, :invalid_response} =
             GitHub.list("owner/repo", token: "test", plug: {Req.Test, __MODULE__})
  end

  test "missing credentials fail without making a request" do
    assert {:error, :credentials_or_remote} = GitHub.list("owner/repo", [])
  end

  defp fixture(name), do: File.read!("test/fixtures/forge/" <> name) |> Jason.decode!()
end
