defmodule Foreman.Requests do
  @moduledoc "Durable asks, serialized with ticket lifecycle changes. Only kind modules may enqueue approval jobs."
  import Ecto.Query
  alias Foreman.{Repo, Overlay}
  alias Foreman.Requests.{Request, Kind, Decision}
  alias Foreman.Request, as: Machine

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

  def reconcile_open_prs do
    Repo.all(
      from r in Request, where: r.kind == "open_pr" and r.state in ["pending", "executing"]
    )
    |> Enum.each(fn request ->
      if request.state == "pending" do
        case Foreman.Requests.OpenPr.unchanged(
               request.facts,
               Foreman.Forge.adapter(),
               Foreman.Forge.options()
             ) do
          {:error, reason} when reason in [:head_moved, :head_missing] ->
            resolve(request.id, :facts_changed, %{"reason" => to_string(reason)})

          _ ->
            :ok
        end
      else
        active =
          Repo.exists?(
            from j in Oban.Job,
              where:
                j.worker == "Foreman.Requests.OpenPrJob" and
                  fragment("?->>'request_id'", j.args) == ^request.id and
                  j.state in ["available", "scheduled", "executing", "retryable"]
          )

        if not active or DateTime.diff(DateTime.utc_now(), request.updated_at) > 90,
          do: resolve(request.id, :orphaned, %{})
      end
    end)

    :ok
  end

  def reconcile_pushes do
    requests =
      Repo.all(from r in Request, where: r.kind == "push" and r.state in ["pending", "executing"])

    Enum.each(requests, fn request ->
      cond do
        request.state == "pending" and Foreman.Requests.Push.unchanged(request.facts) != :ok ->
          resolve(request.id, :facts_changed, %{"reason" => "local_sha_changed"})

        request.state == "executing" ->
          active =
            Repo.exists?(
              from j in Oban.Job,
                where:
                  j.worker == "Foreman.Requests.PushJob" and
                    fragment("?->>'request_id'", j.args) == ^request.id and
                    j.state in ["available", "scheduled", "executing", "retryable"]
            )

          if not active or DateTime.diff(DateTime.utc_now(), request.updated_at) > 90,
            do: resolve(request.id, :orphaned, %{})

        true ->
          :ok
      end
    end)

    :ok
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
        %{machine: Foreman.Epic} -> Enum.reject([row.bead_id, row.beads_epic_id], &is_nil/1)
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

          changed = approval_change(request, event)

          if changed do
            transition(request, :facts_changed, %{"reason" => changed})
          else
            transition(request, event, payload)
          end
      end
    end)
  end

  defp approval_change(%{kind: "push", state: "pending"} = request, :approve) do
    if Foreman.Requests.Push.unchanged(request.facts) != :ok, do: "local_sha_changed"
  end

  defp approval_change(%{kind: "open_pr", state: "pending"} = request, :approve) do
    case Foreman.Requests.OpenPr.observed_head(request.repo_key, request.facts) do
      {:error, reason} when reason in [:head_moved, :head_missing] -> to_string(reason)
      _ -> nil
    end
  end

  defp approval_change(_, _), do: nil

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
            note: Map.get(payload, "note", request.note)
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
        "foreman:overlay:" <> repo
      ])

  defp notify(request), do: Foreman.Events.broadcast(:requests_changed, request.id)

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
