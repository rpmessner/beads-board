defmodule Foreman.CoordinatorTest do
  use Foreman.DataCase, async: false
  alias Foreman.Sessions

  test "stale coordinator hooks cannot fall back to external session tracking" do
    assert {:error, :unknown_session} =
             Foreman.SessionWaiting.ask(Sessions.coordinator_key(), %{
               "session" => Ecto.UUID.generate(),
               "facts" => %{"reason" => "input"}
             })
  end

  test "adoption cannot take another planning conversation's identity" do
    id = Ecto.UUID.generate()

    Foreman.Repo.insert!(%Foreman.PlanningSession{
      session_id: id,
      project: "sample",
      ticket: "x-1",
      workdir: "/tmp",
      state: :ended,
      launched_at: DateTime.utc_now()
    })

    assert Sessions.prepare_coordinator({:adopt, id}) == {:error, :session_id_in_use}
    assert is_nil(Sessions.coordinator())
  end

  test "a failed fresh launch preserves the recorded conversation" do
    {:ok, before, :adopt} = Sessions.prepare_coordinator({:adopt, Ecto.UUID.generate()})

    assert {:error, _} =
             Sessions.launch_coordinator(:fresh,
               executable: "/no/such/claude",
               workdir: File.cwd!(),
               socket: "fm-coordinator-missing-test-socket"
             )

    assert Sessions.coordinator().session_id == before.session_id
  end

  test "a rejected pane command returns a refusal without aborting its caller" do
    {:ok, before, :adopt} = Sessions.prepare_coordinator({:adopt, Ecto.UUID.generate()})

    assert {422, %{error: :invalid_coordinator_pane}} =
             Foreman.AgentCommands.execute(%{
               "action" => "coordinator",
               "mode" => "fresh",
               "pane" => "not-a-pane",
               "socket" => "not-a-socket"
             })

    assert Sessions.coordinator().session_id == before.session_id
  end

  test "coordinator waits reach the inbox without a ticket or project" do
    {:ok, s, :fresh} = Sessions.prepare_coordinator(:resume, window: "@123")
    key = Sessions.coordinator_key()
    {project, ticket} = key

    assert {200, %{id: id}} =
             Foreman.AgentCommands.execute(%{
               "action" => "ask",
               "request_kind" => "session_waiting",
               "id" => ticket,
               "project" => project,
               "session" => s.session_id,
               "facts" => %{"reason" => "usage_limit", "provider" => "Anthropic"}
             })

    assert Foreman.Requests.get(id).state == "pending"
    assert Sessions.coordinator().state == :waiting

    assert {200, _} =
             Foreman.AgentCommands.execute(%{
               "action" => "session_resumed",
               "id" => ticket,
               "project" => project,
               "session" => s.session_id
             })

    assert Foreman.Requests.get(id).state == "superseded"
  end

  test "coordinator adoption is an authenticated command independent of the project catalog" do
    id = "1edc88cf-b665-4ce3-adc4-f1bd434c64f2"

    assert {200, %{session_id: ^id}} =
             Foreman.AgentCommands.execute(%{
               "action" => "coordinator",
               "mode" => "adopt",
               "adopt" => id
             })
  end

  test "fresh replaces the conversation and adopt records an existing UUID" do
    {:ok, first, :fresh} = Sessions.prepare_coordinator(:resume)
    assert {:ok, fresh, :fresh} = Sessions.prepare_coordinator(:fresh)
    refute fresh.session_id == first.session_id
    id = "1edc88cf-b665-4ce3-adc4-f1bd434c64f2"
    assert {:ok, adopted, :adopt} = Sessions.prepare_coordinator({:adopt, id})
    assert adopted.state == :ended
    assert {:ok, resumed, :resume} = Sessions.prepare_coordinator(:resume)
    assert resumed.session_id == id
    assert Sessions.prepare_coordinator({:adopt, "bad"}) == {:error, :invalid_session_id}
  end

  test "a new coordinator is recorded globally and the next launch resumes its identity" do
    assert {:ok, first, :fresh} = Sessions.prepare_coordinator(:resume)
    assert first.workdir == Path.expand("~/dev/music")
    assert Sessions.coordinator().session_id == first.session_id
    assert {:ok, second, :resume} = Sessions.prepare_coordinator(:resume)
    assert second.session_id == first.session_id
  end
end
