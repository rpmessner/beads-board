# fm-previewbtn: fm-c2w.14

Implemented and verified after rebasing onto `main` at `2001a29`. WIP commit `1d88685` contains the implementation. The log-disclosure fix and refreshed acceptance evidence remain uncommitted for coordinator review. No pushes, ticket edits, or subagents. The coordinator-owned brief is unchanged.

## Changes

- `Foreman.Previews` persists worktree-scoped requests and devserve observations in the new `previews` table.
- `Foreman.Previews.Machine` declares none, starting, running, failed, stopping, and stopped. Its reconcile event returns start, stop, or observe effects. An explicit start sets a durable `launch_requested` receipt. Registry observations cannot authorize a launch. See the [generated machine](../machines/preview.md).
- `Previews.Job` uses the worker-only `previews` Oban queue. A worker poller recovers pending work and refreshes the registry and log tail every three seconds. Preview copies refuse commands and jobs under `PREVIEW=1`.
- `Previews.Devserve` invokes `up`, `ls --json`, `logs`, and `down --drop-db` through executable argv. It excludes main units, validates unit names and localhost URLs, bounds subprocess duration, and retains a 16 KiB log tail. It never calls systemd or PostgreSQL directly.
- Overlay transitions to merged, done, or abandoned request cleanup in the same transaction. Failed cleanup remains visible and retryable. A late start cannot overwrite a pending Stop.
- Shared ticket-sheet controls provide Start, Open preview, Follow logs, and Stop on Initiatives, Epic, and Pull requests. `/previews` lists previews whose ticket or worktree is missing and offers Stop.
- The native log disclosure retains its `open` attribute across LiveView patches while its contents continue updating.

## Test evidence

The following assertions failed before their fixes:

- JSON decoding returned nil instead of running.
- Explicit Start returned `{:error, :todo}`.
- A terminal-stage event during start left the preview starting instead of stopping.
- The sheet lacked `#preview-start`.
- A removed ticket's preview was absent from the orphan list.
- An externally starting orphan that vanished was restarted automatically.
- A stopped worktree could not be reused by a later ticket.
- The browser's log disclosure closed during tail updates.

The fake exists only at the devserve boundary. Supplementary tests cover argv metacharacters, main-unit rejection, bounded logs, failed database ownership cleanup and retry, orphan-page Stop, and preview-mode command refusal. These supplementary tests are not claimed as failing-first evidence.

## Live acceptance

`tools/previewbtn-acceptance.exs` served committed fixtures in this checkout's separate acceptance database on port 4879. Only the preview queue ran; normal runtime workers were disabled. The browser runner used the user's devserve configuration to start this worktree's real app from the sheet. Devserve copied the registered source database into its owned preview database and served the preview on port 4880.

The final [browser run](../acceptance/fm-previewbtn/browser.txt) verified:

1. Start from the ticket sheet, without automatic startup.
2. Open preview in a new tab and connect its LiveView.
3. Open Follow logs, observe changing tail content, and keep the disclosure visible across refreshes.
4. Stop from the sheet and observe the preview disappear from devserve.
5. Start again, move the scratch ticket to Done, and observe automatic cleanup. Done no longer offers Start.
6. Confirm that no preview for this worktree and no matching preview database remain.

The browser reported no page errors. The [result file](../acceptance/fm-previewbtn/live-result.json) records the completed steps. The acceptance server was stopped after verification.

All four screenshots were opened and inspected after the disclosure fix. The controls fit, the logs remain visible within their scroll region, the sheet has no horizontal overflow, and Launch remains present. The desktop captures retain the centred Needs you badge.

| Width | Light | Dark |
| --- | --- | --- |
| 1440 | [Screenshot](../acceptance/fm-previewbtn/preview-1440-light.png) | [Screenshot](../acceptance/fm-previewbtn/preview-1440-dark.png) |
| 390 | [Screenshot](../acceptance/fm-previewbtn/preview-390-light.png) | [Screenshot](../acceptance/fm-previewbtn/preview-390-dark.png) |

## Environment and rebase

The initial live attempt failed because the registered absolute Mix executable lacked asdf's `MIX_HOME`. An A/B migration probe against the scratch test database reproduced the failure without that variable and succeeded with it. The coordinator added `MIX_HOME` and `LANG=C.UTF-8` to the user configuration. This build did not modify user configuration.

Two browser assertions needed correction before the successful run. The product title is lowercase `foreman`; the initial assertion expected `Foreman`. The bounded rolling log tail can discard startup lines, so the runner now checks actual log output and its subsequent change rather than requiring the startup banner. Screenshot inspection then exposed the real disclosure bug. The added visibility assertion failed before `JS.ignore_attributes("open")` fixed it.

The coordinator authorized a WIP commit and rebase. Rebase conflicts in `role.ex` and three LiveViews were resolved by preserving both the launcher and preview additions. `ticket_detail.ex` retains Launch/Focus and its planning-session data. `layouts.ex` retains the centred badge. The launcher LiveView tests, including Focus on sheets and list rows, pass in the final suite.

## Review scope

Standards, Spec, and Risk ran sequentially without subagents. The initial review used `2ffd2a03ea4d6c78b654bcc4e092a070d1c9dc1b` and the requested uncommitted changes. Follow-up review checked the rebased feature diff against `2001a29`, the conflict resolutions, and the log-disclosure fix. Unrelated upstream implementation and the coordinator-owned brief were excluded.

## Standards

The lifecycle uses `Foreman.Fsm`; reconciliation effects come from its table. UI collections use streams. Copy is limited to labels, status, and controls. The adapter uses argv rather than shell interpolation.

An Important finding was fixed: `starting` originally conflated observed state with launch authorization. The explicit launch receipt and its failing-first orphan-disappearance test separate those facts. The disclosure fix uses LiveView's documented attribute-preservation command, not an application-side visibility flag.

Declined to judge unrelated existing workflows and sheet content. No open findings. Verdict: Ready.

## Spec

All five fm-c2w.14 acceptance items have implementation and test evidence. The live run additionally proves sheet startup, connected preview navigation, visible changing logs, manual Stop, and Done cleanup through real devserve.

Important findings fixed: stopped worktrees could not be rebound to a later ticket, removed-ticket overlays were not listed as orphans, and live refresh closed the log disclosure. Each has a failing-first regression and a passing rerun.

Declined to judge pre-reboot database discovery, which devserve explicitly does not support, and external CLI users intentionally starting services after cleanup. No open findings. Verdict: Ready.

## Risk

Foreman sends a validated preview unit to `devserve down --drop-db`; devserve chooses the database and checks its ownership comment. A refused drop remains stopping and can be retried. Stage changes and Start share the overlay lock. User commands use row locks, workers serialize IO with a PostgreSQL session advisory lock, and observations use compare-and-swap. A late successful Start re-reads a concurrent Stop before publishing running state.

Proof level 4 comes from the tests for all terminal stages interleaved inside start, failed ownership cleanup, retry, argv safety, and main-unit rejection. Proof level 5 comes from the actual browser's manual Stop and Done cleanup, followed by registry and database checks. The pinned DBConnection code disconnects a connection when its checkout owner exits, releasing the worker's session lock.

An early suite run exposed unnecessary cleanup-job insertion when no previews existed. Cleanup now enqueues only when matching rows exist. The final suite's committed-data guard passes.

Declined to judge hostile local registry/configuration changes, devserve's documented pre-reboot recovery limitation, and arbitrary apps logging secrets. Devserve assigns log safety to the app. No open findings. Verdict: Ready.

## Final gate and cleanup

- `mix precommit`: 5 properties, 529 tests, 0 failures, seed 474984. No final application warnings. [Output](../acceptance/fm-previewbtn/precommit.txt).
- `mix assets.build` and the complete browser runner exited 0.
- `git diff --check` passed after the rebase and disclosure fix.
- [Final registry](../acceptance/fm-previewbtn/registry-final.json): no previews. Main units remain active.
- A catalog-only PostgreSQL query returned zero databases matching this worktree's preview identity.
- No listeners remained on acceptance port 4879 or preview port 4880.

No requested acceptance item remains unverified. Cross-browser and endurance testing were not run. The coordinator owns ticket closure and integration.
