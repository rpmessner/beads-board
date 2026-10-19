defmodule ForemanWeb.PreviewsLive do
  use ForemanWeb, :live_view
  alias Fluxon.Components.Button
  @impl true
  def mount(_, _, socket) do
    if connected?(socket), do: Process.send_after(self(), :reconcile, 3_000)
    {:ok, refresh(socket)}
  end

  @impl true
  def handle_info(:reconcile, socket) do
    Process.send_after(self(), :reconcile, 3_000)
    {:noreply, refresh(socket)}
  end

  @impl true
  def handle_event("stop-preview", %{"id" => id}, socket) do
    # Only the current orphan inventory is actionable from this surface.
    row = Enum.find(Foreman.Previews.orphans(), &(to_string(&1.id) == id))
    if row, do: Foreman.Previews.stop(row.id)
    {:noreply, refresh(socket)}
  end

  defp refresh(socket), do: stream(socket, :previews, Foreman.Previews.orphans(), reset: true)
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:previews}>
      <div class="mx-auto max-w-5xl p-4 sm:p-8">
        <h1 class="mb-6 text-2xl font-semibold">Orphan previews</h1>
        <div id="orphan-previews" phx-update="stream" class="space-y-3">
          <p id="no-orphan-previews" class="hidden only:block text-sm text-foreground-softer">
            No orphan previews
          </p>
          <article
            :for={{id, preview} <- @streams.previews}
            id={id}
            class="rounded-lg border border-base p-4 space-y-2"
          >
            <div class="flex flex-wrap items-center gap-3">
              <span class="font-mono text-xs break-all">
                {preview.metadata["unit"] || preview.worktree}
              </span>
              <span class="text-xs text-foreground-softer">{preview.state}</span>
              <Button.button
                id={"stop-preview-#{preview.id}"}
                size="xs"
                variant="outline"
                phx-click="stop-preview"
                phx-value-id={preview.id}
              >
                Stop
              </Button.button>
            </div>
            <p class="text-xs text-foreground-softer break-all">{preview.worktree}</p>
            <p :if={preview.error} role="status" class="text-xs text-red-600 dark:text-red-400">
              {preview.error}
            </p>
          </article>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
