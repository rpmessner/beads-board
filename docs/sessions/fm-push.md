# fm-push — bb-zgd.3

Status: complete, including the authorized advancing live default-branch push. No commits in this worktree, shell pushes, bd commands, subagents, installed-service changes, or installed-database access. The only new commit is the explicitly authorized fixture in `/tmp/fm-push-scratch`. The isolated port-4773 server is stopped.

## Changes and guards

- `Requests.Push` registers push creation validation and transactional approval enqueue. Facts bind the configured remote, worktree, local branch, expected SHA and remote branch. The default-branch rule checks both projected parent-child edges and board-side epic links.
- `Requests.LocalRefs` reads `.git`, `commondir`, loose refs and `packed-refs` directly. Same device/inode identifies the common directory. No local Git read subprocess runs in production.
- `Requests.PushJob` uses the existing `external_writes` queue, one attempt, a 60-second timeout, and the existing request machine/audit. It rechecks live configuration, ticket stage, default branch, epic membership, worktree identity, config safety and local SHA. Git's non-forced push is the final receive-side fast-forward guard.
- `Requests.reconcile_pushes/0` runs from the worker's three-second tick. Moved pending refs supersede. Missing/terminal jobs or claims older than 90 seconds become failed/unknown. Approval also checks movement under the repository lock.
- Needs you renders all five push facts, full SHA, shared human time, Note, Approve and Decline. Recent outcomes and the ticket Requests tab reuse the fact component. Existing decision form IDs and unfinished inputs remain stable.

CLI:

```sh
foreman ask push <ticket> --project <repo-key> \
  --worktree /absolute/worktree --branch <local-branch> \
  --sha <40-character-sha> --remote-branch <destination>
foreman wait <request-id> --timeout 60
```

Both commands retain never-fail behavior. Jobs persist only the request ID. Git receives the boot credential through `GH_TOKEN` and the command-scoped `gh auth git-credential` helper. No credential is put in argv, jobs, audit, fixtures, or files. Hooks are disabled for the worker command so repository hooks cannot add local commands or side effects.

## Live and browser evidence

The harness uses `foreman_acceptance_fm-push`, port 4773, synthetic Postgres tickets, and `/tmp/fm-push-scratch`. It never invokes the beads reader. Live writes went only through the actual Oban push worker to `rpmessner/beads-board-scratch`.

Initial completed browser run:

| Check | Result |
| --- | --- |
| Named branch | `acceptance/fm-push-1792353529431` |
| Exact SHA observed on GitHub | `7a3061c6bdd5159978d7bc74039cfc0a4529df2f` |
| Named-branch request | `ed25f1c2-cbb1-4327-aac6-9e27ed7d961c`, done |
| One-off default request | `601f5674-c4c8-40d4-9c5c-6460db9f53e1`, done; already at SHA |
| Epic default request | refused at creation: `epic_default_branch` |
| Audit | each approved request has exactly ask, approve, start, succeeded |
| Browser | zero errors; no overflow at either width |

The earlier run also left `acceptance/fm-push-1792353043551` at the same SHA. No branch cleanup was performed. The authorized follow-up below advances scratch `main`.

[CLI responses](../acceptance/fm-push/transcript.json), [live result](../acceptance/fm-push/live-result.json), [audit](../acceptance/fm-push/audit.json), and [forge read](../acceptance/fm-push/forge-read.json) contain no credentials or headers. [Browser output](../acceptance/fm-push/browser.txt) records the final runner.

All four final screenshots were opened and inspected: [390 light](../acceptance/fm-push/push-390-light.png), [390 dark](../acceptance/fm-push/push-390-dark.png), [1440 light](../acceptance/fm-push/push-1440-light.png), [1440 dark](../acceptance/fm-push/push-1440-dark.png). Full SHA wraps without overflow, Note has a visible border, actions share a row, and the card aligns with the heading.

### Authorized default-branch advancement

The user explicitly approved one fixture-only commit in `/tmp/fm-push-scratch`. Created the empty fixture commit `797e13046f22f41dc6b471a2ea80b0a674a7a698`, whose direct parent is the previous remote `main`, `7a3061c6bdd5159978d7bc74039cfc0a4529df2f`. No product-worktree commit was made.

`tools/push-default-acceptance.cjs` posted the one-off `push-2` request through the real CLI and clicked Approve in Needs you. Request `e38a7944-41bb-45cf-8f95-6058868d625b` completed through the actual Oban worker. A subsequent GitHub read confirmed `refs/heads/main` at exactly `797e13046f22f41dc6b471a2ea80b0a674a7a698`, different from the old SHA. The same ask for epic ticket `push-e.1` was refused with `epic_default_branch`.

The [result](../acceptance/fm-push/default-advanced.json) records old SHA, direct parent, expected SHA, observed new SHA, and returned outcome. The [audit](../acceptance/fm-push/default-audit.json) contains exactly ask, approve, start, succeeded: one attempt. [CLI responses](../acceptance/fm-push/default-transcript.json) and [browser output](../acceptance/fm-push/default-browser.txt) are retained. The [outcome screenshot](../acceptance/fm-push/default-advanced.png) was opened and inspected; it shows the completed main push and full new SHA. No browser errors occurred. A credential scan confirmed the current GitHub token is absent from all acceptance artifacts.

The earlier default no-op is retained as historical evidence, not presented as advancement. This follow-up closes the live advancement gap.

## Review scope

Baseline `cfe3d15e54a1042b5e58e81ef9961877b2f7f97d` equals HEAD. The committed three-dot diff and commit list are empty. Review covers the explicitly requested working-tree diff and new deliverables, excluding the coordinator-owned brief. Axes run sequentially without subagents.

### Standards

Reviewed the root/app instructions, house baseline, request machine, CLI, request interpreter, push guards/worker, read-only Git file reader, LiveView/card, tests, and acceptance tools. The existing `Foreman.Request` machine owns every push transition. Start audit and approval enqueue use the existing transaction/lock; reconciliation submits observed events rather than assigning states. No new status machine, dependency, migration, atoms from input, or beads write was added. The low-level config/ref parsers are computations, not workflow lifecycles.

UI uses streams, `to_form`, shared human timestamps, and labels/status/controls only. Existing decision card DOM IDs remain stable. Declined to judge: unrelated workflows, installed deployment, and future request kinds. No Critical or Important Standards finding. Verdict: ready.

### Spec

Checked bb-zgd.3 and approved Decisions 2–6. The CLI names project/worktree/local branch/SHA/remote branch; creation checks committed stage, enabled GitHub forge, repository identity, local SHA, and default-branch eligibility. Approval enqueues an ID-only job. The job rereads the forge default, checks membership and local facts, then sends one explicit SHA-to-head refspec over HTTPS. Git's receive protocol enforces fast-forward atomically without a fetch or ancestry subprocess. Runtime observations and approval both supersede a moved pending SHA. Rescue ends failed with `outcome unknown`.

Important finding fixed: `Requests.transition/3` erased an approval Note during worker transitions. The new regression failed with `note: nil`; preserving an absent payload note fixes it. Existing decision/decline tests remain green.

The initial Important verification gap is closed: after explicit permission for the scratch-only fixture commit, the worker advanced live `main` to its exact direct-child SHA. The recorded GitHub read and single-attempt audit prove the update, not merely a no-op.

Declined to judge: open-PR/merge request handlers, browser notifications, dispatch close-out integration (later tickets). Verdict: ready; no open Critical or Important Spec finding.

### Risk

Safety fact: the serialized `approved → executing` transition and its start audit commit before any external write. A second claim is invalid. A rescued attempt records `outcome unknown`; a stale completion cannot overwrite that terminal state. The command carries one validated SHA-to-`refs/heads/` refspec, never a force flag. Git's receive protocol rejects a diverged remote without a separate local Git read command.

Proof level 4: independent committed database connections obtain exactly one start; the bare-remote suite checks exact SHA, real fast-forward, divergent refusal, replay, and a task killed after the remote accepted the write but before its result was recorded. Rescue produces failed/unknown and no second command. Proof level 5: browser approval invoked the actual Oban worker, published a scratch branch, and a GitHub read confirmed the exact SHA. The live audit has one start per request.

Important findings fixed:

- Local Git configuration can rewrite an explicit HTTPS URL or load credential helpers. `LocalRefs.safe_config/1` now rejects includes, URL rewrites, unknown sections, worktree config, and storage extensions. The worker suppresses hooks, tags, negotiation, redirects, global/system config and inherited Git overrides. A failing-first test proves an injected `insteadOf` cannot reach the command.
- Configuration removal during the forge read could still permit a push. The worker revalidates the configured repository after the network read, and reads ticket stage then. The network-boundary regression first completed a push after removal; it now refuses `forge_disabled` without invoking Git.
- Adapter read-only capability now explicitly refuses before transport. Credentials use worker-memory `GH_TOKEN`, not argv or files. Git output is classified into fixed outcomes, never persisted verbatim.

Cleared: duplicate claims, retries, terminal audit races, pruned jobs, moved local refs, foreign worktrees, packed refs, linked worktrees, default-branch membership changes, forced refspec injection, non-fast-forward updates, credential-bearing output, existing decision form IDs, and CLI refusal exit status. Removing the worker's SHA guard produced one failing regression; the mutation was restored.

Residual limits: local files/configuration and GitHub's default branch can change in the final check-to-push interval; the immutable SHA and receive-side fast-forward rule still constrain the write. Repository config outside the small supported allowlist fails closed. SHA-256/reftable/symbolic branch layouts are unsupported. An ambiguous failure needs observation and a new request, never retry-in-place. The 60-second job timeout and 90-second reconciliation lease bound orphan recovery while the worker is running.

Declined to judge: malicious concurrent filesystem replacement by the local operator, deployment, forge adapters beyond GitHub, and live worker-kill injection (the kill test uses a real bare remote). Cheapest safety check: `mix test test/foreman/push_test.exs test/foreman/request_commit_test.exs`. No open Critical or Important Risk finding. Follow-up Risk review checked the fixture's parent, exact new remote SHA, one start audit, credential-free records, and worker-only push. No production code changed in the follow-up.

## Test-first evidence and limits

Creation refusal, remote binding, foreign worktree, default-branch eligibility, moved SHA/refspecs, pre-approval superseding, worker execution, rescue, periodic reconciliation, CLI facts, push card, unsafe-config refusal, approval-note retention and config-removal race had failing-first runs. The initial test run was blocked by missing dependencies; after `mix deps.get`, the stub failed on the intended `:todo` assertion. The card initially crashed because decisions were assumed; a minimal push-card stub then produced the intended missing-facts assertion before implementation.

Forge-none, job guard rechecks, real default fast-forward, linked/packed refs, post-write kill, independent start races, and credential-output tests were added after the relevant implementation. They are regression evidence, not claimed failing-first evidence. The interrupted-request rescue test itself failed before the rescue implementation.

[SHA mutation](../acceptance/fm-push/mutation-sha.txt): removing the job's moved-SHA guard caused one failure. Restored before all final gates. Review regressions: [note red](../acceptance/fm-push/red-note.txt), [configuration race red](../acceptance/fm-push/red-config-race.txt).

## Final gates

[Precommit](../acceptance/fm-push/precommit.txt), rerun after the advancing live push, seed 959235, exit 0:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
5 properties, 379 tests, 0 failures
```

[Focused suite](../acceptance/fm-push/focused-tests.txt), exit 0:

```text
mix test test/foreman/push_test.exs test/foreman/request_commit_test.exs \
  test/foreman_web/live/needs_you_live_test.exs
31 tests, 0 failures
```

`MIX_ENV=acceptance mix assets.build`, syntax checks for both push acceptance runners, browser acceptance, and `git diff --check` passed. The final application gates emitted no warnings. Initial dependency compilation emitted the existing Oban unused-clause warning. The first full suite failed the old expectation that push was an unsupported kind; the refusal test now expects `not_committed` while retaining its exit-zero assertion.

Tests use `foreman_test_fm-push`; browser/live acceptance uses `foreman_acceptance_fm-push`. Neither is the installed database. The last acceptance server was stopped and port 4773 no longer responds.

## Completion

Follow-up review ran Standards, then Spec, then Risk. The acceptance-only runner uses existing CLI/browser interfaces, the live advancing push closes the remaining Spec gap, and the audit/remote checks confirm one worker attempt. All axes are ready; no Critical or Important finding remains.

Changed: guarded, audited push requests, CLI and card.
Verified: exact live named-branch SHA, advancing one-off default push, epic refusal, four inspected responsive/theme captures plus the advancement outcome, temp-bare guards/rescue, and final gates.
Not verified: installed deployment, which is out of scope. No bb-zgd.3 acceptance item remains open.
