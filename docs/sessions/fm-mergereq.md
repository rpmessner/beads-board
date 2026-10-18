# fm-mergereq: fm-zgd.5

Implemented and verified on branch `fm-mergereq`. No commits, pushes, ticket edits, bd commands, subagents, or live GitHub writes. The installed service, configuration and database were untouched. The isolated acceptance server on port 4785 is stopped.

## Changes and flow

- `Requests.Merge` registers the merge kind and validates the configured forge, write capability, PR, expected head and existing merge eligibility.
- `Requests.confirm_merge/3` commits request approval/start, the existing merge intent and its action-ID linkage in one transaction. The linkage lives in `outcome.result.action_id`; no schema migration is needed.
- Needs you displays repository, PR and full expected head. Approve opens the existing PR-page confirmation. The ask stays pending until final confirmation, so Cancel neither approves nor merges. Notes stay in Postgres, not the navigation URL.
- The existing worker tick calls `Requests.reconcile_merges/0`. Pending closed/moved facts supersede. Executing requests follow the existing merge audit through retargeting to a terminal outcome. A partial merge resolves failed while retaining its merge SHA. Rescued writes use the existing unknown-outcome policy and never retry.
- The merge and retarget jobs, adapters, audit uniqueness, preview policy and all merge rules are unchanged. The original PR-page Merge button remains available.

CLI syntax:

```sh
foreman ask merge <ticket> --project <repo-key> --pr <number> --sha <expected-head>
foreman wait <request-id> --timeout 60
```

## Evidence

Tests use `foreman_test_fm-mergereq`. The browser and actual escripts use `foreman_acceptance_fm-mergereq`, port 4785, synthetic tickets and `Foreman.Forge.Fake`. The acceptance process drains actual Oban jobs and then calls request reconciliation. It does not run a repository reader.

[Browser output](../acceptance/fm-mergereq/browser.txt), [CLI transcript](../acceptance/fm-mergereq/transcript.json) and [outcomes](../acceptance/fm-mergereq/evidence.json) prove:

- Approval opens confirmation with zero queued jobs. Cancel leaves the request pending.
- Waiting escripts return done after merge/retarget, failed after refusal or merge failure, and failed with a merge SHA after retarget failure.
- Each confirmed request has one start and one terminal audit event. Every escript exits 0.
- Both themes at both widths have no document overflow or browser errors.

All eight final screenshots were opened and inspected after the final browser rerun:

| View | 390 light | 390 dark | 1440 light | 1440 dark |
| --- | --- | --- | --- | --- |
| Request | [image](../acceptance/fm-mergereq/card-390-light.png) | [image](../acceptance/fm-mergereq/card-390-dark.png) | [image](../acceptance/fm-mergereq/card-1440-light.png) | [image](../acceptance/fm-mergereq/card-1440-dark.png) |
| Confirmation | [image](../acceptance/fm-mergereq/confirm-390-light.png) | [image](../acceptance/fm-mergereq/confirm-390-dark.png) | [image](../acceptance/fm-mergereq/confirm-1440-light.png) | [image](../acceptance/fm-mergereq/confirm-1440-dark.png) |

The existing MVP merge runner also passed on this server. Only its database/output destination became configurable; its assertions are unchanged. [Output](../acceptance/fm-mergereq/mvp-browser.txt) and [evidence](../acceptance/fm-mergereq/mvp/evidence.json) cover check 8, including top-of-stack refusal, moved head, merge/retarget and observed ticket progression.

## Review scope

Baseline `ca7854ca178464e05702c442011250376126cc16` equals HEAD; committed three-dot diff and commit list are empty. The requested review covers the working-tree diff and new deliverables, excluding the coordinator-owned brief. Axes run sequentially.

### Standards

Reviewed AGENTS, the house baseline, request kind/context, CLI, runtime tick, LiveViews, shared cards, tests and acceptance tools. Existing `Foreman.Request` and `Foreman.Merge.Action` machines own transitions; the request ID and confirmation note are routing data. Merge approval/start, the existing merge intent and its action-ID linkage share one transaction. No migration, dependency, user-input atom conversion or new external write path.

The shared action card preserves push DOM IDs; merge and push have the same form structure and separate fact components. Streams and human timestamps remain. All eight request-card/confirmation screenshots were inspected at 390/1440 in light/dark: aligned content, visible inputs, wrapped SHA, no clipping or overflow.

Minor finding fixed: the merge kind's enqueue contract is now an API doc. Pending reconciliation deliberately reuses the locked approval precheck: unchanged merges return `confirmation_required` and cannot approve or enqueue. Declined: unrelated existing state machines and installed deployment. No Critical or Important Standards finding.

### Spec

Checked every fm-zgd.5 acceptance item, approved Decision 6 and MVP Decision 10/check 8. The CLI names PR/head; Needs you approval opens the original confirmation; final confirmation alone commits approval/start and an existing merge intent. Cancel leaves the ask pending. Closed/moved facts supersede before approval; jobs retain every original guard. Terminal action audits resolve requests, preserving partial merge evidence and reaching actual waiting escripts.

Important finding fixed at `lib/foreman/requests/merge.ex:5`: creation initially checked only PR existence, head and forge capability, omitting the spec's early eligibility guards. A failing-first test accepted a non-bottom PR. Creation now calls the existing `Merge.prepare/2`, covering bottom-of-stack, draft, checks and mergeability without duplicating rules.

The unchanged MVP fake-forge browser runner passed top refusal, expected-head refusal, successful merge/retarget and observed-only ticket progression/close suggestion. No scope expansion into live writes or other request kinds. Declined: live GitHub repetition (recorded contracts and fake acceptance are requested), notifications and skill integration owned by other tickets. No open Critical or Important Spec finding.

### Risk

Safety fact: both UI paths call the same `Merge.enqueue/3`; its remote/PR/head uniqueness and the original job's one-shot claim still protect every external write. Request approval/start and the action-ID linkage commit under the existing per-repository lock. No merge or retarget job, policy, adapter or preview guard was changed. Reconciliation only observes that audit and submits machine events; repeated terminal observations cannot overwrite the first outcome.

Proof level 4: 45 focused tests passed, including independent database connections racing two confirmations and competing terminal outcomes, ordinary/request path deduplication, worker replay, timeout reconciliation, and existing job guards. Proof level 5: real CLI/browser requests reached done, refused, failed and partial outcomes with one start and one terminal event each. Removing the expected-head guard caused two regression failures; the mutation was restored.

Important findings fixed with failing-first regressions:

- `lib/foreman_web/live/needs_you_live.ex:20`: approval initially put the Note in the navigation query. It now stays in the pending request row, so user text does not enter browser URLs or hit URL length limits. The final approval audit retains it.
- `lib/foreman_web/live/pull_requests_live.ex:230`: the request query initially survived Cancel and successful confirmation. A later page patch could reopen confirmation or overwrite the action status with "Request unavailable." Both exits now clear request routing through a LiveView patch.

Cleared: direct approval bypass, double approval, resolution twice, competing ordinary merges, stale expected head, partial retarget evidence, rescued jobs, preview guard bypass, push card DOM stability and observed-only ticket stages. Cheapest check: the focused command recorded below. Declined: installed deployment, live GitHub repetition, and changes to the existing forge race/ambiguous-outcome policy. Residual: approval checks observed snapshots; the existing job re-reads live facts and remains the final authority. No open Critical or Important Risk finding.

## Test-first record

Creation first failed with `unsupported_kind`. Direct approval first advanced to approved instead of requiring confirmation. The confirmation/outcome test failed against a `:todo` stub before the transactional link and reconciliation existed. The initial inbox test crashed on decision-only rendering, then failed on the missing merge card against a minimal stub. CLI parsing first rejected `--pr`.

Creation eligibility, URL note handling and clearing the request route have failing-first regressions. Saved failures: [note URL](../acceptance/fm-mergereq/red-note-url.txt), [route](../acceptance/fm-mergereq/red-route.txt). [The SHA mutation](../acceptance/fm-mergereq/mutation-head.txt) produced two failures and was restored. Partial/refused outcome cases and independent-connection concurrency tests were added after the shared mechanism; they are regression evidence, not claimed failing-first evidence.

Initial setup required `mix deps.get` and emitted the existing Oban dependency warning. Browser setup first caught an incorrectly lengthened fixture SHA and a psql timing setting; the fixture was restored and the runner now uses `psql -X`. Final runs emitted no application warnings or browser errors. An optional screenshot-contact-sheet helper lacked Pillow; the eight screenshots were instead opened individually.

## Final gate

[Full output](../acceptance/fm-mergereq/precommit.txt), exit 0, seed 824294:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
5 properties, 445 tests, 0 failures
```

[Focused risk checks](../acceptance/fm-mergereq/risk-tests.txt), exit 0:

```sh
mix test test/foreman/merge_request_test.exs test/foreman/request_commit_test.exs \
  test/foreman/merge_job_test.exs test/foreman_web/live/pull_requests_live_test.exs
# 45 tests, 0 failures
```

`MIX_ENV=acceptance mix assets.build`, the acceptance escript build, both browser runners, both JavaScript syntax checks and `git diff --check` passed. The final browser rerun followed the note/route fixes. Follow-up Standards, Spec and Risk checks found no open Critical or Important issue.

Changed: guarded merge asks, confirmation routing and request outcomes through the existing merge action.
Verified: all fm-zgd.5 acceptance items, fake-forge MVP check 8, real CLI waits, eight inspected screenshots and the full gate.
Not verified: installed deployment or new live GitHub writes, both outside this session's scope.
