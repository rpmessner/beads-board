defmodule Board.AgentCatalogTest do
  use ExUnit.Case, async: true
  alias Board.AgentCatalog

  @repos [
    %{"key" => "sample", "path" => "/work/sample", "prefixes" => ["s"]},
    %{"key" => "nested", "path" => "/work/sample/nested", "prefixes" => ["n"]}
  ]
  test "prefix selects repo regardless of cwd; explicit project wins" do
    assert {:ok, {"sample", "s-42"}} =
             AgentCatalog.resolve(%{"id" => "s-42", "cwd" => "/elsewhere"}, @repos)

    assert {:ok, {"nested", "s-42"}} =
             AgentCatalog.resolve(%{"id" => "s-42", "project" => "nested"}, @repos)
  end

  test "draft slug selects deepest containing cwd without path prefix collisions" do
    assert {:ok, {"nested", "draft:idea"}} =
             AgentCatalog.resolve(
               %{"id" => "idea", "kind" => "epic", "cwd" => "/work/sample/nested/docs"},
               @repos
             )

    assert {:error, :unknown_project} =
             AgentCatalog.resolve(%{"id" => "draft:idea", "cwd" => "/work/sample-other"}, @repos)

    assert {:error, :ambiguous_prefix} =
             AgentCatalog.resolve(
               %{"id" => "s-42"},
               @repos ++ [%{"key" => "alias", "path" => "/alias", "prefixes" => ["s"]}]
             )
  end
end
