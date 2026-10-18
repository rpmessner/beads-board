# bb-merge: bb-c2w.9

Implementation and fake-forge acceptance are complete. Scratch-repo live acceptance and live mutation recordings await coordinator authorization. No GitHub writes, commits, pushes, bd commands, or subagents. The coordinator brief is untouched. The temporary server on port 4768 is stopped.

## What changed

- `Board.Merge` owns eligibility, confirmed facts, durable intent, deduplication, claims and audit reconciliation. The new `merge_actions` table records repository, PR, confirmed SHA, actor, immutable confirmation facts, state, error, merge SHA and timestamps.
- `Board.Merge.Action` declares the six-state lifecycle. `MergeJob` and `RetargetJob` run on the worker's single-slot `external_writes` queue. Oban arguments contain only the audit ID.
- GitHub uses Req REST `PUT /pulls/:number/merge` with `merge_method: "merge"` and `sha`, then `PATCH /pulls/:child` with `base`. Redirects and transport retries are disabled. Errors are sanitized. The fake implements the same mutation contract atomically.
- The PR page adds a Fluxon confirmation modal, job status, weaker-guard/manual-retarget labels, and duplicate-attempt feedback. Ticket detail shows `bd close <id>` only for the merged stage with a persisted `suggest(close_bead)` effect.
- `Board.Forge.adapter/0` and `options/0` select the runtime adapter without storing credentials in jobs. The default remains GitHub; the acceptance process explicitly selects the fake. SyncJob uses the same boundary.

Migration: `priv/repo/migrations/20261018073018_create_merge_actions.exs`. Apply it before starting the new code. No existing table is altered.

## Machine table

Full generated matrix and diagram: [action.md](../machines/action.md).

| From | Event and guard | To | Effect |
| --- | --- | --- | --- |
| idle, failed, merged | request; eligible and writes enabled | confirming | none |
| idle, failed, merged | request; refused | stay | refused status |
| confirming | cancel | idle | none |
| confirming | confirm; head unchanged, native guard | merging | enqueue merge |
| confirming | confirm; head unchanged, weaker guard | merging | verify head, enqueue merge |
| confirming | confirm; head moved or writes disabled | stay | head-moved status |
| merging | merge_ok; child and retarget capability | retargeting | enqueue retarget |
| merging | merge_ok; child without retarget capability | merged | manual-retarget status |
| merging | merge_ok; no child | merged | none |
| retargeting | retarget_ok | merged | none |
| merging | merge_failed or job_timeout | failed | failed status |
| retargeting | retarget_failed or job_timeout | failed | manual-retarget status |
| all other pairs | any | invalid | none |

## Job rules

1. Commit the audit and Oban job together before external IO. Deduplicate by remote, PR number and confirmed SHA. Claim each phase once with a database compare-and-set.
2. Revalidate enabled repository identity and adapter write capability. Fetch current forge data, including an explicit tracked PR.
3. Require an open PR targeting the default branch, not draft, checks `success` or `none`, and mergeability `mergeable`.
4. Match the confirmed head SHA, default branch, source branch and child identity. Refuse multiple children. A weaker adapter performs another immediate read and validation.
5. Send a merge commit with the expected SHA. Record its returned merge SHA before scheduling the child retarget.
6. Before retargeting, re-read the confirmed child. Require it to remain open with the same source and either its original base or the already-correct default base. Revalidate configuration and capabilities.
7. Preserve merge evidence on retarget failure and show the manual step. Never delete a branch, run local git or write beads.
8. Never replay an attempted write. Ambiguous responses remain `outcome_unknown`; terminal jobs and expired claims reconcile through `job_timeout`. The next ordinary forge read alone drives `cr_merged` and the ticket suggestion.

## Browser evidence

`tools/merge-acceptance.exs` runs on port 4768 with a dedicated `beads_board_merge_acceptance` database, fake forge, synthetic Postgres projection and no beads reader. The browser drives the real LiveView. Test-control notifications drain one actual Oban job at a time, exposing merging and retargeting separately. They are not production HTTP endpoints.

`tools/merge-acceptance.cjs` passed top-of-stack refusal, confirmation facts, a head moved before job execution, merge failure, partial retarget failure, successful merge/retarget and subsequent observed stage. It checks that the ticket remains `pr_open` with no close suggestion before the observation. Console errors and mobile overflow are zero.

Screenshots captured and inspected:

- Confirmation: [light](../acceptance/bb-merge/confirm-light.png), [dark](../acceptance/bb-merge/confirm-dark.png).
- [Merging](../acceptance/bb-merge/merging.png), [retargeting](../acceptance/bb-merge/retargeting.png), [moved head](../acceptance/bb-merge/head-moved.png), [partial failure](../acceptance/bb-merge/partial-failure.png).
- Merged: [light](../acceptance/bb-merge/merged-light.png), [dark](../acceptance/bb-merge/merged-dark.png), [ticket suggestion](../acceptance/bb-merge/merged-ticket.png), [mobile](../acceptance/bb-merge/mobile.png).

The final modal uses Fluxon's solid primary action, full SHA, linked bead badge and explicit original/target child branches. Layout, wrapping, contrast and focus overlay were inspected. [evidence.json](../acceptance/bb-merge/evidence.json) contains the browser assertions.

## Planned live run, not executed

Wait for the coordinator to confirm that the user-approved scratch repository exists and authorize the run. No real repository is used as a substitute.

1. Verify the exact scratch owner/repo, its default branch, merge-commit support and disabled automatic branch deletion. Use an isolated database and port, containing only that remote and synthetic linked ticket projections. No bd commands or real beads-store changes.
2. In the authorized scratch repo, prepare two PRs stacked on the default branch. Record their head SHAs and bases. All fixture setup writes stay inside that repo.
3. Through the board, request the top PR and verify refusal without a mutation request.
4. Open the bottom PR's confirmation. Advance its scratch head before confirming, then verify refusal, an audit error and no merge. Refresh and reopen confirmation at the new SHA.
5. Confirm the bottom PR. Capture the sanitized PUT request and response. Verify the resulting merge commit has the confirmed head as a parent and targets the default branch.
6. Capture the child PATCH and verify its base is the default branch. Verify both source branches still exist.
7. Run the next read. Verify the linked ticket changes from `pr_open` to `merged` through `cr_merged`, and the sheet shows the `bd close` suggestion without executing it.
8. Save sanitized live responses under `test/fixtures/forge`, replacing the synthetic mutation examples in the shared contract tests. Re-run both adapter contracts, browser checks and precommit. Record actual PR numbers, commit SHAs and screenshots here.

Current mutation tests use synthetic success/error bodies and Req.Test transport failures. Existing list tests still use the recorded read fixtures. No live mutation recording is claimed.

## Review baseline

`ebdba9b0af14079cff3256c32eae82e87fdfa919` is HEAD. The committed three-dot diff and commit list are empty. This review covers the explicitly requested working-tree diff and new deliverables, excluding `docs/briefs/bb-merge.md`. Axes run sequentially in this session.

### Standards

Reviewed the local AGENTS rules, house baseline, new machine/job/persistence modules, adapters, LiveView, ticket sheet, tests and harness. The six-state `Board.Merge.Action` owns confirmation and durable job transitions; its matrix and diagram have a golden test. Claim timestamps are one-shot IO ownership, not a second workflow. Streams remain in use for PR cards; times use the shared human formatter. The modal is Fluxon, with server-bound dismissal and no explanatory prose.

No Critical or Important Standards finding. The minor visual finding was fixed: confirmation now uses Fluxon's primary solid button instead of matching Cancel. Declined: changing existing view structure, unrelated machines, or formatter rules. Verdict: ready.

### Spec

Checked bb-c2w.9 acceptance, Decisions 9–10, design section 9 and the mockup. Both adapters now implement writes before declaring `write: true`. The job re-reads and checks bottom-of-stack, draft, checks, mergeability and confirmed head; the GitHub request is a merge commit with `sha`. Confirmation includes PR, target, full SHA, linked beads, guard strength and child retarget. No branch deletion or local git command exists. The audit precedes IO. The stage stays `pr_open` after job success until the next forge observation; the sheet then shows the persisted `suggest(close_bead)` entry effect.

The fake browser run covers top-of-stack refusal, all progress phases, moved head, merge failure, partial retarget failure, observed stage and the close suggestion. Conservative ruling: a branching stack with several children is refused (`multiple_children`) rather than silently choosing a child that was not confirmed.

No Critical or Important implementation finding. Deferred by explicit instruction: scratch-repo live acceptance and replacing synthetic mutation responses with recordings from that run. Declined: scratch creation, real GitHub writes, branch cleanup and additional forge adapters. Verdict: ready for the authorized live gate, not yet live-verified.

### Risk

Safety fact: every write requires a committed audit intent and a one-shot claim. A replay cannot send a second merge, and the native merge request carries the confirmed head SHA. Jobs never post ticket-stage events. This reached proof level 4 in job/contract tests and level 5 in the fake browser app. Live GitHub proof remains blocked.

Important findings fixed:

- `lib/board/merge.ex:98`: a dead worker could leave an action busy forever if its Oban job stayed executing or was pruned. Reconciliation now steps `job_timeout` for terminal jobs or claims older than 90 seconds. Both jobs have 60-second execution limits. A failing-first regression deletes the job and ages its claim.
- `lib/board/merge.ex:140`: a losing audit compare-and-set still enqueued a retarget. Effects now run only when exactly one audit row changed. A failing-first regression races a completed timeout against a stale merge result.
- `lib/board_web/live/pull_requests_live.ex:80`: a repeated request opened a confirmation although deduplication would prevent execution. The UI now loads the recorded outcome instead. The regression failed on the open modal before the fix.

Cleared: moved heads; bypassing UI eligibility; disabled write capability; missing native head guard; missing retarget capability; configuration removal; changed child/base; duplicate enqueue and worker replay; transport ambiguity; partial merge/retarget failure; response validation; retries and redirects; observed-only ticket transitions. No branch deletion or local git execution exists.

Residual limits: GitHub cannot atomically guard a base-branch edit or check rerun with the head SHA. The job re-reads immediately, but another actor can still change those facts in the final network gap. Retarget has the same base-edit race. Repository protections remain authoritative. Unknown outcomes and failures never retry automatically; a same-remote/PR/SHA attempt remains recorded, so recovery at that SHA is manual. PR cards remain the last read snapshot until the next read.

Declined: actual GitHub writes, destructive live failure injection, extra adapters and operator recovery UI. The cheapest safety check is the five focused test files listed below. Verdict: ready within the stated live-run boundary; no Critical or Important implementation finding remains.

## Test-first and mutation evidence

The adapter contract, LiveView confirmation flow and close suggestion failed on assertions before implementation. The initial machine/job tests first failed because their modules were absent, rather than against minimal stubs; that is a test-first ordering limitation, not a claimed assertion-level red. The timeout, lost-update and duplicate-confirmation fixes have assertion-level failing-first regressions.

Mutation checks then verified the key safety boundaries against working code. Removing the machine's write-capability guard produced [1 failure](../acceptance/bb-merge/mutation-machine.txt). Bypassing the job's fresh validation produced [3 failures](../acceptance/bb-merge/mutation-rules.txt). Changing GitHub's merge method to squash produced [1 contract failure](../acceptance/bb-merge/mutation-contract.txt). Every mutation was restored before the final passing gate.

## Final gates

All final commands exited 0:

```text
MIX_TEST_PARTITION=_merge mix precommit
  Repository hygiene: no license material or operator paths detected
  4 properties, 233 tests, 0 failures

MIX_TEST_PARTITION=_merge mix test \
  test/board/merge_action_test.exs test/board/merge_job_test.exs \
  test/board/forge_contract_test.exs test/board/forge_github_test.exs \
  test/board_web/live/pull_requests_live_test.exs
  34 tests, 0 failures

MIX_ENV=test BOARD_ROLE=web mix assets.build
  Tailwind and esbuild completed successfully

NODE_PATH=<Playwright node_modules> node tools/merge-acceptance.cjs
  Fake forge browser acceptance passed

 git diff --check
  clean
```

Outputs: [precommit](../acceptance/bb-merge/precommit.txt), [focused tests](../acceptance/bb-merge/focused-tests.txt).

One earlier full run had an unexplained LiveView redirect in the existing `InitiativesLiveTest` at line 235. [Failure output](../acceptance/bb-merge/precommit-transient-failure.txt) is retained. The entire affected file passed, the full suite passed with the same seed ([output](../acceptance/bb-merge/seed-recheck.txt)), and the final precommit passed with a new seed. No assertion was weakened and no speculative fix was made. Its cause is not established; it is not claimed fixed or attributed to database interference.

Tests used isolated partitions (`merge` initially, `_merge` after the coordinator's notice), never the shared unpartitioned database. The browser used a separate acceptance database. Initial dependency setup and an intermediate formatting check failed; dependencies were installed and formatting corrected before the final gates.

Changed: guarded merge/retarget, audit persistence, confirmation/progress UI, observed close suggestion, contracts and acceptance tools.

Verified: final full and focused suites, mutation checks, fake-forge browser flow, inspected light/dark screenshots and mobile layout. All Critical and Important implementation findings are closed.

Not verified: scratch GitHub writes, actual merge-commit parentage and branch retention there, live mutation recordings, and the cause of the single non-reproducing test redirect. Do not close bb-c2w.9 until the authorized live gate and fixture refresh pass.
