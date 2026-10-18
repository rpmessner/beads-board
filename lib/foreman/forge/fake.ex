defmodule Foreman.Forge.Fake do
  @moduledoc "Atomic in-memory forge for contract and UI acceptance tests."
  @behaviour Foreman.Forge
  use Agent
  def start_link(snapshot), do: Agent.start_link(fn -> snapshot end)
  def list(_, opts), do: Agent.get(Keyword.fetch!(opts, :server), &{:ok, &1})

  def create_change_request(remote, facts, opts) do
    Agent.get_and_update(Keyword.fetch!(opts, :server), fn snapshot ->
      prs = snapshot["change_requests"]

      if Enum.any?(prs, &(&1["state"] == "open" and &1["source_branch"] == facts["head_branch"])) do
        {{:error, :create_refused}, snapshot}
      else
        number = Enum.reduce(prs, 0, &max(&1["number"], &2)) + 1
        result = %{"number" => number, "url" => "https://github.com/#{remote}/pull/#{number}"}

        pr =
          Map.merge(result, %{
            "title" => facts["title"],
            "body" => facts["body"],
            "source_branch" => facts["head_branch"],
            "target_branch" => facts["base_branch"],
            "head_sha" => get_in(snapshot, ["branches", facts["head_branch"]]),
            "state" => "open",
            "draft" => false,
            "checks" => "none",
            "mergeable" => "unknown"
          })

        {{:ok, result}, Map.put(snapshot, "change_requests", prs ++ [pr])}
      end
    end)
  end

  def branch_sha(_, branch, opts) do
    Agent.get(Keyword.fetch!(opts, :server), fn snapshot ->
      case get_in(snapshot, ["branches", branch]) do
        nil -> {:error, :not_found}
        sha -> {:ok, sha}
      end
    end)
  end

  def capabilities,
    do: %{head_guard: true, retarget: true, write: true, create_change_request: true}

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
