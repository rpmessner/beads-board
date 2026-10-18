defmodule Foreman.RuntimeTest do
  use Foreman.DataCase, async: true

  test "Oban persists jobs in the application's Postgres sandbox" do
    assert Oban.config().engine == Oban.Engines.Basic

    assert {:ok, job} =
             Oban.insert(
               Oban.Job.new(%{"probe" => true},
                 worker: "Foreman.RuntimeProbe",
                 queue: :external_reads
               )
             )

    assert Repo.get!(Oban.Job, job.id).args == %{"probe" => true}
    assert %{rows: [[database]]} = Repo.query!("SELECT current_database()")

    assert database ==
             "foreman_test_#{Path.basename(File.cwd!())}#{System.get_env("MIX_TEST_PARTITION")}"
  end

  test "endpoint is loopback only" do
    assert Application.fetch_env!(:foreman, ForemanWeb.Endpoint)[:http][:ip] == {127, 0, 0, 1}
  end
end
