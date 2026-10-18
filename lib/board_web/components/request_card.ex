defmodule BoardWeb.RequestCard do
  use BoardWeb, :html
  alias Fluxon.Components.Badge
  attr :id, :string, required: true
  attr :request, :any, required: true

  def summary(assigns) do
    ~H"""
    <article id={@id} class="space-y-2 rounded-lg border border-base p-4">
      <div class="flex flex-wrap items-center gap-2 text-xs text-foreground-softer">
        <Badge.badge>{@request.state}</Badge.badge>
        <span class="font-mono">{@request.bead_id}</span>
        <span>{@request.actor}</span>
        <span class="ml-auto"><BoardWeb.TicketDetail.timestamp at={@request.updated_at} /></span>
      </div>
      <p class="break-words font-medium">{@request.facts["question"]}</p>
      <p :if={@request.outcome["answer"]} class="whitespace-pre-wrap break-words" phx-no-format>{@request.outcome["answer"]}</p>
      <p
        :if={@request.note not in [nil, "", @request.outcome["answer"]]}
        class="whitespace-pre-wrap break-words text-foreground-softer"
        phx-no-format
      >{@request.note}</p>
      <p :if={@request.outcome["reason"]} class="text-foreground-softer">
        {String.replace(@request.outcome["reason"], "_", " ")}
      </p>
    </article>
    """
  end
end
