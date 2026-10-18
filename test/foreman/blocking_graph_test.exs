defmodule Foreman.BlockingGraphTest do
  use ExUnit.Case, async: true

  test "cycles and external blockers stay visible" do
    a = {"repo", "a"}
    b = {"repo", "b"}
    outside = {"repo", "outside"}

    graph =
      Foreman.BlockingGraph.layout(
        [%{from: a, to: b}, %{from: b, to: a}, %{from: outside, to: a}],
        [%{key: a, stage: :queued}, %{key: b, stage: :building}],
        %{},
        MapSet.new([b])
      )

    assert length(graph.nodes) == 3
    assert length(graph.edges) == 3
    assert Enum.find(graph.nodes, &(&1.key == outside)).external
    assert Enum.find(graph.nodes, &(&1.key == b)).fallout
  end

  @tag timeout: 1000
  test "layering a dense dependency DAG has bounded work" do
    keys = for n <- 1..30, do: {"repo", Integer.to_string(n)}

    edges =
      for {from, i} <- Enum.with_index(keys),
          {to, j} <- Enum.with_index(keys),
          i < j,
          do: %{from: from, to: to}

    graph = Foreman.BlockingGraph.layout(edges, [], %{}, MapSet.new())
    assert length(graph.nodes) == 30
    assert length(Enum.uniq_by(graph.nodes, & &1.x)) == 30
  end
end
