defmodule Board.Requests do
  @moduledoc "Durable asks, serialized with ticket lifecycle changes. Only kind modules may enqueue approval jobs."
  import Ecto.Query
  alias Board.{Repo, Overlay}
  alias Board.Requests.{Request, Kind, Decision}
  alias Board.Request, as: Machine

  def ask({repo, _} = key, kind, params) when is_map(params) do
    transaction(fn ->
      lock(repo)

      with {:ok, handler} <- Kind.fetch(kind),
           row when not is_nil(row) <- Overlay.get(key),
           true <- row.stage not in [:done, :abandoned],
           true <- Decision.text?(params["actor"] || "user"),
           true <- is_nil(params["session"]) or Decision.text?(params["session"]),
           {:ok, facts} <- handler.validate(params["facts"], row),
           {:ok, id} <- Ecto.UUID.cast(params["request_id"] || Ecto.UUID.generate()) do
        {:pending, effects} = Machine.step(:new, :ask, %{kind: kind})

        request =
          Repo.insert!(%Request{
            id: id,
            repo_key: repo,
            bead_id: row.bead_id,
            kind: kind,
            actor: params["actor"] || "user",
            session: params["session"],
            facts: facts,
            state: "pending"
          })

        audit(request, :new, :ask, %{}, effects)
        notify(request)
        {:ok, request}
      else
        nil -> {:error, :not_found}
        false -> {:error, :ticket_finished}
        :error -> {:error, :invalid_request_id}
        error -> error
      end
    end)
  end

  def get(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get(Request, id)
      _ -> nil
    end
  end

  def pending_count, do: Repo.aggregate(from(r in Request, where: r.state == "pending"), :count)

  def pending,
    do: Repo.all(from r in Request, where: r.state == "pending", order_by: [r.inserted_at, r.id])

  def recent,
    do:
      Repo.all(
        from r in Request,
          where: r.state not in ["pending", "approved", "executing"],
          order_by: [desc: r.updated_at, desc: r.id],
          limit: 50
      )

  def for_ticket({repo, id}) do
    row = Overlay.get({repo, id})

    ids =
      case row do
        %{machine: Board.Epic} -> Enum.reject([row.bead_id, row.beads_epic_id], &is_nil/1)
        _ -> [id]
      end

    Repo.all(
      from r in Request,
        where: r.repo_key == ^repo and r.bead_id in ^ids,
        order_by: [desc: r.inserted_at, desc: r.id]
    )
  end

  @doc "Internal interpreter. HTTP agents cannot submit worker or observed events."
  def resolve(id, event, payload) when is_map(payload) do
    transaction(fn ->
      case get(id) do
        nil ->
          {:error, :not_found}

        request ->
          lock(request.repo_key)
          request = Repo.get!(Request, id)
          transition(request, event, payload)
      end
    end)
  end

  def supersede(key) do
    for request <- for_ticket(key), request.state == "pending" do
      transition(request, :facts_changed, %{"reason" => "ticket_finished"})
    end

    :ok
  end

  defp transition(request, event, payload) do
    state = Enum.find(Machine.__fsm__(:states), &(to_string(&1) == request.state))

    with :ok <- validate(event, payload),
         {next, effects} when next != :error <- Machine.step(state, event, %{kind: request.kind}) do
      if next == state do
        {:ok, request}
      else
        outcome =
          case event do
            :answer -> Map.take(payload, ["answer"])
            :orphaned -> %{"reason" => "outcome unknown"}
            _ -> Map.take(payload, ["reason", "result"])
          end

        request =
          request
          |> Ecto.Changeset.change(
            state: to_string(next),
            outcome: outcome,
            note: payload["note"]
          )
          |> Repo.update!()

        audit(request, state, event, payload, effects)

        if {:enqueue, :job} in effects do
          with {:ok, handler} <- Kind.fetch(request.kind), :ok <- handler.enqueue(request) do
            :ok
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end

        notify(request)
        {:ok, request}
      end
    else
      {:error, _} -> {:error, :invalid}
    end
  end

  defp validate(:answer, payload) do
    if Decision.text?(payload["answer"]), do: :ok, else: {:error, :answer_required}
  end

  defp validate(_, payload) do
    if is_nil(payload["note"]) or
         (is_binary(payload["note"]) and byte_size(payload["note"]) <= 20_000),
       do: :ok,
       else: {:error, :invalid_note}
  end

  defp transaction(fun) do
    case Repo.transaction(fun) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  defp lock(repo),
    do:
      Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
        "board:overlay:" <> repo
      ])

  defp notify(request), do: Board.Events.broadcast(:requests_changed, request.id)

  defp audit(request, from, event, payload, effects) do
    Repo.insert_all("request_events", [
      %{
        request_id: Ecto.UUID.dump!(request.id),
        event: to_string(event),
        from_state: to_string(from),
        to_state: request.state,
        payload: payload,
        effects: %{items: Enum.map(effects, fn {k, v} -> %{kind: k, name: v} end)},
        inserted_at: DateTime.utc_now()
      }
    ])
  end
end
