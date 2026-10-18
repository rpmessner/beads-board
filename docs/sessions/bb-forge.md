# bb-forge: bb-c2w.8

Implemented and verified. No commits, pushes, bd commands, subagents, or GitHub writes. The coordinator-owned brief is untouched. The temporary server on port 4758 is stopped.

## What changed

- `Board.Forge` defines list, merge-with-expected-head, retarget, and capabilities. `Board.Forge.GitHub` uses Req; `Board.Forge.Fake` keeps its snapshot in an Agent. The shared contract suite runs against both.
- `Board.Forge.Credentials` obtains `gh auth token` at worker boot and keeps it in memory. Missing auth produces a sanitized read error.
- `Board.Forge.ReadLifecycle`, `SyncJob`, and the worker Runtime schedule serialized reads every two minutes. Manual refresh crosses the Postgres notifier to the worker. Oban arguments contain only repo identity and the manual flag.
- `forge_snapshots` stores the last successful result and read health. The worker rejects partial responses, retains data on failure, and rechecks config before publication.
- `/pull-requests` shows the selected project's ordered stack, branches, head SHA, checks, draft/conflict/waiting status, and bead links. Local or disabled repositories have no panel. There are no merge controls.
- Initiatives counts distinct open CRs across each epic's planned tickets, fallout, and descendants. Ticket sheets show linked CR URLs and states.

## Forge and linking contract

Both adapters declare `%{head_guard: true, retarget: true, write: false}`. Head guard and retarget describe native forge support; `write` remains false in this ticket. Mutation callbacks return `{:error, :read_only}`. Ticket .9 must implement guarded mutations before enabling writes.

The GitHub adapter sends one GraphQL query containing open PRs and aliases for each previously open PR. A tracked PR's explicit `CLOSED` or `MERGED` state produces the corresponding observed event. No close is inferred from disappearance. Terminal records stay available to ticket sheets.

Stack edges match a child's target branch to another open PR's source branch. Default-branch roots come first, followed by their children. Detached bases and cycles are labelled detached and traversal is bounded. Only a default-rooted PR can show ready status, and even that status says read-only.

Link extraction uses each repo's projected ticket prefixes. Each matched ID resolves to a real ticket in that repo. Title wins over branch, then body, for each bead's recorded source. One PR may link several tickets; one epic counts that PR once. Opening, closing the last CR, and merging step the existing stage machine. Its rules for done, abandoned, and already-merged tickets remain unchanged.

## Review baseline

`c41cd42b25dd7e193b4366eef7bcb4216f235acc` equals HEAD; the committed three-dot diff is empty. Review explicitly includes the requested working-tree/new deliverables, excluding the coordinator brief. Axes run sequentially in this session.

### Standards

Important findings fixed:

- Forge admission originally used a conditional outside the machine. `Board.Forge.ReadLifecycle` now declares guarded cadence/manual/rate-limit admission, read, publish and retain transitions. Runtime and the serialized job both consult it; requests within ten seconds coalesce, ordinary/rate-limited reads wait two minutes. A failing-first test covers admission and terminal effects.
- Added the generated lifecycle matrix/diagram and golden check. The distinct `ReadLifecycle` name avoids colliding with the beads `ReadMachine` documentation.
- Kept the existing ticket-detail `crs` number list contract; enriched forge records are a separate `change_requests` field. The full-suite regression exposed that compatibility break before correction.

TDD trail: contract, stack/link extraction, overlay observations and LiveView tests failed against minimal stubs before implementation. The initial sync executor preceded its integration tests; that ordering limitation is not claimed as red-first. Its later cadence guard regression was failing-first.

Declined: merge/retarget implementation and merge UI belong to .9. Standards verdict: ready after fixes and the passing final gate.

### Spec

Important finding fixed: terminal CR observations vanished on the next open-only read. The snapshot now retains prior observations absent from a later result; the adapter explicitly queries every previously open PR in the same GraphQL request, so absence never manufactures a close/merge. A failing-first regression proves merged links survive later reads.

The real fixture has #5 scheduler onto main, then #6 time-model onto scheduler (not the mockup's illustrative #4/#5). Read-only controls deliberately omit the merge machine and buttons. Capabilities declare GitHub's head guard and retarget support, with `write: false`; both mutation callbacks explicitly return `{:error, :read_only}` for .9 to implement.

Declined: .9's actual mutations/confirmation, and adapters beyond GitHub/fake. Spec verdict: ready. Live acceptance and screenshots pass below.

### Risk

Load-bearing fact: only complete, authorized read snapshots can publish observations; no forge mutation is enabled. Proof level 4: recorded-response tests cover tracked merges, pagination, missing tracked PRs, GraphQL errors, missing credentials, HTTP/GraphQL rate limits, malformed identities and config removal during a read. The shared contract tests assert both mutation callbacks return read-only errors. Proof level 5: the isolated running app's Oban worker fetched the real stack and the browser opened the linked ticket sheet.

Important findings fixed:

- Prefix regexes also matched `docs/sessions/fe-sched.md`. Persisted links now resolve against that repo's ticket projection; title/branch/body priority still records each bead's earliest source. A failing-first test rejects the nonexistent reference. Later-arriving tickets can link on a subsequent read.
- Repointing a repo left old PR numbers in `overlay_cr_links`, keeping a new ticket stuck at `pr_open` when its last new CR closed. Successful remote replacement clears the obsolete guard index without inventing close events. Failing-first regression now reaches `committed`.
- HTTP-200 GraphQL rate limits initially had a generic error, allowing manual refresh to bypass the rate-limit cooldown. They now use the same guarded cooldown as HTTP 403/429.
- Malformed CR identities could reach persistence. The adapter now rejects missing numbers/required fields and invalid states/URLs as `invalid_response` before publication.
- A missing `gh` executable no longer crashes credential boot. Failed auth yields no credential; reads report a sanitized error. Token state inspection is redacted; no credential is put in an Oban argument, DB field, fixture or report.

Risks retained: reads cap at 100 open PRs; pagination rejects the entire response rather than publishing partial results or making a second query. Rate limits retain the previous snapshot and wait at least two minutes (manual reads otherwise coalesce within ten seconds). No attempt is made to infer closure from absence. Credential renewal requires worker restart. Closed/merged observations are retained in Postgres; snapshots can grow with repository history.

Declined: GitHub writes, live destructive failure injection, token rotation without restart, and >100-PR pagination expansion. Risk verdict: ready within the read-only boundary. Cheapest pre-merge check: the forge tests plus precommit.

## Live acceptance and screenshots

`tools/forge-acceptance.exs` starts an isolated Postgres database and the app on port 4758. It copies the existing form-engine bead projection through a read-only SQL query, then fetches GitHub through Runtime and Oban. It does not run bd. Its deliberately nonexistent beads path prevents any store access. The screenshots therefore show beads health as unreachable; that is an acceptance isolation choice, not a GitHub failure.

The live response and browser assertions agree:

| PR | Head | Base | Linked tickets |
| --- | --- | --- | --- |
| #5 | pr/scheduler | main | fe-813.3, fe-lwp.15 |
| #6 | pr/time-model | pr/scheduler | fe-813.2 |

`fe-813` shows **2** open CRs. The browser opens the linked ticket sheet, checks its GitHub URL, and finds zero merge buttons. Manual refresh completes through the worker and resets the snapshot age. Browser console errors and mobile page overflow are both zero.

Screenshots captured and inspected:

- Pull requests: [light](../acceptance/bb-forge/pull-requests-light.png), [dark](../acceptance/bb-forge/pull-requests-dark.png).
- Initiatives with CRs: [light](../acceptance/bb-forge/initiatives-light.png), [dark](../acceptance/bb-forge/initiatives-dark.png).
- [Mobile](../acceptance/bb-forge/pull-requests-mobile.png).

The sidebar, header, project navigation, indented stack cards, branch/SHA/check badges, and bead links follow the mockup. Merge controls and its illustrative machine are omitted for .9. I corrected cramped mobile cards by placing their status below the content, and added separation between titles and badges. The final screenshots include those changes.

Machine-readable checks are in [evidence.json](../acceptance/bb-forge/evidence.json). The browser verifier is `tools/forge-acceptance.cjs`. Recorded read-only API responses and their provenance are under `test/fixtures/forge/`.

## Coordinator review follow-up

All three review requests are addressed:

- Removed the PR subtitle and footer. Waiting, error, empty, and no-remote messages are short status labels. Refresh shows `Refreshing`, then `Updated` or `Refresh failed`. Coalesced requests show `Up to date` or `Rate limited`; a recent failed read never shows `Up to date`. `Board.Forge.RefreshStatus` declares the feedback lifecycle, with a generated golden.
- The page reuses `TicketDetail.timestamp`, including its full ISO timestamp in `title` and `datetime`. The shared `RelativeTime` formatter now uses `just now` below a minute and keeps `2 min ago` for minutes. The browser verifies that refresh changes the actual timestamp, not merely its display text.
- Confirmed the sidebar is not coupled to forge health. A read-only query of the acceptance database returned `form-engine | beads: unreachable | reason: unreachable | forge: fresh | forge error: NULL`. The scratch path intentionally does not exist. A regression test starts with healthy beads, applies forge failure and success, and verifies identical beads health and no `down` badge. Only a subsequent beads `unreachable` observation produces `down`. No sidebar production fix was needed, and screenshots retain the truthful scratch warning.

The new copy, refresh-result, and shared-time assertions failed before their fixes. The health-isolation test passed unchanged and confirms the existing separation. I reran browser acceptance and inspected all five replacement screenshots. One later LiveView run failed its wall-clock assertion at the exact two-minute cutoff. That fixture now uses 150 seconds; fixed-clock unit tests retain exact boundary checks. Both final test runs pass.

Lesson: I copied explanatory mockup prose into the product instead of limiting UI text to labels, status, and controls. Prevention uses automated checks: LiveView and browser assertions reject header/footer prose and enforce short refresh results and human timestamps. No lesson bead was created because this worktree forbids bd commands; the coordinator can record it.

Follow-up review found no remaining Important or Critical issue. Standards use the shared timestamp component and a declared refresh machine. Spec covers all three requests. Risk checks cover shared time formatting, failed-refresh feedback during cooldown, and unchanged beads health.

## Final gates

All commands exited 0:

```text
mix precommit
  Repository hygiene: no license material or operator paths detected
  4 properties, 210 tests, 0 failures

mix test <forge contract, GitHub, lifecycle, stack, store, sync, LiveView and shared time files>
  24 tests, 0 failures

BOARD_ROLE=web mix assets.build
  Tailwind and esbuild completed successfully

NODE_PATH=<Playwright node_modules> node tools/forge-acceptance.cjs
  Forge browser acceptance: stack, bead sheet, CR count, light/dark,
  mobile and console checks passed

git diff --check
  clean
```

Full outputs: [precommit](../acceptance/bb-forge/precommit.txt), [forge tests](../acceptance/bb-forge/forge-tests.txt). The default test database and the isolated `MIX_TEST_PARTITION=forge` database both passed the full gate during this session. A transient empty migration was applied during initial setup; I removed only that migration's version record after confirming its table was absent, then reran the normal migration and gate.

Changed: forge adapters, worker reads, observed-event persistence, PR page, epic counts, and ticket links.

Verified: both adapter contracts, negative API cases, stage transitions, stack ordering, live GitHub reads and manual refresh, the five inspected screenshots, and the final gates above. No Critical or Important review finding remains open.

Not verified: forge mutations, separate release-node deployment, more than 100 open PRs, or credential renewal without restart. Mutations remain disabled for .9; the other limits are explicit above. The test-first ordering limitation for the initial sync executor is recorded under Standards.
