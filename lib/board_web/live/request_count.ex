defmodule BoardWeb.RequestCount do
  @moduledoc "Shared authoritative inbox count; mount, notifications and periodic reconciliation."
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _, _, socket) do
    if connected?(socket) do
      Board.Events.subscribe()
      Process.send_after(self(), :request_count_tick, 3_000)
    end

    {:cont,
     socket
     |> refresh()
     |> attach_hook(:request_count_params, :handle_params, fn _, _, socket ->
       {:cont, refresh(socket)}
     end)
     |> attach_hook(:request_count, :handle_info, &handle_info/2)}
  end

  def refresh(socket) do
    count = Board.Requests.pending_count()

    assign(socket,
      pending_count: count,
      page_title: if(count > 0, do: "(#{count}) beads-board", else: "beads-board")
    )
  end

  defp handle_info(:request_count_tick, socket) do
    Process.send_after(self(), :request_count_tick, 3_000)
    {:halt, refresh(socket)}
  end

  defp handle_info({:notification, :board_events, _}, socket), do: {:cont, refresh(socket)}
  defp handle_info(_, socket), do: {:cont, socket}
end
