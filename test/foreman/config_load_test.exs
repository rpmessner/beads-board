defmodule Foreman.ConfigLoadTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "missing optional files use defaults; local file wins", %{tmp_dir: directory} do
    assert {:ok, defaults} = Foreman.Config.load(directory)
    assert defaults["repos"] == []
    File.write!(Path.join(directory, "foreman.toml"), "[board]\nswimlanes = \"epic\"")
    File.write!(Path.join(directory, "foreman.local.toml"), "[board]\nswimlanes = \"none\"")
    assert {:ok, config} = Foreman.Config.load(directory)
    assert config["board"]["swimlanes"] == "none"
    assert config["board"]["stale_session_after"] == "2h"
  end
end
