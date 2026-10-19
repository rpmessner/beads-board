# fm-park: fm-3c3.4

Implemented in the `fm-park` worktree. Fresh-database `mix precommit`: **5 properties, 555 tests, zero failures**. No commits, pushes, ticket edits, subagents, or installed-service changes.

## Changes

- `Sessions.reconcile/1` parks inactive running, waiting and ended sessions. `planning_idle_timeout` is an application setting in **seconds**, default **86,400**; `idle_timeout:` overrides it for a reconciliation run.
- `last_activity_at` persists hook activity and observed attachment. Repeated waiting hooks refresh activity even when the pending request is unchanged. Non-limit StopFailure hooks report activity without clearing an unrelated wait.
- `SessionMachine` declares `idle_timeout`, `relaunch`, and activity observations. The generated diagram/matrix is updated.
- `SessionTmux.park/2` checks the UUID and `window_active_clients` inside a tmux `if-shell -F` command before closing exactly the stored window ID. Errors, unknown identities and attached clients refuse parking.
- Relaunch creates a new window with `claude --resume <stored UUID>` and fresh per-launch hooks, without replaying the opening prompt. Record identity and working directory remain unchanged.
- The shared control offers Relaunch for parked/ended sessions on sheets, epic details, draft rows and idea-epic rows. Existing running sessions retain Focus.
- Observation and attach commands use the stored window ID, not an ambiguous repeated ticket name. Unmarked or foreign-UUID windows are not adopted.
- Relaunch from ended preserves the readable shell. Its ID and activity timestamp remain in `previous_windows`, so it still gets parked later rather than becoming an untracked orphan. Attachment protects these older shells too.

Two migrations add activity and retained-window metadata. Existing records receive a fresh activity timestamp during migration: pre-upgrade activity was not recorded, so immediately treating old launch times as inactivity would be unsafe. Apply both migrations before starting the updated worker. Deploy the updated CLI with the app for the new activity-only hook envelope.

## Verification

Failing-first checks cover machine rows, timeout parking, stored-UUID resume, UI labels, repeated waiting activity, exact attach targeting, old-shell cleanup, non-limit error activity, and refusal to adopt an unmarked window. Logs are under [acceptance/fm-park](../acceptance/fm-park/). Additional passing regressions cover the default day-long limit, hook timestamp refresh, attached-client protection and attachment refresh; these are not claimed as red-first tests.

The tmux tests use fresh temporary sockets and delete their scratch servers. They prove only the target window closes, a real control client prevents closure, foreign UUIDs refuse closure, an ended shell survives Relaunch until its idle limit, and the same conversation UUID reaches `--resume`.

The final gate ran after dropping **only `foreman_test_fm-park`**, exercising both migrations from an empty database:

```text
mix precommit
5 properties, 555 tests, 0 failures; seed 748015

git diff --check
clean
```

[Fresh-database gate output](../acceptance/fm-park/precommit.txt). A final repeat after the handoff was written also passed: 5 properties, 555 tests, zero failures, seed 152856 ([output](../acceptance/fm-park/final-precommit.txt)). No application warnings in either final gate. Initial dependency compilation emitted an existing Oban warning. An early acceptance-browser attempt failed because this fresh checkout had no built assets; building the acceptance assets resolved it. A hygiene check caught local build paths in a copied red-test compilation log; the retained log now contains only the test result.

## Live scratch run

The isolated app used **4788**, database **`foreman_acceptance_fm-park`**, socket **`fm-park-live`**, and repo **`/tmp/fm-park-live`**. No request targeted the installed app on 4747. The installed database and tmux service were not changed.

A real Claude Code 2.1.303 conversation remembered `amber otter 7391`. With a **120-second limit**, the monitor parked it and retained UUID `db1713eb-cda6-4646-a70a-b6b037bec87b`. The browser saw parked/Relaunch, clicked Relaunch, and reopened a new window. `/proc` showed `--resume` with that UUID. Asked for the earlier phrase, Claude answered `amber otter 7391` again.

Evidence:

- [Before parking](../acceptance/fm-park/before-parking.txt)
- [Resumed conversation](../acceptance/fm-park/resumed-conversation.txt)
- [Resume argv](../acceptance/fm-park/resume-argv.json), with runtime settings omitted
- [Persisted records](../acceptance/fm-park/live-records.txt)
- [Browser result](../acceptance/fm-park/browser.json) and [runner output](../acceptance/fm-park/browser.txt)

A scratch epic window was closed by hand; reconciliation parked it and both its list row and detail page offered Relaunch. The browser runner covers all three surfaces. LiveView tests also cover published idea-epic rows. The live initial prompt uses a deliberately small recall task rather than a planning workflow; workflow prompting was verified by fm-launch. Initial live hooks were silent no-ops so the shortened timer could be observed independently; hook activity is covered by the integration tests.

`tools/park-acceptance.exs` guards the environment, database and port; `tools/park-acceptance.cjs` reproduces browser checks once the scratch records are parked. The server seeds only when the conversation record is absent.

Inspected all 12 sheet/detail/list screenshots in light and dark at 390 and 1440 px. Relaunch is reachable and unclipped, with no document overflow or browser errors. The command field remains selectable on narrow screens. After switching attach commands to stable IDs, refreshed all captures and re-inspected the four sheet captures. Existing epic columns scroll horizontally on mobile.

## Standards review

Fixed point `b5ebeabe0d6c87e9cd3baeb8a54ea9b19927f8c4` resolves to HEAD. The committed three-dot diff and commit list are empty because commits were prohibited. Review therefore covers this build's working-tree diff and new deliverables, excluding the coordinator-owned brief. Axes ran sequentially, without subagents.

The state machine owns lifecycle transitions and effects. Activity timestamps and retained window IDs are persisted data, not another status machine. Older shells reuse the ended-state idle transition and guarded close effect. Templates use the shared control and existing human timestamps. No dependencies were added.

Declined to judge unrelated UI structure and existing application machines. **Ready**: no open Standards finding.

## Spec review

The acceptance behaviors have automated coverage and the live same-conversation check above. Review found that ended-session Relaunch initially abandoned the old shell's cleanup; a failing regression preceded retaining its window metadata. Repeated waiting requests also initially bypassed the activity update; a failing regression preceded that fix.

Rulings: ended-session Relaunch preserves the old shell until its own parking deadline, because only parking may close it. Existing sessions get a full grace period at upgrade because historical hook activity cannot be reconstructed. Relaunch remains available even if the ticket's stage later stops qualifying for a fresh Launch.

Declined to judge installed deployment, real 24-hour wall-clock waiting, and upstream conversation-file deletion. **Ready** for the tested acceptance paths.

## Risk review

The safety fact is that closing a window requires both the exact stored UUID and zero clients viewing that window, checked in tmux rather than a separate shell check followed by kill. The adapter test reaches proof level 4 with a real attached control client. The conversation identity reaches level 5: the running app resumed the recorded UUID and recalled earlier content.

Resolved findings:

- `session_tmux.ex` previously allowed a blank identity and attached by ticket name. Regressions now require an exact UUID and stable window target; creation tags the window before returning it.
- `session_waiting.ex` now refreshes activity on deduplicated waits.
- `Sessions.reconcile_previous/2` keeps ended shells within the parking lifecycle without clearing the current conversation's waiting request.

Residual limits: attachment is sampled by the existing three-second monitor, so an attach-and-detach entirely between polls is not recorded as activity. The atomic close guard still protects anyone attached at closure. External tmux creation and the database transaction are not a distributed transaction: a process crash after opening a resume window but before saving it can leave an untracked window, though the stored conversation UUID is retained. No crash-injection recovery guarantee is claimed. Hooks remain best-effort during app outages, as in fm-waiting.

Declined to judge hostile same-user tmux/database changes and upstream Claude transcript retention. Cheapest repeat check: the session machine, sessions, session tmux, session hooks, session waiting and session-launch LiveView test files, followed by `mix precommit`. No confirmed wrong-conversation or attached-window-close defect remains in the tested paths; the sampling/crash limits above should remain visible to the coordinator.

## Cleanup and handoff

[Cleanup evidence](../acceptance/fm-park/cleanup.json) confirms the scratch tmux server is gone, port 4788 is closed, and no scratch Claude process remains. Scratch files and isolated databases remain for reproduction. No production deployment was performed.

**Changed:** parking, activity persistence, same-conversation Relaunch, retained-shell cleanup, and shared UI controls.
**Verified:** fresh-database precommit, real tmux safety tests, real Claude recall after parking, browser checks and inspected screenshots.
**Not verified:** installed deployment, crash-between-tmux-and-DB recovery, and sub-poll transient attachment capture.
