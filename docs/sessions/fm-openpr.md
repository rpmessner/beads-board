# fm-openpr: fm-zgd.4

Status: complete, including the final gate below. No commits, direct pushes, ticket edits, bd commands, subagents, or installed-service changes. The isolated port-4774 server is stopped.

## Changes and guards

- `Requests.OpenPr` registers immutable facts, creation validation and transactional approval enqueue. Repo identity comes from configuration, not caller-supplied remote data.
- `Requests.OpenPrJob` runs on `external_writes`, with only a request ID, one attempt and a 60-second timeout. The request machine commits the start audit before IO. It checks Preview, capabilities, configuration, committed stage, live base/head refs and absence of an open PR for that head.
- GitHub adds `create_change_request/3` and `branch_sha/3`. POST uses the exact named head, base, title and body. Req disables redirects and retries. Errors are fixed classifications, not raw responses. The fake implements the same boundary, and both run the contract suite.
- Worker snapshots now include branch SHAs. Creation and approval use those observations without web credentials. The worker's regular reconciliation supersedes moved pending heads and fails orphaned executions after terminal/pruned jobs or a 90-second lease.
- Needs you displays repository, head, full SHA, base, title and body. It preserves body whitespace, the shared Note field and adjacent Approve/Decline controls. Recent outcomes and the ticket Requests tab reuse the facts component.
- Requests never send ticket-stage events. `Forge.SyncJob` and `Forge.Store` remain the path to `pr_open`.

```sh
foreman ask open_pr <ticket> --project <key> --head <branch> --sha <sha> \
  --base <branch> --title "Title" --body-file /path/to/body.md
foreman wait <request-id> --timeout 60
```

The CLI preserves file bytes and keeps never-fail behavior, including unreadable body files. No migration or dependency was added.

## Live run and browser evidence

The final run used `foreman_acceptance_fm-openpr`, port 4774 and synthetic Postgres tickets. `/tmp/fm-openpr-scratch` is a clone of the authorized scratch repo. Its fixture branch points at an existing child commit; no fixture commit was needed. The CLI posted a push request, the browser approved it, and the actual worker published the branch. It then posted and approved the open-PR request.

| Fact | Final value |
| --- | --- |
| PR | [#4](https://github.com/rpmessner/beads-board-scratch/pull/4) |
| Head | `acceptance/fm-openpr-1792363240698` |
| SHA | `2e8aa23947317903351a25bbffe97b9c9e319557` |
| Base | `main` |
| Title | `openpr-2: Exact approval title` |
| Body | `Open PR acceptance.\n\nExact body, including trailing newline.\n` |
| Request | `f8057b23-4c47-47cc-95e6-eae639237337` |
| Push request | `381d5266-3d3b-4962-a351-266a784503c3` |
| Stage before read | `committed` |
| Stage after ordinary SyncJob | `pr_open` |

[CLI transcript](../acceptance/fm-openpr/transcript.json), [live result](../acceptance/fm-openpr/live-result.json), [create response](../acceptance/fm-openpr/observed-create.json), [observed stage and snapshot](../acceptance/fm-openpr/observed-stage.json), and [audit](../acceptance/fm-openpr/audit.json) record the run. Each approved write has exactly ask, approve, start, succeeded. The recording transport accepts only the scratch remote and never saves headers or credentials. A memory-only token scan found no credential in the artifacts. The [contract fixture](../../test/fixtures/forge/live-openpr/create.json) is the final real response.

All four final captures were opened and inspected: [390 light](../acceptance/fm-openpr/openpr-390-light.png), [390 dark](../acceptance/fm-openpr/openpr-390-dark.png), [1440 light](../acceptance/fm-openpr/openpr-1440-light.png), [1440 dark](../acceptance/fm-openpr/openpr-1440-dark.png). Full SHA and body wrap without overflow, fields remain legible, actions share a row, and the card aligns with the heading. The [observed ticket](../acceptance/fm-openpr/observed-ticket.png) was also inspected. [Browser output](../acceptance/fm-openpr/browser.txt) reports zero browser errors.

The initial pre-rebase run created PR #3, then needed a read-only completion check because its browser assertion expected `PR open` rather than the existing `pr_open` label. Its records remain under [initial](../acceptance/fm-openpr/initial/). The corrected complete runner passed after rebasing, creating #4. Both PRs and both scratch branches remain; no cleanup writes were made.

## Review scope

Baseline `f1b4f91fdae5b78c37ae88be5a5ce7678ea6265c` initially equalled HEAD. At the coordinator's request, this branch rebased onto main at `70c7f83`. The baseline-to-HEAD diff now contains only inherited preview work (`c7d89b8`, merged by `70c7f83`). This session's code remains uncommitted. Review covers its working-tree diff and new deliverables, plus integration with the inherited preview boundary. The coordinator-owned brief and unrelated inherited preview implementation are excluded. Axes ran Standards, then Spec, then Risk.

### Standards

Reviewed root/app AGENTS, the house baseline, request/forge modules, CLI, card, tests and acceptance tools. The existing `Foreman.Request` machine owns every transition; the new kind supplies validation and transactional enqueue. No separate status lifecycle or migration was added. LiveView retains streams, shared timestamps, `to_form`, existing decision/push IDs, and labels/status/controls only. The action form is shared; push and PR fact rendering remain separate.

The post-rebase check uses the merged `Foreman.Preview` module unchanged. Its guard runs before credential lookup or forge IO. No temporary preview shim remains.

No Critical or Important finding. Declined to judge: unrelated lifecycle machines, inherited preview implementation beyond this integration, and installed deployment. Verdict: ready.

### Spec

Checked fm-zgd.4 and Decisions 2, 3 and 6. The CLI names project/head/SHA/base/title/body-file, preserving body bytes. Creation refuses uncommitted and disabled-forge asks. Approval enqueues one ID-only job; the worker rechecks remote head SHA, base existence, open PR absence, capabilities, configuration and ticket stage. Pending observed movement supersedes. The ordinary SyncJob read, not the write response, changes the ticket stage.

Scratch PRs #3 and #4 have their exact approved heads, bases, titles and bodies. The final post-rebase run records `committed` after creation and `pr_open` after SyncJob. Both adapters replay #4's captured create response. Four replacement responsive/theme captures were opened and inspected. The initial runner expected `PR open`, but the existing sheet displays `pr_open`. The corrected complete runner passed on #4.

Ruling: creation/approval use the worker's last branch snapshot, matching the existing stored-default push pattern. Only the worker has credentials; it checks live facts before writing. Pending reconciliation reads the live head. No credential was added to the web role.

No open Critical or Important finding. Declined to judge: later request kinds, notifications and dispatch integration. Verdict: ready.

### Risk

The safety fact is the durable one-shot start audit before IO. A second start cannot execute, and an orphaned request never retries. Independent database connections raced the start and recorded one winner. A supervised task was killed after the fake forge accepted creation but before the response returned. Rescue recorded `outcome unknown`, kept the one PR, and recorded no second start. Ambiguous responses and two separately approved asks also created only one PR. These are proof level 4. Both live browser runs reached level 5 through actual Oban workers and single-attempt audits.

Important findings fixed:

- The first branch-snapshot implementation rejected repos with more than 100 branches, which would break existing PR reads. A failing-first regression now follows branch cursors and retains later branches without dropping PRs. Repeated cursors and incomplete pages fail closed.
- A rate-limited branch continuation initially lost the cooldown classification. The failing-first regression now returns `rate_limited`, as the initial page does.
- The coordinator's preview requirement is enforced before credential access. Its failing-first test now passes with forge options removed and a forge that raises on IO. The inherited guard returns `refused in preview`.

Cleared by tests: creation refusals, moved/missing heads, missing bases, an existing PR, changed configuration including removal during the last network read, changed ticket stage, disabled capability, wrong response URL, redirects, transport retries, and credential-bearing error output. Failed head reads do not supersede a pending request. Removing the final live-head guard caused three test failures; the mutation was restored.

Residual limits: GitHub has no atomic expected-SHA parameter for PR creation. Another actor can move a branch between the final read and POST. The named branch/base and exact text remain fixed, but this final network race cannot be removed by the adapter. Creation uses the latest worker snapshot and can refuse a newly pushed head until refresh. Reads retain the existing 100-open-PR limit; branch pages now paginate within the sync/job timeouts. Unknown outcomes require observation and a new request, never retry-in-place.

Declined to judge: writes outside scratch, live worker-kill injection, installed deployment, and hostile concurrent operator changes. The worker-kill test uses the stateful fake forge. Cheapest check: the open-PR, forge contract, GitHub transport and request-commit tests. Verdict: ready; no open Critical or Important finding.

## Test-first evidence and limits

The create contract failed against `:todo` implementations for both adapters. Creation stage/configuration validation, observed guards, approval enqueue/worker completion, pre-approval superseding, reconciliation, CLI flags, card facts, preview refusal and both pagination fixes have failing-first outputs in `docs/acceptance/fm-openpr/red-*.txt`.

The standalone branch-read contract, job guard rechecks, ambiguous-response and post-write-kill tests were added after the shared guards and one-shot interpreter existed. They are regression evidence, not claimed red-first evidence. [Removing the final live-head guard](../acceptance/fm-openpr/mutation-head.txt) caused three failures. That mutation is absent from the final code.

Initial dependency setup required `mix deps.get`. The first precommit attempt caught operator checkout paths in two captured logs; those paths are replaced with `<checkout>`. No product assertion was weakened. The initial browser label failure and its successful full replacement are recorded above.

## Final gates

[Focused suite](../acceptance/fm-openpr/focused-tests.txt), seed 848212, exit 0:

```text
mix test test/foreman/open_pr_test.exs test/foreman/forge_contract_test.exs \
  test/foreman/forge_github_test.exs test/foreman/request_commit_test.exs \
  test/foreman_web/live/needs_you_live_test.exs
54 tests, 0 failures
```

[Precommit](../acceptance/fm-openpr/precommit.txt), seed 922677, exit 0:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
5 properties, 464 tests, 0 failures
```

`MIX_ENV=acceptance mix assets.build`, `node --check tools/openpr-acceptance.cjs`, the final browser run and `git diff --check` passed. The final application gates emitted no warnings. Initial dependency compilation emitted the existing Oban unused-clause warning.

Unit tests use `foreman_test_fm-openpr`; live acceptance uses `foreman_acceptance_fm-openpr`. The installed service, configuration and database were untouched. Port 4774 no longer listens.

Changed: the guarded open-PR kind, worker, forge callbacks, CLI and card.
Verified: exact live PR facts, single-attempt audit, observed-only stage, both adapter contracts, guards, rescue, preview refusal, four inspected responsive/theme captures, and the full gate.
Not verified: installed deployment and destructive live worker-kill injection, neither required for this ticket. No fm-zgd.4 acceptance item remains open.
