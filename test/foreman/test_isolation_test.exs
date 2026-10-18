defmodule Foreman.TestIsolationTest do
  use ExUnit.Case, async: false

  test "test database is checkout-local and retains the partition suffix" do
    old = System.get_env("MIX_TEST_PARTITION")

    on_exit(fn ->
      if old,
        do: System.put_env("MIX_TEST_PARTITION", old),
        else: System.delete_env("MIX_TEST_PARTITION")
    end)

    System.put_env("MIX_TEST_PARTITION", "_probe")
    config = Config.Reader.read!("config/test.exs", env: :test, target: :host)
    checkout = Path.basename(File.cwd!())
    assert config[:foreman][Foreman.Repo][:database] == "foreman_test_#{checkout}_probe"
    assert config[:foreman][Foreman.Repo][:pool] == Ecto.Adapters.SQL.Sandbox
  end

  @tag :tmp_dir
  test "different checkout names select different databases", %{tmp_dir: tmp} do
    names =
      for checkout <- ["bb-cli", "bb-merge"] do
        directory = Path.join([tmp, checkout, "config"])
        File.mkdir_p!(directory)
        path = Path.join(directory, "test.exs")
        File.cp!("config/test.exs", path)
        Config.Reader.read!(path, env: :test, target: :host)[:foreman][Foreman.Repo][:database]
      end

    suffix = System.get_env("MIX_TEST_PARTITION") || ""
    assert names == ["foreman_test_bb-cli" <> suffix, "foreman_test_bb-merge" <> suffix]
  end

  test "acceptance commits cannot target a unit-test database" do
    config = Config.Reader.read!("config/acceptance.exs", env: :acceptance, target: :host)

    assert config[:foreman][Foreman.Repo][:database] ==
             "foreman_acceptance_#{Path.basename(File.cwd!())}"

    assert config[:foreman][Foreman.Repo][:pool] == DBConnection.ConnectionPool

    assert_raise RuntimeError, ~r/acceptance requires MIX_ENV=acceptance/, fn ->
      Code.eval_file("tools/cli-acceptance-server.exs")
    end
  end

  test "the suite guard detects committed fixture leaks without deleting them" do
    unboxed = &Ecto.Adapters.SQL.Sandbox.unboxed_run(Foreman.Repo, &1)

    on_exit(fn ->
      unboxed.(fn -> Foreman.Repo.query!("DELETE FROM board_config WHERE id=1") end)
    end)

    unboxed.(fn ->
      Foreman.Repo.insert_all("board_config", [
        %{
          id: 1,
          config: %{},
          source: "leak-regression",
          discovered: [],
          loaded_at: DateTime.utc_now()
        }
      ])
    end)

    assert_raise RuntimeError,
                 ~r/Committed test data.*board_config/,
                 &Foreman.TestDatabase.assert_clean!/0

    unboxed.(fn ->
      assert %{rows: [["leak-regression"]]} =
               Foreman.Repo.query!("SELECT source FROM board_config WHERE id=1")
    end)
  end

  test "no autonomous runtime writer starts in the test application" do
    refute Application.fetch_env!(:foreman, :runtime_enabled)

    for module <- [Foreman.Runtime, Foreman.Config.Watcher, Foreman.SpoolWorker] do
      assert Process.whereis(module) == nil
      refute module in Foreman.Role.children("all", Application.fetch_env!(:foreman, Oban))
    end

    assert Application.fetch_env!(:foreman, Oban)[:testing] == :manual
  end
end
