defmodule Board.CLI do
  @moduledoc "Agent escript: offline ticket files plus best-effort server-backed overlay commands."
  @ticket %{
    "dispatch" => "dispatch",
    "progress" => "progress",
    "report" => "report",
    "review" => "review",
    "changes" => "request_changes",
    "commit" => "commit",
    "abandon" => "abandon",
    "revive" => "revive"
  }
  @epic %{
    "create" => "create",
    "spec" => "start_spec",
    "approve" => "approve_spec",
    "ticket" => "ticket",
    "abandon" => "abandon",
    "revive" => "revive"
  }
  @switches [
    json: :boolean,
    actor: :string,
    session: :string,
    project: :string,
    repo: :string,
    window: :string,
    harness: :string,
    model: :string,
    workdir: :string,
    branch: :string,
    base: :string,
    brief: :string,
    report: :string,
    path: :string,
    sha: :string,
    title: :string,
    spec: :string,
    beads_epic_id: :string,
    epic: :string,
    epic_project: :string,
    stage: :string
  ]

  def main(args) do
    # Postgres connection supervisors may exit asynchronously. They must not
    # propagate a linked exit into the agent-facing escript.
    Process.flag(:trap_exit, true)
    # Do not boot Board.Application: an agent must not become a web/worker node.
    Application.ensure_all_started(:req)
    Application.ensure_all_started(:postgrex)
    Logger.configure(level: :emergency)
    System.halt(run(args))
  end

  def run(args, opts \\ []) do
    if Board.TicketCLI.command?(args, opts) do
      Board.TicketCLI.run(args, opts)
    else
      run_overlay(List.delete(args, "--overlay"), opts)
    end
  rescue
    _ -> warn(args, "board unavailable; agent may continue")
  catch
    :exit, _ -> warn(args, "board unavailable; agent may continue")
  end

  defp run_overlay(args, opts) do
    case parse(args) do
      {:ok, %{request: request, json: json?}} ->
        request = Map.put(request, "request_id", Ecto.UUID.generate())
        {code, body} = Board.CLITransport.deliver(request, opts)
        if json?, do: IO.puts(Jason.encode!(body)), else: IO.puts(format(body))
        code

      {:error, _} ->
        warn(args, "usage: board <verb> <id> [options]; see docs/sessions/bb-cli.md")
    end
  rescue
    _ -> warn(args, "board unavailable; agent may continue")
  catch
    :exit, _ -> warn(args, "board unavailable; agent may continue")
  end

  defp warn(args, message) do
    if "--json" in args,
      do: IO.puts(Jason.encode!(%{warning: message})),
      else: IO.puts("warning: " <> message)

    0
  end

  defp format(%{"warning" => warning}), do: "warning: " <> warning

  defp format(%{"stage" => stage, "allowed" => allowed}),
    do: "stage: #{stage}; allowed: #{Enum.join(allowed, ", ")}"

  defp format(%{"stage" => stage}), do: "stage: #{stage}"
  defp format(body), do: Jason.encode!(body)

  def parse(args, defaults \\ []) do
    {opts, args, invalid} = OptionParser.parse(args, strict: @switches)

    {kind, args} =
      case args do
        ["epic" | rest] -> {"epic", rest}
        rest -> {"ticket", rest}
      end

    case {invalid, args} do
      {[], [verb | rest]} ->
        event = if(kind == "epic", do: @epic, else: @ticket)[verb]
        read_or_link = kind == "ticket" and verb in ~w(show ls attach detach)

        valid_args =
          (verb == "ls" and rest == []) or length(rest) == 1 or
            (verb in ~w(progress changes) and length(rest) == 2)

        if (event || read_or_link) && valid_args do
          id = List.first(rest)

          id =
            if kind == "epic" and verb == "create" and not String.starts_with?(id, "draft:"),
              do: "draft:" <> id,
              else: id

          payload =
            Map.new(
              Keyword.take(opts, [
                :window,
                :harness,
                :model,
                :workdir,
                :branch,
                :base,
                :brief,
                :report,
                :path,
                :sha,
                :title,
                :beads_epic_id
              ]),
              fn {k, v} -> {to_string(k), v} end
            )

          payload = if opts[:spec], do: Map.put(payload, "spec_link", opts[:spec]), else: payload

          payload =
            if length(rest) == 2, do: Map.put(payload, "body", List.last(rest)), else: payload

          request = %{
            "action" => if(event, do: "event", else: verb),
            "kind" => kind,
            "event" => event,
            "id" => id,
            "payload" => payload,
            "actor" => opts[:actor] || defaults[:actor] || System.get_env("BOARD_ACTOR", "user"),
            "session" => opts[:session] || defaults[:session] || System.get_env("BOARD_SESSION"),
            "project" => opts[:project] || opts[:repo],
            "cwd" => defaults[:cwd] || File.cwd!(),
            "epic" => opts[:epic],
            "epic_project" => opts[:epic_project],
            "stage" => opts[:stage]
          }

          {:ok, %{request: request, json: opts[:json] || false}}
        else
          {:error, :usage}
        end

      _ ->
        {:error, :usage}
    end
  end
end
