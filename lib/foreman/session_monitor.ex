defmodule Foreman.SessionMonitor do
  @moduledoc "Worker-side liveness polling; stopping this process never touches tmux."
  use GenServer
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    send(self(), :poll)
    {:ok, opts}
  end

  def handle_info(:poll, opts) do
    Foreman.Sessions.reconcile(opts)
    Process.send_after(self(), :poll, 3_000)
    {:noreply, opts}
  end
end
