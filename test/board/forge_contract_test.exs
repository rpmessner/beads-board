defmodule Board.ForgeContractTest do
  use ExUnit.Case, async: true

  for adapter <- [Board.Forge.Fake, Board.Forge.GitHub] do
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

        fake = start_supervised!({Board.Forge.Fake, snapshot})

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

        assert @adapter.capabilities() == %{head_guard: true, retarget: true, write: true}
      end

      test "merge is head guarded and retarget changes only the base" do
        fake =
          start_supervised!(
            {Board.Forge.Fake,
             %{
               "default_branch" => "main",
               "change_requests" => [
                 %{"number" => 5, "head_sha" => "confirmed", "state" => "open"},
                 %{"number" => 6, "target_branch" => "stack"}
               ]
             }}
          )

        opts = [server: fake, token: "test", plug: {Req.Test, __MODULE__}]

        Req.Test.stub(__MODULE__, fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          payload = Jason.decode!(body)

          case {conn.method, conn.request_path} do
            {"PUT", "/repos/owner/repo/pulls/5/merge"} ->
              assert payload["merge_method"] == "merge"

              if payload["sha"] == "confirmed",
                do: Req.Test.json(conn, %{"merged" => true, "sha" => "merge-sha"}),
                else:
                  conn
                  |> Plug.Conn.put_status(409)
                  |> Req.Test.json(%{"message" => "Head changed"})

            {"PATCH", "/repos/owner/repo/pulls/6"} ->
              assert payload == %{"base" => "main"}
              Req.Test.json(conn, %{"number" => 6, "base" => %{"ref" => "main"}})
          end
        end)

        assert {:error, :head_moved} = @adapter.merge("owner/repo", 5, "old", opts)
        assert {:ok, %{"sha" => sha}} = @adapter.merge("owner/repo", 5, "confirmed", opts)
        assert is_binary(sha)
        assert :ok = @adapter.retarget("owner/repo", 6, "main", opts)

        if @adapter == Board.Forge.Fake do
          {:ok, snapshot} = @adapter.list("owner/repo", opts)
          assert Enum.find(snapshot["change_requests"], &(&1["number"] == 5))["state"] == "merged"

          assert Enum.find(snapshot["change_requests"], &(&1["number"] == 6))["target_branch"] ==
                   "main"
        end
      end
    end
  end
end
