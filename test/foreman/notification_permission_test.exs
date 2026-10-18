defmodule Foreman.NotificationPermissionTest do
  use ExUnit.Case, async: true
  alias Foreman.NotificationPermission

  test "only a click from default permission can prompt" do
    for state <- NotificationPermission.__fsm__(:states),
        event <- NotificationPermission.__fsm__(:events) do
      {_, effects} = NotificationPermission.step(state, event, %{})
      assert Keyword.has_key?(effects, :prompt) == (state == :default and event == :click)
    end
  end

  test "reconciliation cannot reopen an outstanding prompt" do
    assert {:requesting, [prompt: :permission]} =
             NotificationPermission.step(:default, :click, %{})

    assert {:requesting, []} = NotificationPermission.step(:requesting, :default, %{})
    assert {:default, []} = NotificationPermission.step(:requesting, :dismissed, %{})
    assert {:granted, []} = NotificationPermission.step(:requesting, :granted, %{})
    assert {:denied, []} = NotificationPermission.step(:requesting, :denied, %{})
  end

  test "browser table preserves the declared machine" do
    table = NotificationPermission.browser_table()

    for {state, events} <- table, {event, row} <- events do
      {next, effects} = NotificationPermission.step(state, event, %{})
      assert row == %{state: next, prompt: Keyword.has_key?(effects, :prompt)}
    end
  end
end
