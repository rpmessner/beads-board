defmodule BoardWeb.RelativeTime do
  @moduledoc "Compact relative UTC timestamps for board status labels."
  def format(time, now \\ DateTime.utc_now()) do
    seconds = max(DateTime.diff(now, time), 0)

    cond do
      seconds < 60 -> "#{seconds} s ago"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86400 -> "#{div(seconds, 3600)} h ago"
      true -> "#{div(seconds, 86400)} d ago"
    end
  end
end
