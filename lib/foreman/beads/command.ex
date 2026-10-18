defmodule Foreman.Beads.Command do
  @moduledoc """
  Owned Linux port primitive used by Read's export effect. The guardian bounds
  time/output and reaps its process group before replying. Closing the port (also
  on owner death) cancels the group. An abstract socket retains physical admission
  until reaping, even if the BEAM and its Postgres connection die first.
  """
  @errors Map.new(
            [:busy, :timeout, :output_limit, :cancelled, :exit, :unreachable],
            &{Atom.to_string(&1), &1}
          )

  def run(path, argv, opts \\ []) do
    port =
      Port.open({:spawn_executable, System.find_executable("python3")}, [
        :binary,
        :exit_status,
        :use_stdio,
        :hide,
        args: [Application.app_dir(:foreman, "priv/command_guardian.py")]
      ])

    Port.command(
      port,
      Jason.encode!(%{
        path: path,
        argv: argv,
        timeout: Keyword.get(opts, :timeout, 20_000),
        max_bytes: Keyword.get(opts, :max_bytes, 32_000_000),
        identity: Keyword.get(opts, :identity)
      }) <> "\n"
    )

    collect(port, [])
  rescue
    ArgumentError -> {:error, :unreachable}
  end

  defp collect(port, chunks) do
    receive do
      {^port, {:data, data}} ->
        collect(port, [data | chunks])

      {^port, {:exit_status, 0}} ->
        case chunks |> Enum.reverse() |> IO.iodata_to_binary() |> Jason.decode() do
          {:ok, %{"output" => output}} -> Base.decode64(output)
          {:ok, %{"error" => error}} -> {:error, Map.get(@errors, error, :unreachable)}
          _ -> {:error, :unreachable}
        end

      {^port, {:exit_status, _}} ->
        {:error, :unreachable}
    end
  end
end
