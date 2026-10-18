defmodule BoardWeb.PullRequestsLive do
  use BoardWeb, :live_view
  alias Fluxon.Components.{Badge, Button}

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Board.Events.subscribe()
      Process.send_after(self(), :reconcile, 3_000)
    end

    {:ok, assign(socket, page_title: "Pull requests", project: nil, refresh_state: :idle)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {state, []} = Board.Forge.RefreshStatus.step(socket.assigns.refresh_state, :cancel, %{})
    socket = socket |> assign(refresh_state: state) |> clear_flash(:info)

    {:noreply,
     socket
     |> assign(project: params["project"])
     |> BoardWeb.TicketDetail.load(params, uri)
     |> refresh()}
  end

  @impl true
  def handle_info(:reconcile, socket) do
    Process.send_after(self(), :reconcile, 3_000)
    {:noreply, refresh(socket)}
  end

  def handle_info({:notification, :board_events, _}, socket), do: {:noreply, refresh(socket)}

  @impl true
  def handle_event("refresh", _, socket) do
    {state, [status: :refreshing]} =
      Board.Forge.RefreshStatus.step(socket.assigns.refresh_state, :request, %{})

    socket = socket |> assign(refresh_state: state) |> put_flash(:info, "Refreshing")

    if socket.assigns.panel && Board.Forge.SyncJob.due?(socket.assigns.stored, true) do
      Board.Events.broadcast(:forge_requested, socket.assigns.project)
      {:noreply, socket}
    else
      status =
        case socket.assigns.stored do
          %{error: "rate_limited"} -> "Rate limited"
          %{error: error} when not is_nil(error) -> "Refresh failed"
          _ -> "Up to date"
        end

      {:noreply, finish_refresh(socket, status)}
    end
  end

  def handle_event("close-ticket", params, socket),
    do: {:noreply, BoardWeb.TicketDetail.close(socket, params)}

  defp refresh(socket) do
    repos = Board.RuntimeState.repos()
    project = socket.assigns.project || (Enum.find(repos, &remote?/1) || %{})["key"]
    repo = Enum.find(repos, &(&1["key"] == project))
    panel = repo && remote?(repo)
    stored = if panel, do: Board.Forge.Store.get(project)
    stored = if stored && stored.remote == repo["github"], do: stored
    snapshot = (stored && stored.snapshot) || %{}
    prs = Board.Forge.Stack.order(snapshot["change_requests"] || [], snapshot["default_branch"])
    previous = Map.get(socket.assigns, :stored)

    socket =
      if stored && (!previous || stored.attempted_at != previous.attempted_at) do
        finish_refresh(socket, if(stored.error, do: "Refresh failed", else: "Updated"))
      else
        socket
      end

    socket
    |> assign(
      repos: repos,
      project: project,
      panel: panel,
      stored: stored,
      default_branch: snapshot["default_branch"],
      count: length(prs)
    )
    |> stream(:projects, Enum.map(repos, &%{id: &1["key"], repo: &1}), reset: true)
    |> stream(:prs, Enum.map(prs, &Map.put(&1, :id, "cr-#{project}-#{&1["number"]}")),
      reset: true,
      dom_id: & &1.id
    )
    |> BoardWeb.TicketDetail.refresh()
  end

  defp finish_refresh(socket, status) do
    {state, effects} =
      Board.Forge.RefreshStatus.step(socket.assigns.refresh_state, :complete, %{})

    socket = assign(socket, refresh_state: state)
    if effects == [status: :result], do: put_flash(socket, :info, status), else: socket
  end

  defp remote?(repo),
    do: repo["enabled"] && repo["forge"] == "github" && is_binary(repo["github"])

  defp status(%{"detached" => true}), do: "Detached base"
  defp status(%{"parent" => parent}) when not is_nil(parent), do: "Waiting on ##{parent}"
  defp status(%{"draft" => true}), do: "Draft"
  defp status(%{"mergeable" => "conflicting"}), do: "Conflicts"

  defp status(%{"checks" => checks}) when checks not in ["success", "none"],
    do: "Checks: #{checks}"

  defp status(%{"mergeable" => "mergeable"}), do: "Ready · read-only"
  defp status(_), do: "Mergeability unknown"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:pull_requests} repos={@repos}>
      <header class="flex flex-wrap items-center gap-3">
        <div class="mr-auto space-y-1">
          <h1 class="text-[22px] leading-7 font-semibold">Pull requests</h1>
        </div>
        <Button.button :if={@panel} id="forge-refresh" phx-click="refresh" variant="outline" size="sm">
          <.icon name="hero-arrow-path" class="size-4" /> Refresh
        </Button.button>
      </header>
      <nav
        id="forge-projects"
        phx-update="stream"
        class="flex flex-wrap gap-x-5 border-b border-base"
        aria-label="Pull request projects"
      >
        <.link
          :for={{id, item} <- @streams.projects}
          id={id}
          patch={~p"/pull-requests?project=#{item.repo["key"]}"}
          class={[
            "flex items-center gap-2 border-b-2 py-3 text-sm",
            if(@project == item.repo["key"],
              do: "border-primary font-medium",
              else: "border-transparent text-foreground-softer"
            )
          ]}
          aria-current={@project == item.repo["key"] && "page"}
        >
          {item.repo["key"]}
          <span :if={!remote?(item.repo)} class="text-xs">no remote</span>
        </.link>
      </nav>
      <section :if={@panel} id="forge-panel" class="space-y-4">
        <div class="flex flex-wrap items-center gap-3 text-xs text-foreground-softer">
          <span class="bb-label">Stack on {@default_branch || "default branch"}</span>
          <Badge.badge :if={@default_branch} class="font-mono">{@default_branch}</Badge.badge>
          <span>{@count} open</span>
          <span :if={@stored && @stored.synced_at} id="forge-synced" class="ml-auto">
            Synced <BoardWeb.TicketDetail.timestamp at={@stored.synced_at} />
          </span>
        </div>
        <div :if={!@stored} id="forge-waiting" class="bb-panel text-foreground-softer">
          Awaiting sync
        </div>
        <div
          :if={@stored && @stored.error}
          id="forge-error"
          role="status"
          class="bb-panel text-foreground-softer"
        >
          Sync failed · {@stored.error}
        </div>
        <div id="pull-requests" phx-update="stream" class="space-y-3">
          <div
            id="prs-empty"
            class="hidden rounded-xl border border-base p-8 text-center text-foreground-softer only:block"
          >
            No open pull requests
          </div>
          <article
            :for={{id, pr} <- @streams.prs}
            id={id}
            data-number={pr["number"]}
            class="flex gap-3"
            style={"padding-left: #{min(pr["depth"], 5) * 28}px"}
          >
            <div
              aria-hidden="true"
              class="mt-1 h-10 w-4 shrink-0 rounded-bl-lg border-b-2 border-l-2 border-base"
            >
            </div>
            <div class="bb-panel flex min-w-0 flex-1 flex-wrap items-center gap-4 !p-4">
              <div class="w-full min-w-0 space-y-2 md:w-auto md:flex-1">
                <a
                  href={pr["url"]}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="block font-medium break-words hover:underline"
                >
                  <span class="mr-2 font-mono text-xs text-foreground-softer">#{pr["number"]}</span>{pr[
                    "title"
                  ]}
                </a>
                <div class="flex flex-wrap items-center gap-1.5">
                  <Badge.badge class="max-w-full font-mono">
                    <span class="truncate">{pr["source_branch"]} → {pr["target_branch"]}</span>
                  </Badge.badge>
                  <Badge.badge class="font-mono">
                    {String.slice(pr["head_sha"] || "", 0, 7)}
                  </Badge.badge>
                  <Badge.badge>checks: {pr["checks"]}</Badge.badge>
                  <.link
                    :for={link <- pr["links"] || []}
                    patch={Board.TicketSheet.path(@page_uri, {@project, link["bead_id"]})}
                    data-bead={link["bead_id"]}
                    title={"Source: #{link["source"]}"}
                  >
                    <Badge.badge color="info" class="font-mono">{link["bead_id"]}</Badge.badge>
                  </.link>
                </div>
              </div>
              <span data-parent={pr["parent"]}>
                <Badge.badge>{status(pr)}</Badge.badge>
              </span>
            </div>
          </article>
        </div>
      </section>
      <p :if={!@panel} id="forge-no-remote" class="text-foreground-softer">
        No remote
      </p>
      <BoardWeb.TicketDetail.sheet
        ticket={@ticket}
        state={@sheet_state}
        return_to={@sheet_return}
        streams={@streams}
      />
    </Layouts.app>
    """
  end
end
