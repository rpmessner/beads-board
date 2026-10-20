defmodule ForemanWeb.DocumentPanel do
  @moduledoc "Shared document panel and URL executor for ticket surfaces."
  use ForemanWeb, :html
  import Phoenix.LiveView, only: [push_patch: 2]
  alias Foreman.DocumentPanel
  alias Fluxon.Components.Sheet

  def load(socket, params) do
    {event, doc} =
      case DocumentPanel.key(params["doc"]) do
        nil when not is_map_key(params, "doc") -> {:close, nil}
        nil -> {:missing, %{repo: "", path: ""}}
        {repo, path} -> document(repo, path, params["doc_source"])
      end

    {state, []} =
      DocumentPanel.step(Map.get(socket.assigns, :document_state, :closed), event, %{})

    doc = if state == :closed, do: Map.get(socket.assigns, :panel_doc), else: doc
    assign(socket, document_state: state, panel_doc: doc)
  end

  def open(socket, %{"href" => href}) do
    case DocumentPanel.link_params(href) do
      nil -> socket
      params -> push_patch(socket, to: DocumentPanel.path(socket.assigns.page_uri, params))
    end
  end

  def close(%{assigns: %{document_state: :closed}} = socket), do: socket
  def close(socket), do: push_patch(socket, to: DocumentPanel.path(socket.assigns.page_uri))

  defp document(repo_key, path, source) do
    repo = Enum.find(Foreman.CardText.repos(), &(&1["key"] == repo_key))

    # Only configured roots here. Worktree sources must be explicitly validated
    # by the source resolver before they can supply a root.
    result =
      with true <- is_nil(source),
           %{"path" => root} <- repo,
           false <- ".." in Path.split(path),
           true <- Foreman.Documents.document?(root, path) do
        Foreman.Documents.read(root, path)
      end

    case result do
      {:ok, doc} ->
        html =
          Foreman.Markdown.render(doc.content, repo: repo_key, path: doc.path, header_ids: false)

        {:open, %{repo: repo_key, path: doc.path, html: html}}

      _ ->
        {:missing, %{repo: repo_key, path: path}}
    end
  end

  attr :id, :string, required: true
  attr :state, :atom, required: true
  attr :doc, :any, required: true
  attr :uri, :string, required: true
  slot :inner_block, required: true

  def surface(assigns) do
    ~H"""
    <div id={@id} phx-hook=".CardDocLinks" class="min-w-0 space-y-5">
      {render_slot(@inner_block)}
      <Sheet.sheet
        id="document-sheet"
        open={@state != :closed}
        placement="right"
        class="w-[min(760px,100vw)] space-y-6 scroll-pt-6 [scrollbar-gutter:stable]"
        hide_close_button
        on_close={JS.push("close-document")}
      >
        <section
          :if={@doc}
          id={if(@state != :closed, do: "card-panel")}
          aria-label="Document"
          class="space-y-6"
        >
          <header class="flex items-center gap-3 text-xs text-foreground-softer">
            <span>{@doc.repo}</span>
            <span
              id="document-heading"
              class="min-w-0 flex-1 break-all font-mono"
              title={@doc.path}
              phx-mounted={
                JS.set_attribute({"aria-label", "Document"}, to: "#document-sheet [role=dialog]")
              }
            >
              {@doc.path}
            </span>
            <a
              :if={Map.has_key?(@doc, :html)}
              id="panel-open-viewer"
              data-viewer
              href={Foreman.Markdown.viewer_path(@doc.repo, @doc.path)}
              class="shrink-0 rounded p-2 hover:bg-sunken"
            >
              Open in viewer
            </a>
            <.link
              id="panel-close"
              patch={DocumentPanel.path(@uri)}
              class="rounded p-2 hover:bg-sunken"
              aria-label="Close document"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </.link>
          </header>
          <div
            :if={Map.has_key?(@doc, :html)}
            id={if(@state == :open, do: "panel-document")}
            class="fm-markdown"
          >
            {Phoenix.HTML.raw(@doc.html)}
          </div>
          <p
            :if={!Map.has_key?(@doc, :html)}
            id={if(@state == :unavailable, do: "panel-status")}
            class="py-6 text-foreground-softer"
          >
            Document unavailable
          </p>
        </section>
      </Sheet.sheet>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".CardDocLinks">
      export default {
        mounted() {
          this.onClick = (event) => {
            const link = event.target.closest("a[href^='/documents/']:not([data-viewer])")
            const modified = event.metaKey || event.ctrlKey || event.shiftKey || event.altKey
            if (!link || event.defaultPrevented || event.button !== 0 || modified) return
            event.preventDefault()
            event.stopPropagation()
            this.pushEvent("open-doc", {href: link.getAttribute("href")})
          }
          this.el.addEventListener("click", this.onClick)
        },
        destroyed() {
          this.el.removeEventListener("click", this.onClick)
        }
      }
    </script>
    """
  end
end
