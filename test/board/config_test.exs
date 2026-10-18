defmodule Board.ConfigTest do
  use ExUnit.Case, async: true

  test "unknown stages are rejected with the source and field" do
    assert {:error, error} = parse("[[columns]]\ntitle = \"Oops\"\nstages = [\"speccing\"]")
    assert error =~ "board.toml"
    assert error =~ "columns[0].stages"
    assert error =~ "speccing"
  end

  test "bad TOML is an error, not a crash" do
    assert {:error, "board.toml: invalid TOML"} = parse("[board\n")
  end

  test "malformed shapes, unknown options and duplicate identities are rejected" do
    for text <- [
          "repos = [1]",
          "repos = false",
          "columns = {}",
          "unknown = true",
          "[board]\nswimlanes = false",
          "[board]\nstale_session_after = \"soon\"",
          "[board]\nstale_session_after = \"0h\"",
          "[[columns]]\ntitle = \"X\"\nstages = []",
          "[[repos]]\nkey = \"sample\"\npath = \"relative/path\"",
          "[[repos]]\nkey = \"sample\"\npath = \"~/dev/sample\"\nenabled = \"yes\"",
          "[[repos]]\nkey = \"sample\"\npath = \"~/dev/sample\"\nforge = \"unknown\"",
          "[[repos]]\nkey = \"sample\"\npath = \"~/dev/sample\"\n[[repos]]\nkey = \"sample\"\npath = \"~/dev/other\"",
          "[[repos]]\nkey = \"sample\"\npath = \"~/dev/sample\"\n[[repos]]\nkey = \"other\"\npath = \"~/dev/sample/.\"",
          "[backfill]\ndefault = \"speccing\"",
          "[epics.\"fe-1\"]\npin = 1"
        ] do
      assert {:error, _} = parse(text), text
    end
  end

  test "empty repos clears inherited repos and omitted files leave shipped defaults" do
    assert {:ok, config} = parse("repos = []")
    assert config["repos"] == []
    assert length(config["columns"]) == 5
  end

  defp parse(text) do
    Board.Config.parse_layers(
      [
        {"defaults", File.read!("priv/board.defaults.toml")},
        {"board.toml", text}
      ],
      home: "/tmp/config-home"
    )
  end

  test "local tables override global values while columns replace as a unit" do
    defaults = File.read!("priv/board.defaults.toml")

    global = """
    [board]
    swimlanes = "epic"
    [[repos]]
    key = "sample"
    path = "~/dev/sample"
    github = "example/sample"
    [[columns]]
    title = "Working"
    stages = ["building", "reported"]
    """

    local = """
    [board]
    stale_session_after = "30m"
    [[repos]]
    key = "sample"
    enabled = false
    """

    assert {:ok, config} =
             Board.Config.parse_layers(
               [{"defaults", defaults}, {"board.toml", global}, {"board.local.toml", local}],
               home: "/tmp/config-home"
             )

    assert config["board"] == %{"swimlanes" => "epic", "stale_session_after" => "30m"}
    assert config["backfill"] == %{"closed" => "done", "default" => "queued"}

    assert config["columns"] == [
             %{"title" => "Working", "stages" => ["building", "reported"], "collapsed" => false}
           ]

    assert config["repos"] == [
             %{
               "key" => "sample",
               "path" => "/tmp/config-home/dev/sample",
               "github" => "example/sample",
               "enabled" => false,
               "forge" => "github",
               "color" => "zinc"
             }
           ]
  end
end
