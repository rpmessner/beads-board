defmodule Foreman.SessionTmux do
  @moduledoc "Non-destructive tmux adapter. Targets are resolved by exact names, then addressed by tmux IDs. No kill command is exposed."

  def launch(session, prompt, opts \\ []) do
    with :ok <- Foreman.Preview.allow_external_write(),
         :ok <- validate(session),
         {:ok, windows} <- windows(opts) do
      case Enum.find(windows, &(&1.project == session.project and &1.ticket == session.ticket)) do
        nil ->
          create(session, prompt, windows, opts)

        window ->
          with {:ok, _} <- cmd(["select-window", "-t", window.window], opts),
               do: {:ok, window.window}
      end
    end
  end

  def observe(session, opts \\ []) do
    with {:ok, windows} <- windows(opts) do
      case Enum.find(windows, &(&1.project == session.project and &1.ticket == session.ticket)) do
        nil -> {:ok, :window_gone}
        w -> {:ok, %{window: w.window, state: w.state}}
      end
    end
  end

  def attach_command(session, opts \\ []) do
    "tmux -L #{quote_arg(socket(opts))} attach -t #{quote_arg(session.project <> ":" <> session.ticket)}"
  end

  defp create(s, prompt, windows, opts) do
    case System.find_executable(Keyword.get(opts, :executable, "claude")) do
      nil -> {:error, :claude_unavailable}
      executable -> open_window(s, prompt, windows, Keyword.put(opts, :executable, executable))
    end
  end

  defp open_window(s, prompt, windows, opts) do
    command = wrapper(s, prompt, opts)

    args =
      if Enum.any?(windows, &(&1.project == s.project)),
        do: ["new-window", "-t", "=" <> s.project, "-n", s.ticket],
        else: ["new-session", "-d", "-s", s.project, "-n", s.ticket]

    with {:ok, output} <-
           cmd(args ++ ["-P", "-F", ~S(#{window_id}), "-c", s.workdir, command], opts) do
      window = String.trim(output)
      if Regex.match?(~r/\A@\d+\z/, window), do: {:ok, window}, else: {:error, :tmux_unavailable}
    end
  end

  defp wrapper(s, prompt, opts) do
    tmux = "tmux -L " <> quote_arg(socket(opts))
    claude = Keyword.get(opts, :executable, "claude")
    # All variable text becomes a single shell argument, including multiline prompts.
    "#{tmux} set-option -w -t \"$TMUX_PANE\" automatic-rename off; " <>
      "#{tmux} set-option -w -t \"$TMUX_PANE\" @foreman-state running; " <>
      Enum.map_join([claude, "--session-id", s.session_id, prompt], " ", &quote_arg/1) <>
      "; #{tmux} set-option -w -t \"$TMUX_PANE\" @foreman-state ended; exec /bin/sh"
  end

  defp windows(opts) do
    format = ~S(#{session_name}\t#{window_name}\t#{window_id}\t#{@foreman-state}\t#{pane_dead})
    format = String.replace(format, "\\t", "\t")

    case cmd(["list-windows", "-a", "-F", format], opts) do
      {:ok, output} ->
        rows =
          for line <- String.split(output, "\n", trim: true),
              [project, ticket, window, state, dead] = String.split(line, "\t"),
              do: %{
                project: project,
                ticket: ticket,
                window: window,
                state:
                  cond do
                    dead == "1" or state == "ended" -> :ended
                    state == "running" -> :running
                    true -> :starting
                  end
              }

        {:ok, rows}

      {:error, {:tmux, output}} ->
        if String.contains?(output, [
             "no server running",
             "No such file or directory",
             "no current target"
           ]),
           do: {:ok, []},
           else: {:error, :tmux_unavailable}

      error ->
        error
    end
  end

  defp validate(s) do
    if Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, s.project) and
         Regex.match?(~r/\A[a-zA-Z0-9_.:-]+\z/, s.ticket) and File.dir?(s.workdir),
       do: :ok,
       else: {:error, :invalid_launch_target}
  end

  defp socket(opts),
    do:
      Keyword.get(opts, :socket, Application.get_env(:foreman, :planning_tmux_socket, "foreman"))

  defp quote_arg(value), do: "'" <> String.replace(value, "'", "'\\''") <> "'"

  defp cmd(args, opts) do
    case System.cmd("tmux", ["-N", "-L", socket(opts), "-f", "/dev/null"] ++ args,
           stderr_to_stdout: true
         ) do
      {out, 0} -> {:ok, out}
      {out, _} -> {:error, {:tmux, out}}
    end
  rescue
    ErlangError -> {:error, :tmux_unavailable}
  end
end
