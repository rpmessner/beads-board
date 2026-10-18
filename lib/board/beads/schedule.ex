defmodule Board.Beads.Schedule do
  @moduledoc """
  Pure admission boundary for one physical repository. No timers or jobs start here.

  The owner supplies monotonic milliseconds and a fresh boot epoch (for example a
  UUID); physical identity must be resolved by the external-read adapter, never
  inferred from a config key. All aliases of a store must share this snapshot.
  Call `request/2` on nominal three-second ticks even without changed file signals.
  Pings, signals and the five-minute sweep call the same function.

  Busy requests are coalesced, not queued. Completion never launches catch-up work.
  `finish/2` means the job is terminal AND its owned subprocess has been reaped;
  requesting cancellation or an Oban timeout alone must not release admission.
  Restart-safe tokens prevent old completions from releasing a newer flight.
  This core alone does not provide cross-process or cross-node single flight.
  """
  alias Board.Beads.ScheduleMachine

  def new(identity, epoch, now),
    do: %{
      state: ScheduleMachine.__fsm__(:initial),
      identity: identity,
      epoch: epoch,
      generation: 0,
      next_at: now
    }

  def request(snapshot, now), do: advance(snapshot, :request, now)
  def finish(snapshot, token), do: advance(snapshot, :finished, token)
  def disable(snapshot), do: advance(snapshot, :disable, nil)
  def enable(snapshot), do: advance(snapshot, :enable, nil)

  defp advance(snapshot, event, payload) do
    {state, effects} = ScheduleMachine.step(snapshot.state, {event, payload}, snapshot)

    Enum.reduce(effects, {%{snapshot | state: state}, []}, fn
      {:enqueue, :read}, {current, external} ->
        current = %{current | generation: current.generation + 1, next_at: payload + 3_000}
        {current, external ++ [enqueue: {current.identity, token(current)}]}

      {:cancel, :read}, {current, external} ->
        {current, external ++ [cancel: {current.identity, token(current)}]}
    end)
  end

  defp token(snapshot), do: {snapshot.epoch, snapshot.generation}
end
