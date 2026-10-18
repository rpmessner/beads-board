defmodule Foreman.Forge.Credentials do
  @moduledoc "Worker boot credential, memory only. Status inspection is redacted."
  use GenServer
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def token, do: GenServer.call(__MODULE__, :token)
  @impl true
  def init(_) do
    task =
      Task.async(fn ->
        case System.find_executable("gh") do
          nil -> {"", 1}
          executable -> System.cmd(executable, ["auth", "token"], stderr_to_stdout: true)
        end
      end)

    token =
      case Task.yield(task, 5_000) || Task.shutdown(task, :brutal_kill) do
        {:ok, {value, 0}} -> String.trim(value)
        _ -> nil
      end

    {:ok, token}
  end

  @impl true
  def handle_call(:token, _, token), do: {:reply, token, token}
  @impl true
  def format_status(status), do: %{status | state: :redacted}
end
