defmodule Foreman.Requests.Merge do
  @moduledoc "Merge asks bind a PR and head. Confirmation delegates to the existing merge action."
  @behaviour Foreman.Requests.Kind

  def validate(facts, row) when is_map(facts) do
    with true <- (is_integer(facts["number"]) and facts["number"] > 0) || {:error, :invalid_facts},
         {:ok, _} <- Foreman.Requests.LocalRefs.sha(facts["expected_sha"]),
         {:ok, repo} <- Foreman.Requests.Push.configured(row.repo_key),
         true <- Foreman.Forge.adapter().capabilities().write || {:error, :read_only},
         facts = Map.put(Map.take(facts, ["number", "expected_sha"]), "remote", repo["github"]),
         :ok <- unchanged(row.repo_key, facts),
         {:ok, _} <-
           Foreman.Merge.prepare(Foreman.Forge.Store.get(row.repo_key).snapshot, facts["number"]) do
      {:ok, facts}
    end
  end

  def validate(_, _), do: {:error, :invalid_facts}

  def unchanged(key, facts) do
    with {:ok, repo} <- Foreman.Requests.Push.configured(key),
         true <- repo["github"] == facts["remote"] || {:error, :config_changed},
         %{remote: remote, snapshot: snapshot} <- Foreman.Forge.Store.get(key),
         true <- remote == facts["remote"] || {:error, :config_changed},
         pr when not is_nil(pr) <-
           Enum.find(snapshot["change_requests"] || [], &(&1["number"] == facts["number"])) do
      cond do
        pr["state"] != "open" -> {:error, :not_open}
        pr["head_sha"] != facts["expected_sha"] -> {:error, :head_moved}
        true -> :ok
      end
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc "Requests.confirm_merge/3 owns atomic approval and merge enqueue after modal confirmation."
  def enqueue(_), do: :ok
end
