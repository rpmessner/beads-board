defmodule Board.Forge do
  @moduledoc """
  Forge boundary. `list/2` returns a JSON-safe snapshot with `default_branch` and
  `change_requests` (string keys). Each CR has number, title, body, source_branch,
  target_branch, head_sha, draft, checks, mergeable, url and state. State is
  open/closed/merged; checks and mergeable are normalized lowercase forge values.

  `tracked: [number]` requests explicit states for previously open CRs, in the
  same read. Incomplete reads return an error, never an authoritative empty list.
  Transport/credential options are ephemeral and must not enter persisted jobs.

  Capabilities distinguish native head_guard/retarget support from enabled writes.
  This read-only slice declares mutation signatures, but `write: false` and both
  mutation callbacks return `{:error, :read_only}` until the merge-action ticket.
  """
  @type snapshot :: %{required(String.t()) => term()}
  @callback list(String.t(), keyword()) :: {:ok, snapshot()} | {:error, atom()}
  @callback merge(String.t(), pos_integer(), String.t(), keyword()) ::
              {:ok, map()} | {:error, atom()}
  @callback retarget(String.t(), pos_integer(), String.t(), keyword()) :: :ok | {:error, atom()}
  @callback capabilities() :: %{head_guard: boolean(), retarget: boolean(), write: boolean()}
end
