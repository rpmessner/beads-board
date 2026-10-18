defmodule Board.RuntimeTest do
  use Board.DataCase, async: true

  test "Oban persists jobs in the application's Postgres sandbox" do
    assert Oban.config().engine == Oban.Engines.Basic

    assert {:ok, job} =
             Oban.insert(
               Oban.Job.new(%{"probe" => true},
                 worker: "Board.RuntimeProbe",
                 queue: :external_reads
               )
             )

    assert Repo.get!(Oban.Job, job.id).args == %{"probe" => true}
    assert %{rows: [[database]]} = Repo.query!("SELECT current_database()")

    assert database ==
             "beads_board_test_#{Path.basename(File.cwd!())}#{System.get_env("MIX_TEST_PARTITION")}"
  end

  test "endpoint is loopback only" do
    assert Application.fetch_env!(:board, BoardWeb.Endpoint)[:http][:ip] == {127, 0, 0, 1}
  end
end
