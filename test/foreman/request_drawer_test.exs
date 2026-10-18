defmodule Foreman.RequestDrawerTest do
  use ExUnit.Case, async: true

  test "open and close are idempotent from both visibility states" do
    assert Foreman.RequestDrawer.__fsm__(:initial) == :closed

    for state <- [:closed, :open] do
      assert Foreman.RequestDrawer.step(state, :open, %{}) == {:open, []}
      assert Foreman.RequestDrawer.step(state, :close, %{}) == {:closed, []}
    end
  end
end
