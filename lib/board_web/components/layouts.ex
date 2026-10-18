defmodule BoardWeb.Layouts do
  use BoardWeb, :html
  embed_templates "layouts/*"
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-base text-sm text-foreground md:flex">
      <aside class="flex shrink-0 flex-col gap-6 border-b border-base bg-sunken px-3 py-4 md:min-h-screen md:w-60 md:border-r md:border-b-0">
        <a href="/" class="flex items-center gap-2.5 px-2.5 py-1 text-[15px] font-semibold">
          <.icon name="hero-ellipsis-horizontal-circle" class="size-6" /> beads-board
        </a>
        <nav aria-label="Main" class="space-y-1">
          <.link navigate={~p"/"} class="bb-nav">
            <.icon name="hero-bars-3-bottom-left" class="size-4" /> Initiatives
          </.link>
          <span class="bb-nav text-foreground-softer" aria-disabled="true">
            <.icon name="hero-code-bracket" class="size-4" /> Pull requests
            <span class="ml-auto text-xs">soon</span>
          </span>
          <.link navigate={~p"/settings"} class="bb-nav bg-accent" aria-current="page">
            <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
          </.link>
        </nav>
        <div class="mt-auto space-y-4 px-2.5">
          <div class="flex gap-2">
            <button
              id="theme-light"
              class="bb-theme"
              aria-label="Light theme"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme="light"
            >
              <.icon name="hero-sun" class="size-4" />
            </button>
            <button
              id="theme-dark"
              class="bb-theme"
              aria-label="Dark theme"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme="dark"
            >
              <.icon name="hero-moon" class="size-4" />
            </button>
          </div>
          <p class="text-xs text-foreground-softer">
            Synced via <span class="font-mono">bd export</span>
            <br />Agents take priority over freshness.
          </p>
        </div>
      </aside>
      <main class="min-w-0 flex-1 space-y-5 px-5 pt-6 pb-10 lg:px-7">
        {render_slot(@inner_block)}
      </main>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" aria-live="polite" class="fixed right-5 bottom-5 z-50 space-y-2">
      <div
        :for={kind <- [:info, :error]}
        :if={Phoenix.Flash.get(@flash, kind)}
        class="bb-panel"
        phx-click={JS.push("lv:clear-flash", value: %{key: kind})}
      >
        {Phoenix.Flash.get(@flash, kind)}
      </div>
    </div>
    """
  end
end
