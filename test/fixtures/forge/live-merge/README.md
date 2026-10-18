# Authorized live merge recordings

Captured on 2026-10-18 from the user-approved private scratch repository. The isolated board used the real `Foreman.Forge.GitHub` adapter. Its acceptance-only transport forwarded requests to GitHub with retries and redirects disabled, then saved these JSON projections.

Each file contains the HTTP status, request body and response body projection. No headers, credentials, user objects, author/committer identities, emails, avatar URLs, node IDs or repository metadata are retained. GraphQL PR URLs replace the real owner/repository with `fixture-owner/merge-scratch`. PR numbers, branch names, commit SHAs, checks, mergeability and states are unchanged.

- `initial-list.json`: two open PRs before the final moved-head check.
- `moved-list.json`: the newly pushed head observed by the job; the old confirmation was refused without a merge request.
- `merge-list.json`: the fresh read immediately before the successful merge.
- `merge-merge.json`: the real merge-commit PUT request and HTTP 200 response, projected to `merged` and `sha`.
- `retarget-list.json`: the child's original base before the PATCH.
- `retarget-retarget.json`: the real PATCH request and HTTP 200 response, projected to PR number and base ref.
- `observed-list.json`: the next read, with PR #1 merged and PR #2 open against main.
- `first-initial-list.json` and `first-moved-list.json`: the first attempt, where the changed head had `mergeable: UNKNOWN`. These reproduce the diagnostic-ordering regression.
- `stale-head-list.json`: GitHub briefly returned the prior head with unknown mergeability after another push. The foreman refused it. The acceptance runner now waits until GitHub reports both the expected new SHA and known mergeability before confirming.

The shared contract suite replays the real successful mutation responses and subsequent read against GitHub and the fake. Its HTTP 409 negative case remains synthetic: live moved-head attempts stopped at the job's read guard, so no live HTTP 409 response exists.

The full REST retarget response is deliberately not retained; it contains unrelated personal and repository metadata. The saved projection includes every field consumed by the adapter. See `docs/sessions/bb-merge.md` for the commit-parent, branch-retention and browser evidence.
