defmodule Foreman.Spool do
  @moduledoc "Durable, ordered delivery. A global advisory lock serializes replay workers."
  import Ecto.Query
  alias Foreman.Repo

  def enqueue(%{"request_id" => id} = request) do
    Repo.insert_all("spooled_events", [%{request_id: Ecto.UUID.dump!(id), request: request}],
      on_conflict: :nothing
    )

    :ok
  end

  def replay(limit \\ 100) do
    Enum.reduce_while(1..limit, :ok, fn _, :ok ->
      case replay_one() do
        :continue -> {:cont, :ok}
        :stop -> {:halt, :ok}
      end
    end)
  end

  defp replay_one do
    {:ok, result} =
      Repo.transaction(
        fn ->
          %{rows: [[locked]]} =
            Repo.query!("SELECT pg_try_advisory_xact_lock(hashtextextended('foreman:spool', 0))")

          if locked do
            case Repo.one(
                   from s in "spooled_events",
                     where: s.state == "pending",
                     order_by: s.id,
                     limit: 1,
                     lock: "FOR UPDATE",
                     select: %{id: s.id, request: s.request}
                 ) do
              nil ->
                :stop

              row ->
                {status, body} = Foreman.AgentCommands.execute(row.request)

                event =
                  cond do
                    status == 200 -> :accept
                    status == 404 or status >= 500 -> :retry
                    true -> :reject
                  end

                {state, effects} = Foreman.SpoolMachine.step(:pending, event, %{})

                Enum.each(effects, fn {:save, :receipt} ->
                  Repo.update_all(from(s in "spooled_events", where: s.id == ^row.id),
                    set: [state: to_string(state), result: %{status: status, body: body}]
                  )
                end)

                if state == :pending, do: :stop, else: :continue
            end
          else
            :stop
          end
        end,
        timeout: 40_000
      )

    result
  end
end
