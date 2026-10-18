defmodule Foreman.Config.Reload do
  @moduledoc """
  Pure config reload boundary. Start with validated shipped defaults. The runtime
  executes `{:read, {:config, generation}}` through Oban and passes its result
  with that generation to `complete/3`.
  Broadcast effects contain no config content; subscribers fetch the snapshot.
  """
  alias Foreman.Config.ReloadMachine

  def new(config),
    do: %{state: ReloadMachine.__fsm__(:initial), config: config, error: nil, generation: 0}

  def request(snapshot), do: advance(snapshot, :reload, nil)

  def complete(snapshot, generation, {:ok, config}),
    do: advance(snapshot, :accepted, {generation, config})

  def complete(snapshot, generation, {:error, error}),
    do: advance(snapshot, :rejected, {generation, error})

  defp advance(snapshot, event, payload) do
    {state, effects} = ReloadMachine.step(snapshot.state, {event, payload}, snapshot)

    Enum.reduce(effects, {%{snapshot | state: state}, []}, fn
      {:read, :config}, {current, external} ->
        generation = current.generation + 1
        {%{current | generation: generation}, external ++ [read: {:config, generation}]}

      {:install, :config}, {current, external} ->
        {%{current | config: elem(payload, 1), error: nil}, external}

      {:reject, :config}, {current, external} ->
        {%{current | error: elem(payload, 1)}, external}

      effect, {current, external} ->
        {current, external ++ [effect]}
    end)
  end
end
