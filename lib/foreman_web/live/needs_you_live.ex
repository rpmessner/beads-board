defmodule ForemanWeb.NeedsYouLive do
  use ForemanWeb, :live_view
  alias Foreman.Requests
  alias Fluxon.Components.{Button, Badge}

  def mount(_, _, socket) do
    if connected?(socket), do: Process.send_after(self(), :reconcile, 3_000)

    {:ok,
     socket
     |> assign(:pending_ids, MapSet.new())
     |> stream_configure(:pending, dom_id: &("request-" <> &1.id))
     |> stream(:pending, [])
     |> refresh()}
  end

  def handle_params(params, uri, socket),
    do: {:noreply, ForemanWeb.TicketDetail.load(socket, params, uri)}

  def handle_event("resolve", %{"id" => id, "decision" => params, "action" => "approve"}, socket) do
    {:noreply, result(socket, Requests.resolve(id, :approve, %{"note" => params["note"]}))}
  end

  def handle_event("resolve", %{"id" => id, "decision" => params, "action" => "answer"}, socket) do
    answer = if params["choice"] in [nil, ""], do: params["note"], else: params["choice"]
    result = Requests.resolve(id, :answer, %{"answer" => answer, "note" => params["note"]})
    {:noreply, result(socket, result)}
  end

  def handle_event("resolve", %{"id" => id, "decision" => params, "action" => "decline"}, socket) do
    {:noreply, result(socket, Requests.resolve(id, :decline, %{"note" => params["note"]}))}
  end

  def handle_event("close-ticket", params, socket),
    do: {:noreply, ForemanWeb.TicketDetail.close(socket, params)}

  def handle_info(:reconcile, socket) do
    Process.send_after(self(), :reconcile, 3_000)
    {:noreply, socket |> refresh() |> ForemanWeb.TicketDetail.refresh()}
  end

  def handle_info({:notification, :foreman_events, _}, socket),
    do: {:noreply, socket |> refresh() |> ForemanWeb.TicketDetail.refresh()}

  defp result(socket, {:ok, _}), do: refresh(socket)

  defp result(socket, {:error, _}),
    do: socket |> put_flash(:error, "Request not updated") |> refresh()

  defp refresh(socket) do
    pending = Requests.pending()
    ids = MapSet.new(pending, & &1.id)
    previous = socket.assigns.pending_ids

    # Pending facts are immutable. Leave existing cards mounted so reconciliation
    # cannot erase an answer or note the user is still composing.
    socket =
      Enum.reduce(MapSet.difference(previous, ids), socket, fn id, socket ->
        stream_delete_by_dom_id(socket, :pending, "request-" <> id)
      end)

    socket =
      pending
      |> Enum.with_index()
      |> Enum.reduce(socket, fn {request, index}, socket ->
        if MapSet.member?(previous, request.id),
          do: socket,
          else: stream_insert(socket, :pending, request, at: index)
      end)

    socket
    |> assign(:pending_ids, ids)
    |> ForemanWeb.RequestCount.refresh()
    |> stream(:recent, Requests.recent(), reset: true)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} pending_count={@pending_count} active={:needs_you}>
      <header id="inbox-heading" class="flex items-center gap-3">
        <h1 class="text-xl font-semibold">Needs you</h1>
        <Badge.badge :if={@pending_count > 0}>{@pending_count}</Badge.badge>
      </header>
      <div id="pending-requests" phx-update="stream" class="max-w-3xl space-y-5">
        <div
          id="inbox-empty"
          class="hidden only:block rounded-xl border border-dashed border-base p-10 text-center text-foreground-softer"
        >
          No pending requests
        </div>
        <.request_card :for={{id, request} <- @streams.pending} id={id} request={request} />
      </div>
      <details id="recent-outcomes" class="max-w-3xl border-t border-base pt-4">
        <summary class="cursor-pointer text-sm font-medium text-foreground-softer">
          Recent outcomes
        </summary>
        <div id="recent-requests" phx-update="stream" class="mt-4 space-y-3">
          <ForemanWeb.RequestCard.summary
            :for={{id, request} <- @streams.recent}
            id={id}
            request={request}
          />
        </div>
      </details>
      <ForemanWeb.TicketDetail.sheet
        ticket={@ticket}
        state={@sheet_state}
        return_to={@sheet_return}
        streams={@streams}
        tab={@ticket_tab}
        uri={@page_uri}
      />
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :request, :any, required: true

  def request_card(%{request: %{kind: "push"}} = assigns), do: push_card(assigns)
  def request_card(assigns), do: decision_card(assigns)

  attr :id, :string, required: true
  attr :request, :any, required: true

  def push_card(assigns) do
    assigns = assign(assigns, :form, to_form(%{"note" => ""}, as: :decision))

    ~H"""
    <article id={@id} class="rounded-xl border border-base bg-base p-5 shadow-sm sm:p-6">
      <div class="mb-4 flex flex-wrap items-center gap-2 text-xs text-foreground-softer">
        <Badge.badge>Push</Badge.badge>
        <.link
          patch={"/needs-you?" <> URI.encode_query(%{"ticket" => @request.repo_key <> ":" <> @request.bead_id})}
          class="font-mono hover:underline"
        >
          {@request.bead_id}
        </.link>
        <span>{@request.actor}<span :if={@request.session}> · {@request.session}</span></span>
        <span class="ml-auto"><ForemanWeb.TicketDetail.timestamp at={@request.inserted_at} /></span>
      </div>
      <ForemanWeb.RequestCard.push_facts request={@request} />
      <.form
        for={@form}
        id={"push-" <> @request.id}
        phx-submit="resolve"
        phx-value-id={@request.id}
        class="mt-5 space-y-4"
      >
        <.input
          field={@form[:note]}
          id={"push-note-" <> @request.id}
          type="textarea"
          label="Note"
          rows="2"
          class="mt-2 block w-full rounded-lg border border-base bg-sunken px-3 py-2 text-foreground outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/20"
        />
        <div class="flex gap-2">
          <Button.button
            id={"submit-approve-" <> @request.id}
            type="submit"
            name="action"
            value="approve"
            variant="solid"
            color="primary"
          >
            Approve
          </Button.button>
          <Button.button
            id={"submit-decline-" <> @request.id}
            type="submit"
            name="action"
            value="decline"
          >
            Decline
          </Button.button>
        </div>
      </.form>
    </article>
    """
  end

  attr :id, :string, required: true
  attr :request, :any, required: true

  def decision_card(assigns) do
    assigns =
      assign(
        assigns,
        :form,
        to_form(%{"note" => "", "choice" => ""}, as: :decision)
      )

    ~H"""
    <article id={@id} class="rounded-xl border border-base bg-base p-5 shadow-sm sm:p-6">
      <div class="mb-4 flex flex-wrap items-center gap-2 text-xs text-foreground-softer">
        <Badge.badge>Decision</Badge.badge>
        <.link
          patch={"/needs-you?" <> URI.encode_query(%{"ticket" => @request.repo_key <> ":" <> @request.bead_id})}
          class="font-mono hover:underline"
        >
          {@request.bead_id}
        </.link>
        <span>{@request.actor}<span :if={@request.session}> · {@request.session}</span></span>
        <span class="ml-auto"><ForemanWeb.TicketDetail.timestamp at={@request.inserted_at} /></span>
      </div>
      <h2 class="break-words text-lg font-semibold">{@request.facts["question"]}</h2>
      <p
        :if={@request.facts["text"]}
        class="mt-2 whitespace-pre-wrap break-words text-foreground-softer"
        phx-no-format
      >{@request.facts["text"]}</p>
      <.form
        for={@form}
        id={"decision-" <> @request.id}
        phx-submit="resolve"
        phx-value-id={@request.id}
        class="mt-5 space-y-4"
      >
        <fieldset :if={@request.facts["options"] != []} class="space-y-2">
          <legend class="sr-only">Options</legend>
          <label
            :for={{option, index} <- Enum.with_index(@request.facts["options"])}
            data-recommended={to_string(option == @request.facts["recommendation"])}
            class="flex cursor-pointer items-center gap-3 rounded-lg border border-base px-3 py-3 hover:bg-sunken has-[:checked]:border-primary has-[:checked]:bg-sunken"
          >
            <input
              id={"option-#{@request.id}-#{index}"}
              type="radio"
              name="decision[choice]"
              value={option}
              class="size-4 shrink-0 accent-current"
            />
            <span class="min-w-0 flex-1 break-words">{option}</span>
            <span
              :if={option == @request.facts["recommendation"]}
              class="text-xs text-foreground-softer"
            >
              Recommended
            </span>
          </label>
        </fieldset>
        <.input
          field={@form[:note]}
          id={"decision-note-" <> @request.id}
          type="textarea"
          label="Note"
          rows="2"
          class="mt-2 block w-full rounded-lg border border-base bg-sunken px-3 py-2 text-foreground outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/20"
        />
        <div id={"decision-actions-" <> @request.id} class="flex gap-3">
          <Button.button
            type="submit"
            name="action"
            value="answer"
            id={"submit-answer-" <> @request.id}
            variant="solid"
          >
            Answer
          </Button.button>
          <Button.button
            type="submit"
            name="action"
            value="decline"
            id={"submit-decline-" <> @request.id}
          >
            Decline
          </Button.button>
        </div>
      </.form>
    </article>
    """
  end
end
