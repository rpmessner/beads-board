defmodule Foreman.Previews.Job do
  @moduledoc "Worker-only preview reconciliation. Preview copies cannot control host services."
  use Oban.Worker, queue: :previews, max_attempts: 3, unique: [period: 30, states: :incomplete]
  @impl true
  def timeout(_), do: :timer.minutes(4)
  @impl true
  def perform(_) do
    with :ok <- Foreman.Preview.allow_external_write(), do: Foreman.Previews.reconcile()
  end
end
