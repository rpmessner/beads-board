defmodule Foreman.Forge do
  @moduledoc """
  Forge boundary. `list/2` returns a JSON-safe snapshot with `default_branch` and
  `change_requests` (string keys). Each CR has number, title, body, source_branch,
  target_branch, head_sha, draft, checks, mergeable, url and state. State is
  open/closed/merged; checks and mergeable are normalized lowercase forge values.

  Snapshots also contain `branches`, a map of branch names to observed SHAs.
  Creation validates against that worker snapshot; jobs use `branch_sha/3` for
  the final live head check. `create_change_request/3` preserves the named
  head_branch, base_branch, title and body and returns a number and URL.
  The head_guard capability describes merge, not atomic PR-creation support.

  `tracked: [number]` requests explicit states for previously open CRs, in the
  same read. Incomplete reads return an error, never an authoritative empty list.
  Transport/credential options are ephemeral and must not enter persisted jobs.

  Capabilities distinguish native head_guard/retarget support from enabled writes.
  Mutations are merge commits only and never delete branches. Transports must not
  retry writes automatically; ambiguous outcomes require observation, not replay.
  """
  def adapter, do: Application.get_env(:foreman, :forge_adapter, Foreman.Forge.GitHub)

  def options do
    case Application.fetch_env(:foreman, :forge_options) do
      {:ok, opts} -> opts
      :error -> [token: Foreman.Forge.Credentials.token()]
    end
  end

  @type snapshot :: %{required(String.t()) => term()}
  @callback list(String.t(), keyword()) :: {:ok, snapshot()} | {:error, atom()}
  @callback merge(String.t(), pos_integer(), String.t(), keyword()) ::
              {:ok, map()} | {:error, atom()}
  @callback retarget(String.t(), pos_integer(), String.t(), keyword()) :: :ok | {:error, atom()}
  @callback create_change_request(String.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  @callback branch_sha(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
  @callback capabilities() :: %{
              head_guard: boolean(),
              retarget: boolean(),
              write: boolean(),
              create_change_request: boolean()
            }
end
