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
        IO.puts(:stderr, "Coordinator not launched: #{inspect(error)}")
        1
    end
  end

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
