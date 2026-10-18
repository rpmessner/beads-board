defmodule Foreman.Sessions do
  @moduledoc "Board-owned planning sessions, separate from dispatched build sessions."
  import Ecto.Query
  alias Foreman.{Repo, PlanningSession, SessionMachine, SessionTmux}

  def launchable?(%{type: "epic", stage: stage}), do: stage in [:idea, :draft]

  def launchable?(%{type: type, status: status, parent: nil}) when is_binary(type),
    do: type != "epic" and status not in ["closed", "tombstone"]

  def launchable?(_), do: false

  def target(key) do
    snapshot = Foreman.Initiatives.snapshot(%{"view" => ""})
    orphan = Enum.find(snapshot.orphans, &(&1.key == key))
    epic = find_epic(snapshot.drafts ++ snapshot.epics, key)

    cond do
      orphan -> Map.put(orphan, :parent, Enum.find(orphan.edges, &(&1.type == "parent-child")))
      epic -> epic
      true -> nil
    end
  end

  def get({project, ticket}), do: Repo.get_by(PlanningSession, project: project, ticket: ticket)

  def launch({project, ticket} = key, opts \\ []) do
    with :ok <- Foreman.Preview.allow_external_write(),
         target when not is_nil(target) <- target(key),
         true <- launchable?(target),
         repo when not is_nil(repo) <-
           Enum.find(Foreman.RuntimeState.repos(), &(&1["key"] == project)),
         {:ok, workdir} <- main_checkout(repo["path"]),
         prompt when is_binary(prompt) <- opening_prompt(target, project, ticket) do
      {state, [open: :window]} = SessionMachine.step(:new, :launch, %{})
      # Reserve identity before external IO. A crash can retry with this UUID;
      # tmux's exact-name lookup recovers a window created before a DB update.
      Repo.insert!(
        %PlanningSession{
          project: project,
          ticket: ticket,
          workdir: workdir,
          state: state,
          launched_at: DateTime.utc_now()
        },
        on_conflict: :nothing,
        conflict_target: [:project, :ticket]
      )

      {:ok, result} =
        Repo.transaction(fn ->
          session = locked(key) |> observe(opts)

          if session.state == :parked do
            {:error, :session_parked}
          else
            case SessionTmux.launch(session, prompt, opts) do
              {:ok, window} ->
                session = save(session, %{window: window, error: nil}) |> observe(opts)
                {:ok, session}

              {:error, reason} ->
                save(session, %{error: error_message(reason)})
                {:error, reason}
            end
          end
        end)

      Foreman.Events.broadcast(:sessions_changed, project)
      result
    else
      false -> {:error, :not_launchable}
      nil -> {:error, :not_launchable}
      error -> error
    end
  end

  def reconcile(opts \\ []) do
    Repo.all(from s in PlanningSession, where: s.state != :parked)
    |> Enum.each(fn s ->
      Repo.transaction(fn -> locked({s.project, s.ticket}) |> observe(opts) end)
    end)

    :ok
  end

  defp observe(session, opts) do
    case SessionTmux.observe(session, opts) do
      {:ok, :window_gone} when not is_nil(session.window) ->
        transition(session, :window_gone)

      {:ok, %{window: window, state: state}} ->
        session = save(session, %{window: window})
        session = if state in [:running, :ended], do: transition(session, :started), else: session
        if state == :ended, do: transition(session, :exited), else: session

      _ ->
        session
    end
  end

  defp transition(session, event) do
    {state, []} = SessionMachine.step(session.state, event, %{})

    if state != session.state do
      result = save(session, %{state: state, observed_at: DateTime.utc_now()})
      Foreman.Events.broadcast(:sessions_changed, session.project)
      result
    else
      session
    end
  end

  defp locked({project, ticket}),
    do:
      Repo.one!(
        from s in PlanningSession,
          where: s.project == ^project and s.ticket == ^ticket,
          lock: "FOR UPDATE"
      )

  defp save(session, attrs), do: session |> Ecto.Changeset.change(attrs) |> Repo.update!()

  defp find_epic(epics, key),
    do:
      Enum.find_value(epics, fn epic ->
        if epic.key == key, do: epic, else: find_epic(Map.get(epic, :children, []), key)
      end)

  defp opening_prompt(target, project, ticket) do
    source =
      if String.starts_with?(ticket, "draft:"),
        do:
          "the board draft #{ticket}" <>
            if(target.spec_link, do: " and #{target.spec_link}", else: ""),
        else: "tickets/#{ticket}.md"

    Foreman.SessionPrompt.render(target.type, %{ticket: ticket, project: project, source: source})
  end

  defp main_checkout(path) do
    case System.cmd("git", ["-C", path, "worktree", "list", "--porcelain"],
           stderr_to_stdout: true
         ) do
      {"worktree " <> output, 0} -> {:ok, output |> String.split("\n", parts: 2) |> hd()}
      _ -> {:error, :main_checkout_unavailable}
    end
  rescue
    ErlangError -> {:error, :main_checkout_unavailable}
  end

  def error_message("refused in preview"), do: "refused in preview"
  def error_message(:not_launchable), do: "Ticket cannot be launched"
  def error_message(:session_parked), do: "Session window is gone"
  def error_message(:main_checkout_unavailable), do: "Main checkout unavailable"
  def error_message(:claude_unavailable), do: "Claude unavailable; check the web service PATH"
  def error_message(:prompt_unavailable), do: "Install the foreman skill session-launch templates"
  def error_message(_), do: "Launch failed; check tmux and retry"
end
