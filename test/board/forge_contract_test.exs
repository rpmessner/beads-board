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

        assert @adapter.capabilities() == %{head_guard: true, retarget: true, write: false}
        assert @adapter.merge("repo", 5, "sha", []) == {:error, :read_only}
        assert @adapter.retarget("repo", 6, "main", []) == {:error, :read_only}
      end
    end
  end
end
