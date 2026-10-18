defmodule Foreman.Preview do
  @moduledoc "Execution-time boundary for external writes. Reads and preview-local persistence remain available."

  @spec allow_external_write() :: :ok | {:error, String.t()}
  def allow_external_write do
    if System.get_env("PREVIEW") == "1", do: {:error, "refused in preview"}, else: :ok
  end
end
