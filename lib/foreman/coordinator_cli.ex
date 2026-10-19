defmodule Foreman.CoordinatorCLI do
  @moduledoc "In-pane coordinator launcher. Transport failures never launch an unrecorded conversation."
  def parse([]), do: {:ok, :resume}
  def parse(["--fresh"]), do: {:ok, :fresh}

  def parse(["--adopt", id]) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> {:ok, {:adopt, id}}
      _ -> {:error, :usage}
    end
  end

  def parse(_args), do: {:error, :usage}

  def run(args, opts \\ []) do
    with {:ok, mode} <- parse(args),
         {:ok, target} <- target(mode),
         request =
           Map.merge(target, %{
             "action" => "coordinator",
             "mode" => mode_name(mode),
             "adopt" => adopt_id(mode),
             "transient" => true,
             "request_id" => Ecto.UUID.generate()
           }),
         {0, %{"session_id" => id} = body} when is_binary(id) <-
           Foreman.CLITransport.deliver(request, opts) do
      IO.puts(body["session_id"])
      0
    else
      error ->
        IO.puts(:stderr, "Coordinator not launched: #{refusal(error)}.")
        1
    end
  end

  defp refusal({:error, :usage}), do: refusal_reason("invalid_coordinator_mode")
  defp refusal({:error, :run_inside_tmux}), do: "run this command inside tmux"
  defp refusal({_, %{"error" => reason}}), do: refusal_reason(reason)

  defp refusal({_, %{"warning" => _}}),
    do: "foreman is unavailable; check the service and CLI authentication"

  defp refusal(_), do: "foreman returned an unexpected response"

  defp refusal_reason("claude_unavailable"), do: "claude is not on the foreman service PATH"

  defp refusal_reason("invalid_coordinator_pane"),
    do: "run this command in the coordinator pane on the foreman tmux server"

  defp refusal_reason("coordinator_active"),
    do: "the coordinator is still running; stop it before replacing its conversation"

  defp refusal_reason("session_id_in_use"), do: "that conversation belongs to another session"
  defp refusal_reason("invalid_session_id"), do: "the conversation ID must be a UUID"

  defp refusal_reason("invalid_coordinator_mode"),
    do: "use foreman coordinator [--fresh | --adopt <uuid>]"

  defp refusal_reason("invalid_launch_target"),
    do: "the coordinator working directory is unavailable"

  defp refusal_reason("tmux_unavailable"), do: "the foreman tmux server is unavailable"
  defp refusal_reason("refused in preview"), do: "this command is unavailable in a preview"
  defp refusal_reason(_), do: "foreman refused the coordinator request"

  defp mode_name({:adopt, _}), do: "adopt"
  defp mode_name(mode), do: to_string(mode)
  defp adopt_id({:adopt, id}), do: id
  defp adopt_id(_), do: nil
  defp target({:adopt, _}), do: {:ok, %{}}

  defp target(_) do
    with tmux when is_binary(tmux) <- System.get_env("TMUX"),
         pane when is_binary(pane) <- System.get_env("TMUX_PANE") do
      {:ok, %{"socket" => tmux |> String.split(",") |> hd(), "pane" => pane}}
    else
      _ -> {:error, :run_inside_tmux}
    end
  end
end
