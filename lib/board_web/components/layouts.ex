defmodule BoardWeb.Layouts do
  use BoardWeb, :html
  embed_templates "layouts/*"
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :active, :atom, default: :initiatives
  attr :repos, :list, default: []
  attr :filters, :map, default: %{}
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-base text-sm text-foreground md:flex">
      <aside class="flex shrink-0 flex-col gap-6 border-b border-base bg-sunken px-3 py-4 md:min-h-screen md:w-60 md:border-r md:border-b-0">
        <a href="/" class="flex items-center gap-2.5 px-2.5 py-1 text-[15px] font-semibold">
          <.icon name="hero-ellipsis-horizontal-circle" class="size-6" /> beads-board
        </a>
        <nav aria-label="Main" class="space-y-1">
          <.link
            navigate={~p"/"}
            class={["bb-nav", @active in [:initiatives, :epic] && "bb-nav-active"]}
            aria-current={@active in [:initiatives, :epic] && "page"}
          >
            <.icon name="hero-bars-3-bottom-left" class="size-4" /> Initiatives
          </.link>
          <span class="bb-nav text-foreground-softer" aria-disabled="true">
            <.icon name="hero-code-bracket" class="size-4" /> Pull requests
            <span class="ml-auto text-xs">soon</span>
          </span>
          <.link
            navigate={~p"/settings"}
            class={["bb-nav", @active == :settings && "bb-nav-active"]}
            aria-current={@active == :settings && "page"}
          >
            <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
          </.link>
        </nav>
        <section :if={@repos != []} class="space-y-2 px-2.5" aria-label="Projects">
          <h2 class="bb-label">Projects · tickets</h2>
          <.link
            :for={repo <- @repos}
            id={"sidebar-project-" <> repo["key"]}
            patch={if @active == :initiatives, do: project_path(@filters, repo["key"])}
            navigate={if @active != :initiatives, do: project_path(%{}, repo["key"])}
            class={[
              "bb-project bb-nav text-xs",
              @active == :initiatives && @filters["project"] == repo["key"] && "bb-nav-active"
            ]}
            aria-current={@active == :initiatives && @filters["project"] == repo["key"] && "true"}
          >
            <span class="bb-project-dot"></span>
            <span class="min-w-0 flex-1 truncate" title={repo["key"]}>{repo["key"]}</span>
            <span class="text-foreground-softer">
              {if repo["health"].state == "unreachable", do: "down", else: repo["count"]}
            </span>
          </.link>
        </section>
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
        </div>
      </aside>
      <main class="min-w-0 flex-1 space-y-5 px-5 pt-6 pb-10 lg:px-7">
        {render_slot(@inner_block)}
      </main>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  defp project_path(filters, project) do
    filters
    |> Board.Initiatives.Filters.toggle_project(project)
    |> Board.Initiatives.Filters.path()
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
