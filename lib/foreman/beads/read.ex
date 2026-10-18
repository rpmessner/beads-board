defmodule Foreman.Beads.Read do
  @moduledoc """
  Pure read protocol; effects require an external-read job adapter. Not a bd runner.

  `check_lock` calls JournalLock passively. Only `:clear` permits the `export`
  effect (one stdout-only `bd export`, default timeout 20 seconds). The adapter
  must strip inherited repo-routing environment overrides, refuse server startup,
  bound output, and own/reap the subprocess; those guarantees are not provided by
  this pure module. No repair, file fallback or store copy effect exists.

  `reaped/3` accepts successful complete stdout only AFTER process exit/reaping;
  unsuccessful exits carry a sanitized error, never partial stdout. Projection
  validates and hashes the output transactionally. Its result feeds `projected/3`.
  All replies carry the immutable flight token. Never reuse it after a restart.

  Timeout/disable/shutdown while exporting requests cancellation of the owned
  child, not an agent PID. The protocol stays cancelling until `reaped/3` arrives;
  even successful late stdout is discarded. Only `finished` releases scheduler
  admission. Once projection starts it is atomic and cancellation is ignored.
  An adapter must not send `finished` merely because Oban cancelled the job.
  """
  alias Foreman.Beads.ReadMachine

  def new(path, token),
    do: %{
      state: ReadMachine.__fsm__(:initial),
      path: path,
      token: token,
      outcome: nil,
      cancellation: nil
    }

  def start(snapshot), do: advance(snapshot, :start, nil)
  def lock_checked(snapshot, token, :clear), do: advance(snapshot, :clear, {token, nil})

  def lock_checked(snapshot, token, {:defer, reason}) when reason in [:held, :indeterminate],
    do: advance(snapshot, :deferred, {token, {:defer, reason}})

  def reaped(snapshot, token, {:ok, output}) when is_binary(output),
    do: advance(snapshot, :exported, {token, output})

  def reaped(snapshot, token, {:error, _} = error),
    do: advance(snapshot, :failed, {token, error})

  def cancel(snapshot, token, reason) when reason in [:timeout, :disabled, :shutdown],
    do: advance(snapshot, :cancel, {token, {:error, reason}})

  def projected(snapshot, token, result), do: advance(snapshot, :projected, {token, result})

  defp advance(snapshot, event, payload) do
    {state, effects} = ReadMachine.step(snapshot.state, {event, payload}, snapshot)

    Enum.reduce(effects, {%{snapshot | state: state}, []}, fn
      {:check_lock, :repo}, {current, external} ->
        {current, external ++ [check_lock: {current.token, current.path}]}

      {:export, :repo}, {current, external} ->
        {current, external ++ [export: {current.token, current.path, 20_000}]}

      {:project, :output}, {current, external} ->
        {current, external ++ [project: {current.token, elem(payload, 1)}]}

      {:cancel_export, :owned}, {current, external} ->
        {:error, reason} = elem(payload, 1)
        {%{current | cancellation: reason}, external ++ [cancel_export: {current.token, reason}]}

      {:finish, :cancelled}, {current, external} ->
        outcome = {:error, current.cancellation}
        {%{current | outcome: outcome}, external ++ [finished: {current.token, outcome}]}

      {:finish, :result}, {current, external} ->
        outcome = elem(payload, 1)
        {%{current | outcome: outcome}, external ++ [finished: {current.token, outcome}]}
    end)
  end
end
