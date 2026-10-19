defmodule ForemanWeb.PreviewControls do
  use ForemanWeb, :html
  alias Fluxon.Components.Button
  attr :preview, :map, required: true
  attr :terminal, :boolean, default: false

  def controls(assigns) do
    ~H"""
    <section id="ticket-preview" class="rounded-lg border border-base p-3 space-y-3">
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-sm font-medium">Preview</span>
        <span id="preview-state" class="text-xs text-foreground-softer">{@preview.state}</span>
        <Button.button
          :if={!@terminal && @preview.state in [:none, :stopped, :failed]}
          id="preview-start"
          size="xs"
          phx-click="preview"
          phx-value-action="start"
        >
          Start
        </Button.button>
        <a
          :if={@preview.state == :running && @preview.metadata["url"]}
          id="preview-open"
          href={@preview.metadata["url"]}
          target="_blank"
          rel="noopener noreferrer"
          class="rounded px-2 py-1 text-xs font-medium hover:bg-sunken underline underline-offset-4"
        >
          Open preview
        </a>
        <Button.button
          :if={@preview.state not in [:none, :stopped]}
          id="preview-stop"
          size="xs"
          variant="outline"
          phx-click="preview"
          phx-value-action="stop"
        >
          Stop
        </Button.button>
        <.link navigate={~p"/previews"} class="ml-auto text-xs text-foreground-softer hover:underline">
          Orphans
        </.link>
      </div>
      <p
        :if={@preview.error}
        id="preview-error"
        role="status"
        class="text-xs text-red-600 dark:text-red-400"
      >
        {@preview.error}
      </p>
      <details
        :if={@preview.state not in [:none, :stopped]}
        id="preview-log-panel"
        class="text-xs"
        phx-mounted={JS.ignore_attributes("open")}
      >
        <summary class="cursor-pointer rounded py-1 font-medium">Follow logs</summary>
        <pre
          id="preview-logs"
          class="mt-2 max-h-48 overflow-auto whitespace-pre-wrap break-all rounded bg-sunken p-3 font-mono"
        >{@preview.logs}</pre>
      </details>
    </section>
    """
  end
end
