defmodule Foreman.Forge.GitHub do
  @moduledoc "Bounded GraphQL reads and head-guarded REST merge commits. Never deletes branches."
  @behaviour Foreman.Forge
  @fields "number title body headRefName baseRefName headRefOid isDraft mergeable mergeStateStatus url state commits(last:1) { nodes { commit { statusCheckRollup { state } } } }"

  @impl true
  def list(remote, opts \\ []) do
    with [owner, name] <- String.split(remote, "/"),
         token when is_binary(token) and token != "" <- Keyword.get(opts, :token) do
      tracked =
        Keyword.get(opts, :tracked, [])
        |> Enum.filter(&(is_integer(&1) and &1 > 0))
        |> Enum.uniq()

      aliases = Enum.map_join(tracked, " ", &"pr#{&1}: pullRequest(number:#{&1}) { #{@fields} }")

      query =
        "query($owner:String!,$name:String!) { repository(owner:$owner,name:$name) { defaultBranchRef { name } pullRequests(first:100,states:OPEN,orderBy:{field:CREATED_AT,direction:ASC}) { pageInfo { hasNextPage } nodes { #{@fields} } } #{aliases} } }"

      request =
        [
          url: "https://api.github.com/graphql",
          auth: {:bearer, token},
          json: %{query: query, variables: %{owner: owner, name: name}},
          retry: false,
          redirect: false,
          receive_timeout: 15_000
        ] ++ Keyword.take(opts, [:plug])

      case Req.post(request) do
        {:ok, %{status: 200, body: %{"errors" => errors}}} ->
          limited =
            is_list(errors) &&
              Enum.any?(
                errors,
                &(is_map(&1) &&
                    (&1["type"] == "RATE_LIMITED" ||
                       get_in(&1, ["extensions", "type"]) == "RATE_LIMITED"))
              )

          {:error, if(limited, do: :rate_limited, else: :graphql)}

        {:ok, %{status: 200, body: %{"data" => %{"repository" => repo}}}} ->
          decode(repo, tracked)

        {:ok, %{status: status}} when status in [403, 429] ->
          {:error, :rate_limited}

        {:ok, %{status: 401}} ->
          {:error, :unauthorized}

        _ ->
          {:error, :unavailable}
      end
    else
      _ -> {:error, :credentials_or_remote}
    end
  end

  defp decode(
         %{
           "defaultBranchRef" => %{"name" => default},
           "pullRequests" => %{"pageInfo" => %{"hasNextPage" => false}, "nodes" => nodes}
         } = repo,
         tracked
       ) do
    previous = Enum.map(tracked, &repo["pr#{&1}"])

    if Enum.any?(previous, &is_nil/1) do
      {:error, :incomplete}
    else
      {:ok,
       %{
         "default_branch" => default,
         "change_requests" =>
           Enum.uniq_by(nodes ++ previous, & &1["number"]) |> Enum.map(&normalize/1)
       }}
    end
  rescue
    _ -> {:error, :invalid_response}
  end

  defp decode(_, _), do: {:error, :incomplete}

  defp normalize(pr) do
    true = is_integer(pr["number"]) and pr["number"] > 0
    true = is_boolean(pr["isDraft"]) and pr["state"] in ["OPEN", "CLOSED", "MERGED"]
    true = Enum.all?(~w(title headRefName baseRefName headRefOid url), &is_binary(pr[&1]))
    true = String.starts_with?(pr["url"], "https://github.com/")

    checks =
      get_in(pr, ["commits", "nodes"])
      |> List.first()
      |> get_in(["commit", "statusCheckRollup", "state"])

    %{
      "number" => pr["number"],
      "title" => pr["title"],
      "body" => pr["body"],
      "source_branch" => pr["headRefName"],
      "target_branch" => pr["baseRefName"],
      "head_sha" => pr["headRefOid"],
      "draft" => pr["isDraft"],
      "checks" => if(checks, do: String.downcase(checks), else: "none"),
      "mergeable" => String.downcase(pr["mergeable"]),
      "merge_state" => pr["mergeStateStatus"],
      "url" => pr["url"],
      "state" => String.downcase(pr["state"])
    }
  end

  @impl true
  def capabilities, do: %{head_guard: true, retarget: true, write: true}

  @impl true
  def merge(remote, number, sha, opts) when is_binary(sha) and byte_size(sha) > 0 do
    case mutation(:put, remote, number, "/merge", %{merge_method: "merge", sha: sha}, opts) do
      {:ok, %{"merged" => true, "sha" => merged_sha}} when is_binary(merged_sha) ->
        {:ok, %{"sha" => merged_sha}}

      {:ok, %{"merged" => false}} ->
        {:error, :merge_refused}

      {:ok, _} ->
        {:error, :invalid_response}

      error ->
        error
    end
  end

  @impl true
  def retarget(remote, number, base, opts) when is_binary(base) and byte_size(base) > 0 do
    case mutation(:patch, remote, number, "", %{base: base}, opts) do
      {:ok, %{"number" => ^number, "base" => %{"ref" => ^base}}} -> :ok
      {:ok, _} -> {:error, :invalid_response}
      error -> error
    end
  end

  defp mutation(method, remote, number, suffix, body, opts) do
    token = Keyword.get(opts, :token)

    if is_binary(remote) && Regex.match?(~r/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/, remote) &&
         is_integer(number) && number > 0 && is_binary(token) && token != "" do
      request =
        [
          method: method,
          url: "https://api.github.com/repos/#{remote}/pulls/#{number}#{suffix}",
          auth: {:bearer, token},
          json: body,
          retry: false,
          redirect: false,
          receive_timeout: 15_000
        ] ++ Keyword.take(opts, [:plug])

      case Req.request(request) do
        {:ok, %{status: 200, body: response}} -> {:ok, response}
        {:ok, %{status: 409}} -> {:error, :head_moved}
        {:ok, %{status: status}} when status in [405, 422] -> {:error, :merge_refused}
        {:ok, %{status: 401}} -> {:error, :unauthorized}
        {:ok, %{status: status}} when status in [403, 429] -> {:error, :forbidden_or_rate_limited}
        {:ok, %{status: 404}} -> {:error, :not_found}
        _ -> {:error, :outcome_unknown}
      end
    else
      {:error, :credentials_or_remote}
    end
  end
end
