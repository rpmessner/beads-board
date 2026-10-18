defmodule Board.SpoolWorker do
  @moduledoc "Worker-role boot and periodic replay; database failures never take down the worker."
  use GenServer
  require Logger
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(opts) do
    send(self(), :replay)
    {:ok, Keyword.get(opts, :interval, 3_000)}
  end

  @impl true
  def handle_info(:replay, interval) do
    try do
      Board.Spool.replay()
    rescue
      _ -> Logger.warning("board spool replay deferred: database or command unavailable")
    catch
      :exit, _ -> Logger.warning("board spool replay deferred: database unavailable")
    end

    Process.send_after(self(), :replay, interval)
    {:noreply, interval}
  end
end
