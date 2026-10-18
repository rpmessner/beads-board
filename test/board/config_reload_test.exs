defmodule Board.ConfigReloadTest do
  use ExUnit.Case, async: true

  alias Board.Config.Reload

  test "a late completion from an older reload cannot replace newer data" do
    snapshot = Reload.new(%{"value" => "initial"})
    {first, _} = Reload.request(snapshot)
    {accepted, _} = Reload.complete(first, 1, {:ok, %{"value" => "first"}})
    {second, _} = Reload.request(accepted)
    assert Reload.complete(second, 1, {:ok, %{"value" => "late"}}) == {second, []}
  end

  @tag :tmp_dir
  test "invalid edits retain the last good config, then recover", %{tmp_dir: directory} do
    {:ok, defaults} = Board.Config.load(directory)
    snapshot = Reload.new(defaults)
    {loading, effects} = Reload.request(snapshot)
    assert effects == [read: {:config, 1}]
    assert Reload.request(loading) == {loading, []}

    for bad <- ["[[columns]]\ntitle = \"Bad\"\nstages = [\"speccing\"]", "[broken"] do
      File.write!(Path.join(directory, "board.toml"), bad)
      {rejected, effects} = Reload.complete(loading, 1, Board.Config.load(directory))
      assert rejected.config == defaults
      assert rejected.state == :invalid
      assert is_binary(rejected.error)
      assert effects == [broadcast: :config]

      File.write!(Path.join(directory, "board.toml"), "[board]\nswimlanes = \"epic\"")
      {retry, _} = Reload.request(rejected)
      {accepted, effects} = Reload.complete(retry, 2, Board.Config.load(directory))
      assert accepted.config["board"]["swimlanes"] == "epic"
      assert accepted.state == :valid
      assert accepted.error == nil
      assert effects == [broadcast: :config]
      assert Reload.complete(accepted, 2, {:error, "late result"}) == {accepted, []}
    end
  end
end
