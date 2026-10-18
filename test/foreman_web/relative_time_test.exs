defmodule ForemanWeb.RelativeTimeTest do
  use ExUnit.Case, async: true

  test "recent timestamps use human time" do
    now = ~U[2026-10-18 12:00:00Z]
    assert ForemanWeb.RelativeTime.format(now, now) == "just now"
    assert ForemanWeb.RelativeTime.format(DateTime.add(now, -59), now) == "just now"
    assert ForemanWeb.RelativeTime.format(DateTime.add(now, -120), now) == "2 min ago"
  end
end
