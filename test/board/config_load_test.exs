defmodule Board.ConfigLoadTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "missing optional files use defaults; local file wins", %{tmp_dir: directory} do
    assert {:ok, defaults} = Board.Config.load(directory)
    assert defaults["repos"] == []
    File.write!(Path.join(directory, "board.toml"), "[board]\nswimlanes = \"epic\"")
    File.write!(Path.join(directory, "board.local.toml"), "[board]\nswimlanes = \"none\"")
    assert {:ok, config} = Board.Config.load(directory)
    assert config["board"]["swimlanes"] == "none"
    assert config["board"]["stale_session_after"] == "2h"
  end
end
