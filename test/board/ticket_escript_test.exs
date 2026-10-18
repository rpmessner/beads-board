defmodule Board.TicketEscriptTest do
  use ExUnit.Case, async: false

  setup_all do
    Mix.Task.run("escript.build", ["--no-compile"])
    {:ok, executable: Path.expand("board")}
  end

  test "default config comes from the user directory with local overrides, never the checkout", %{
    executable: executable
  } do
    root =
      Path.join(System.tmp_dir!(), "board-default-config-#{System.unique_integer([:positive])}")

    home = Path.join(root, "home")
    config = Path.join(home, ".config/beads-board")
    checkout = Path.join(root, "checkout")
    File.mkdir_p!(config)
    File.mkdir_p!(checkout)
    on_exit(fn -> File.rm_rf!(root) end)
    {_, 0} = System.cmd("git", ["init", "-q", checkout])

    entry =
      "[[repos]]\nkey = \"sample\"\npath = #{Jason.encode!(checkout)}\nprefix = \"global\"\n"

    File.write!(Path.join(config, "board.toml"), entry)

    File.write!(
      Path.join(config, "board.local.toml"),
      "[[repos]]\nkey = \"sample\"\nprefix = \"local\"\n"
    )

    File.write!(Path.join(checkout, "board.toml"), String.replace(entry, "global", "wrong"))
    env = [{"HOME", home}, {"BOARD_CONFIG_DIR", nil}, {"BOARD_URL", "http://127.0.0.1:1"}]

    {text, 0} =
      System.cmd(executable, ["new", "Default config", "--json"], cd: checkout, env: env)

    assert %{"id" => "local-" <> _} = Jason.decode!(text)
    File.rm!(Path.join(config, "board.local.toml"))
    {text, 0} = System.cmd(executable, ["new", "Global config", "--json"], cd: checkout, env: env)
    assert %{"id" => "global-" <> _} = Jason.decode!(text)
    File.rm!(Path.join(config, "board.toml"))
    {text, 2} = System.cmd(executable, ["new", "No fallback", "--json"], cd: checkout, env: env)
    assert Jason.decode!(text)["error"] =~ "board.toml"
  end

  test "every file command runs in a checkout with HTTP and Postgres unavailable", %{
    executable: executable
  } do
    root = Path.join(System.tmp_dir!(), "board-escript-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    {_, 0} = System.cmd("git", ["init", "-q", root])

    config = Path.join(root, "config")
    File.mkdir_p!(config)

    File.write!(
      Path.join(config, "board.toml"),
      "[[repos]]\nkey = \"demo\"\npath = #{Jason.encode!(root)}\nprefix = \"demo\"\n"
    )

    env = [
      {"BOARD_URL", "http://127.0.0.1:1"},
      {"PGPORT", "1"},
      {"BOARD_DATABASE_URL", "postgres://none:none@127.0.0.1:1/none"},
      {"BOARD_CONFIG_DIR", config}
    ]

    run = fn args ->
      {text, code} =
        System.cmd(executable, args ++ ["--json"], cd: root, env: env, stderr_to_stdout: true)

      assert code == 0, "#{inspect(args)}: #{text}"
      Jason.decode!(text)
    end

    epic = run.(["new", "Epic", "--type", "epic"])["id"]
    one = run.(["new", "One", "--parent", epic])["id"]
    two = run.(["new", "Two", "--parent", epic, "--blocked-by", one])["id"]
    assert run.(["show", one])["title"] == "One"
    assert length(run.(["ls"])) == 3
    assert Enum.map(run.(["ready"]), & &1["id"]) == [one]
    assert run.(["update", one, "--title", "Updated"])["title"] == "Updated"
    assert run.(["note", one, "Done", "--actor", "test"])["body"] =~ "test: Done"
    assert run.(["close", one, "--reason", "Verified"])["status"] == "closed"
    assert Enum.map(run.(["ready"]), & &1["id"]) == [two]
    assert run.(["reopen", one])["status"] == "open"
    assert run.(["dep", "rm", two, one])["blocked_by"] == []
    assert run.(["dep", "add", two, one])["blocked_by"] == [one]
    assert [%{"children" => [_, _]}] = run.(["tree"])
    assert run.(["renumber", one, epic <> ".4"])["id"] == epic <> ".4"
    assert run.(["check"])["valid"]
    {text, 2} = System.cmd(executable, ["close", two, "--json"], cd: root, env: env)
    assert Jason.decode!(text)["error"] =~ "reason"
    File.write!(Path.join([root, "tickets", two <> ".md"]), "broken")
    {text, 2} = System.cmd(executable, ["check", "--json"], cd: root, env: env)
    assert [%{"file" => file}] = Jason.decode!(text)["errors"]
    assert file == "tickets/#{two}.md"
  end
end
