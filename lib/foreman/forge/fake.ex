defmodule Foreman.Forge.Fake do
  @moduledoc "Atomic in-memory forge for contract and UI acceptance tests."
  @behaviour Foreman.Forge
  use Agent
  def start_link(snapshot), do: Agent.start_link(fn -> snapshot end)
  def list(_, opts), do: Agent.get(Keyword.fetch!(opts, :server), &{:ok, &1})
  def capabilities, do: %{head_guard: true, retarget: true, write: true}

  def merge(_, number, sha, opts) do
    Agent.get_and_update(Keyword.fetch!(opts, :server), fn snapshot ->
      pr = Enum.find(snapshot["change_requests"], &(&1["number"] == number))

      cond do
        snapshot["merge_error"] ->
          {{:error, :unavailable}, snapshot}

        is_nil(pr) ->
          {{:error, :not_found}, snapshot}

        pr["head_sha"] != sha ->
          {{:error, :head_moved}, snapshot}

        pr["state"] != "open" ->
          {{:error, :not_open}, snapshot}

        true ->
          result = %{"sha" => "merge-" <> sha}
          {{:ok, result}, replace(snapshot, number, &Map.put(&1, "state", "merged"))}
      end
    end)
  end

  def retarget(_, number, base, opts) do
    Agent.get_and_update(Keyword.fetch!(opts, :server), fn snapshot ->
      cond do
        snapshot["retarget_error"] ->
          {{:error, :unavailable}, snapshot}

        not Enum.any?(snapshot["change_requests"], &(&1["number"] == number)) ->
          {{:error, :not_found}, snapshot}

        true ->
          {:ok, replace(snapshot, number, &Map.put(&1, "target_branch", base))}
      end
    end)
  end

  defp replace(snapshot, number, fun) do
    Map.update!(
      snapshot,
      "change_requests",
      &Enum.map(&1, fn pr -> if pr["number"] == number, do: fun.(pr), else: pr end)
    )
  end
end
