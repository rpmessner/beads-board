defmodule Foreman.ForgeContractTest do
  use ExUnit.Case, async: true

  for adapter <- [Foreman.Forge.Fake, Foreman.Forge.GitHub] do
    describe inspect(adapter) do
      @adapter adapter
      test "lists the recorded real stack through the forge contract" do
        snapshot = %{
          "default_branch" => "main",
          "change_requests" => [
            %{
              "number" => 5,
              "title" => "Output-clock scheduler for replay (fe-813.3, fixes fe-lwp.15)",
              "source_branch" => "pr/scheduler",
              "target_branch" => "main",
              "head_sha" => "357a083981c80b83c45c7722b7c3c67e39c108b4",
              "draft" => false,
              "checks" => "none",
              "mergeable" => "unknown",
              "url" => "https://github.com/rpmessner/form-engine/pull/5",
              "state" => "open"
            },
            %{
              "number" => 6,
              "title" =>
                "Time model: meter beat groups, subdivisions, loop cycles; group accents (fe-813.2)",
              "source_branch" => "pr/time-model",
              "target_branch" => "pr/scheduler",
              "head_sha" => "62c242d53fdb2228d76f8eabe9ca9d72677b6d26",
              "draft" => false,
              "checks" => "none",
              "mergeable" => "mergeable",
              "url" => "https://github.com/rpmessner/form-engine/pull/6",
              "state" => "open"
            }
          ]
        }

        fake = start_supervised!({Foreman.Forge.Fake, snapshot})

        Req.Test.stub(__MODULE__, fn conn ->
          Req.Test.json(
            conn,
            File.read!("test/fixtures/forge/form-engine.json") |> Jason.decode!()
          )
        end)

        assert {:ok, actual} =
                 @adapter.list("rpmessner/form-engine",
                   server: fake,
                   token: "test",
                   plug: {Req.Test, __MODULE__}
                 )

        assert actual["default_branch"] == "main"

        assert Enum.map(
                 actual["change_requests"],
                 &Map.take(&1, Map.keys(hd(snapshot["change_requests"])))
               ) == snapshot["change_requests"]

        assert @adapter.capabilities() == %{
                 head_guard: true,
                 retarget: true,
                 write: true,
                 create_change_request: true
               }
      end

      test "reads exact remote branch SHA, including slash names and absence" do
        sha = String.duplicate("a", 40)
        fake = start_supervised!({Foreman.Forge.Fake, %{"branches" => %{"pr/feature" => sha}}})

        Req.Test.stub(__MODULE__, fn conn ->
          assert conn.method == "GET"

          case conn.request_path do
            "/repos/owner/repo/git/ref/heads/pr%2Ffeature" ->
              Req.Test.json(conn, %{
                "ref" => "refs/heads/pr/feature",
                "object" => %{"type" => "commit", "sha" => sha}
              })

            _ ->
              conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{})
          end
        end)

        opts = [server: fake, token: "test", plug: {Req.Test, __MODULE__}]
        assert {:ok, ^sha} = @adapter.branch_sha("owner/repo", "pr/feature", opts)
        assert {:error, :not_found} = @adapter.branch_sha("owner/repo", "absent", opts)
      end

      test "creates a change request with exactly the named text and branches" do
        facts = %{
          "head_branch" => "feature",
          "base_branch" => "main",
          "title" => "Exact title",
          "body" => "Body\n\nWith spacing.\n"
        }

        fake =
          start_supervised!(
            {Foreman.Forge.Fake,
             %{
               "default_branch" => "main",
               "branches" => %{
                 "feature" => String.duplicate("a", 40),
                 "main" => String.duplicate("b", 40)
               },
               "change_requests" => []
             }}
          )

        Req.Test.stub(__MODULE__, fn conn ->
          assert conn.method == "POST"
          assert conn.request_path == "/repos/owner/repo/pulls"
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "head" => "feature",
                   "base" => "main",
                   "title" => "Exact title",
                   "body" => "Body\n\nWith spacing.\n"
                 }

          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{"number" => 1, "html_url" => "https://github.com/owner/repo/pull/1"})
        end)

        assert {:ok, %{"number" => 1, "url" => "https://github.com/owner/repo/pull/1"}} =
                 @adapter.create_change_request("owner/repo", facts,
                   server: fake,
                   token: "test",
                   plug: {Req.Test, __MODULE__}
                 )

        assert @adapter.capabilities().create_change_request

        if @adapter == Foreman.Forge.Fake do
          {:ok, snapshot} = @adapter.list("owner/repo", server: fake)
          assert [pr] = snapshot["change_requests"]

          assert Map.take(pr, ["title", "body", "source_branch", "target_branch"]) == %{
                   "title" => "Exact title",
                   "body" => "Body\n\nWith spacing.\n",
                   "source_branch" => "feature",
                   "target_branch" => "main"
                 }
        end
      end

      test "merge is head guarded and retarget replays the recorded live responses" do
        merge = fixture("merge-merge.json")
        retarget = fixture("retarget-retarget.json")
        head = merge["request"]["sha"]

        fake =
          start_supervised!(
            {Foreman.Forge.Fake,
             %{
               "default_branch" => "main",
               "change_requests" => [
                 %{"number" => 1, "head_sha" => head, "state" => "open"},
                 %{"number" => 2, "target_branch" => "pr/acceptance-bottom"}
               ]
             }}
          )

        opts = [server: fake, token: "test", plug: {Req.Test, __MODULE__}]

        Req.Test.stub(__MODULE__, fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          payload = Jason.decode!(body)

          case {conn.method, conn.request_path} do
            {"PUT", "/repos/owner/repo/pulls/1/merge"} ->
              assert payload["merge_method"] == "merge"

              if payload["sha"] == head,
                do: Req.Test.json(conn, merge["response"]),
                else:
                  conn
                  |> Plug.Conn.put_status(409)
                  |> Req.Test.json(%{"message" => "Head changed"})

            {"PATCH", "/repos/owner/repo/pulls/2"} ->
              assert payload == retarget["request"]
              Req.Test.json(conn, retarget["response"])
          end
        end)

        assert {:error, :head_moved} = @adapter.merge("owner/repo", 1, "old", opts)
        assert {:ok, %{"sha" => sha}} = @adapter.merge("owner/repo", 1, head, opts)
        assert is_binary(sha)
        if @adapter == Foreman.Forge.GitHub, do: assert(sha == merge["response"]["sha"])
        assert :ok = @adapter.retarget("owner/repo", 2, "main", opts)

        if @adapter == Foreman.Forge.Fake do
          {:ok, snapshot} = @adapter.list("owner/repo", opts)
          assert Enum.find(snapshot["change_requests"], &(&1["number"] == 1))["state"] == "merged"

          assert Enum.find(snapshot["change_requests"], &(&1["number"] == 2))["target_branch"] ==
                   "main"
        end
      end

      test "replays the real scratch open-PR response" do
        recording = File.read!("test/fixtures/forge/live-openpr/create.json") |> Jason.decode!()
        payload = recording["request"]
        response = recording["response"]
        number = response["number"]

        facts = %{
          "head_branch" => payload["head"],
          "base_branch" => payload["base"],
          "title" => payload["title"],
          "body" => payload["body"]
        }

        fake =
          start_supervised!(
            {Foreman.Forge.Fake,
             %{
               "branches" => %{payload["head"] => response["head"]["sha"]},
               "change_requests" => [%{"number" => number - 1, "state" => "closed"}]
             }}
          )

        Req.Test.stub(__MODULE__, fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == payload
          conn |> Plug.Conn.put_status(recording["status"]) |> Req.Test.json(response)
        end)

        assert {:ok, result} =
                 @adapter.create_change_request("rpmessner/beads-board-scratch", facts,
                   server: fake,
                   token: "test",
                   plug: {Req.Test, __MODULE__}
                 )

        assert result == %{"number" => number, "url" => response["html_url"]}
      end

      test "the recorded next read observes the merge and retarget" do
        expected = %{
          "default_branch" => "main",
          "change_requests" => [
            %{"number" => 1, "state" => "merged", "target_branch" => "main"},
            %{"number" => 2, "state" => "open", "target_branch" => "main"}
          ]
        }

        fake = start_supervised!({Foreman.Forge.Fake, expected})
        Req.Test.stub(__MODULE__, &Req.Test.json(&1, fixture("observed-list.json")["response"]))

        assert {:ok, snapshot} =
                 @adapter.list("fixture-owner/merge-scratch",
                   server: fake,
                   token: "test",
                   tracked: [1, 2],
                   plug: {Req.Test, __MODULE__}
                 )

        assert snapshot["default_branch"] == "main"

        assert snapshot["change_requests"]
               |> Enum.map(&Map.take(&1, ["number", "state", "target_branch"]))
               |> Enum.sort_by(& &1["number"]) == expected["change_requests"]
      end
    end
  end

  defp fixture(name), do: File.read!("test/fixtures/forge/live-merge/" <> name) |> Jason.decode!()
end
