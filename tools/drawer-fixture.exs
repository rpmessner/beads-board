if Mix.env() != :acceptance or
     Foreman.Repo.config()[:database] != "foreman_acceptance_#{Path.basename(File.cwd!())}",
  do: raise("checkout-local acceptance only")

case System.argv() do
  ["ask"] ->
    {:ok, request} = Foreman.Requests.ask({"scratch", "scratch-1"}, "decision", %{"actor" => "pi", "session" => "fm-drawer", "facts" => %{"question" => "Which layout should we use?", "options" => ["Wide", "Compact"], "recommendation" => "Compact"}})
    IO.puts(request.id)
  ["open-pr"] ->
    request = Foreman.Repo.insert!(%Foreman.Requests.Request{
      repo_key: "scratch", bead_id: "scratch-1", kind: "open_pr", actor: "pi", state: "pending",
      facts: %{"remote" => "owner/repo", "head_branch" => "feature", "base_branch" => "main",
        "expected_sha" => String.duplicate("a", 40), "title" => "Review the layout", "body" => "Keep the existing shortcuts.\nVerify the new layout."}
    })
    IO.puts(request.id)
  ["merge"] ->
    request = Foreman.Repo.insert!(%Foreman.Requests.Request{
      repo_key: "scratch", bead_id: "scratch-1", kind: "merge", actor: "pi", state: "pending",
      facts: %{"remote" => "owner/repo", "number" => 5, "expected_sha" => String.duplicate("b", 40)}
    })
    IO.puts(request.id)

  ["clear"] ->
    for request <- Foreman.Requests.pending(), do: Foreman.Requests.resolve(request.id, :decline, %{})
  ["get", id] ->
    request = Foreman.Requests.get(id)
    IO.puts(Jason.encode!(Map.take(request, [:state, :note, :outcome])))
end
