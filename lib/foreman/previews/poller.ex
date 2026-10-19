defmodule Foreman.Previews.Poller do
  @moduledoc "Worker boot/recovery polling; never launches an app without durable start intent."
  use GenServer
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(_) do
    send(self(), :poll)
    {:ok, nil}
  end

  @impl true
  def handle_info(:poll, state) do
    if Foreman.Preview.allow_external_write() == :ok, do: Foreman.Previews.enqueue()
    Process.send_after(self(), :poll, 3_000)
    {:noreply, state}
  end
end
