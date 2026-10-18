# Run only as the seed command of a scratch devserve app (FOREMAN_ROLE=web).
unless System.get_env("PREVIEW") == "1" and
         String.contains?(Foreman.Repo.config()[:database], "_preview_") do
  raise "requires a devserve scratch database"
end

alias Foreman.Repo

{:ok, defaults} =
  Foreman.Config.parse_layers([{"defaults", File.read!("priv/foreman.defaults.toml")}])

repo = %{
  "key" => "preview",
  "path" => File.cwd!(),
  "enabled" => true,
  "tickets" => "files",
  "forge" => "none"
}

Repo.insert_all("board_config", [
  %{
    id: 1,
    config: Map.put(defaults, "repos", [repo]),
    stores: %{},
    discovered: [],
    source: "scratch preview",
    loaded_at: DateTime.utc_now()
  }
])

Foreman.TicketFiles.Reader.publish(repo, Foreman.TicketFiles.snapshot(File.cwd!()))
Foreman.Overlay.backfill("preview", [%{bead_id: "preview-1", status: "open", issue_type: "task"}])
Repo.update_all("tickets", set: [stage: "committed"])

request =
  Repo.insert!(%Foreman.Requests.Request{
    repo_key: "preview",
    bead_id: "preview-1",
    kind: "push",
    actor: "fixture",
    state: "approved",
    facts: %{
      "remote" => "example/never-write",
      "worktree" => File.cwd!(),
      "local_branch" => "fm-preview",
      "remote_branch" => "never-write",
      "expected_sha" => String.duplicate("a", 40)
    }
  })

{:ok, _} = %{request_id: request.id} |> Foreman.Requests.PushJob.new() |> Oban.insert()
IO.puts("Seeded approved push #{request.id}")
