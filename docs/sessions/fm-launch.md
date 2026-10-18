# fm-launch: fm-3c3.1

Implemented and verified in the `fm-launch` worktree. No commits, pushes, ticket edits, subagents, or installation. The coordinator-owned brief is untouched.

## Changes

- `Foreman.Sessions` resolves launchable tickets, selects the main checkout using `git worktree list`, reserves a Claude UUID, and serializes launch attempts with a Postgres row lock.
- `Foreman.PlanningSession` stores project, ticket, UUID, window ID, main checkout, launch time, observed state, and a retry error. Its `planning_sessions` table is separate from dispatched build sessions.
- `Foreman.SessionTmux` creates the project session and ticket window, focuses an existing window, quotes every argument, and leaves a shell after Claude exits. It uses only the dedicated socket and exposes no kill operation.
- `Foreman.SessionMonitor` polls liveness every three seconds in the worker role. Web and worker restarts do not own or stop tmux.
- Launch appears on eligible sheets, epic details, draft list rows, and idea-stage epic rows. The shared sheet also works on Pull requests. Session state and the copyable attach command remain visible after launch.
- The independent unit and installation instructions are in `deploy/systemd/`. The main README links them and keeps ordinary web/worker install commands separate.

## Machine and extension contract

`Foreman.SessionMachine` declares `new -> starting` on launch, `starting -> running` on observed start, `running -> ended` on observed exit, and `starting/running/ended -> parked` on window loss. Other launch claims are invalid; stale observations are ignored. Generated diagram and matrix: [session_machine.md](../machines/session_machine.md).

The launch effect opens a window. No effect closes one. A reserved starting record survives an external failure and retains its UUID for retry. If tmux created the window before the DB update, retry recovers that window. A closed window parks the existing conversation instead of silently starting a new one. Hooks, waiting, parking timers, and Relaunch belong to later tickets.

`Sessions.launch({project, ticket})` returns `{:ok, PlanningSession}` or `{:error, reason}`. `Sessions.get/1` reads the record; `Sessions.reconcile/1` observes tmux. UUID is the primary key; project/ticket is unique. The window field stores tmux's stable `@id`; the visible window name is the ticket ID.

## Review scope

Fixed point `759d0f45a1bfc095bb5923e7a62166b0ef826881` is HEAD: committed three-dot diff and commit list are empty. The explicitly requested self-review covers the working-tree diff and new deliverables, excluding the coordinator brief. Axes run sequentially, without subagents.

## Standards

Reviewed root/local AGENTS, the house baseline, application changes, tests, and acceptance tools. Session states are declared by `Foreman.SessionMachine`; all persisted state changes run through `step/3`. The monitor owns scheduling only. Copy controls add no application lifecycle. UI text is labels, states, or instructions on failed launch; times use the shared formatter. Collections remain streamed. Existing dispatched build sessions are unchanged.

Minor findings fixed: removed a misleading test comment about a wait-for barrier and added the machine to generated-doc golden checks.

Declined to judge: future waiting/hooks/parking/relaunch (later tickets), existing epic/history presentation. Verdict: Ready. No open Standards findings.

## Spec

Reviewed fm-3c3.1 including its list-row note and Decisions 1–5, 8, launch/liveness rows of 9, and 11. The sheet, epic detail, and draft rows have working Launch controls. The scratch run starts real Claude with the task, bug, and epic prompts; a repeated Launch retains the same window. The board displays state and a copied attach command. Temporary-server integration tests cover exit-to-shell, window disappearance, failure retry, and preview refusal. Restart acceptance preserves panes and an attached client. Global Claude settings hashes match.

Important finding fixed: launchability originally excluded decision tickets and legacy chores. It now accepts other unplanned non-epic ticket types and routes them through the task/flow template. Failing regressions preceded the fix.

Visual findings fixed before review: mobile draft Launch was clipped by the legacy fixed-width row; the draft row is now responsive. The shared input wrapper initially kept the attach command unnecessarily narrow; it now flexes to fill the card.

Declined to judge: installation (reserved for user approval), waiting notifications, parking and Relaunch (later tickets). A final scope check also caught fallback templates being enabled in normal environments. A failing regression now proves missing skill templates refuse launch when test fallback is disabled. `config/test.exs` enables the fallback for unit and acceptance checks only. Verdict: Ready. No open Spec findings in this ticket's scope.

## Risk

The safety fact is that the launcher addresses only its named server, reuses windows by exact project/ticket identity under a database row lock, and has no window-kill operation. `tmux -N` prevents accidental creation inside a board service cgroup. The separate unit has no lifecycle dependency on web/worker. Proof level 5: the scratch app and its monitor were restarted while a control client remained attached; pane IDs/PIDs and client PID stayed identical (`restart.json`). Level 4: 12 focused tmux/session/UI tests passed during this review, including shell metacharacters/newlines/apostrophes in argv, duplicate launch, failed-launch retry, no child-ticket launch, and preview refusal. `systemd-analyze --user verify` passed.

Cleared: a half-failed launch keeps its reserved UUID; retry finds a created window instead of launching another. A manually closed window parks the record instead of silently creating another conversation. Claude is resolved to an absolute executable from the launching web process so the service's tmux PATH need not find it. Existing build-session rows and overlay transitions are unchanged. Global Claude settings hashes match before/after the live launches.

Follow-up findings: the suspected tab/newline parsing risk did not reproduce. A tmux 3.4 probe showed that window names escape control characters, and the real-server regression passed without a parser change. A missing Claude executable now has its own refusal instruction. The browser also caught a four-pixel input/Copy misalignment caused by the shared input's bottom margin; a targeted wrapper rule and browser assertion fix it.

Declined to judge: actual service installation/reboot persistence, hostile same-user database/tmux edits, later hooks and parking. Cheapest pre-merge check: the focused test command followed by `mix precommit`; repeat `tools/launch-restart-check.py` for deployment-process changes. Verdict: Ready. No open Risk findings.

## Prompt templates for the coordinator

The app reads `~/.agents/skills/foreman/templates/session-launch/`. That globally linked directory is owned by the foreman skill. The coordinator should add these files in the skills repo. This build does not edit that repo. Tests prove file override, test-only fallback, and refusal when templates are missing in normal environments. Unknown non-epic types use `task.md`.

`epic.md`:

```text
You are the coordinator for {{ticket}} in project {{project}}.
Read AGENTS.md and {{source}}. Start /tight-spec for this ticket.
Keep planning scoped to this ticket. Follow the foreman skill for board updates and the house workflow for specs, build dispatch, and review. Ask the user when a decision is theirs.
```

`bug.md`:

```text
You are the coordinator for {{ticket}} in project {{project}}.
Read AGENTS.md and {{source}}. Start diagnosing-bugs for this ticket.
Keep planning scoped to this ticket. Follow the foreman skill for board updates and the house workflow for specs, build dispatch, and review. Ask the user when a decision is theirs.
```

`feature.md` and `task.md`, identical content:

```text
You are the coordinator for {{ticket}} in project {{project}}.
Read AGENTS.md and {{source}}. Start flow for this ticket.
Keep planning scoped to this ticket. Follow the foreman skill for board updates and the house workflow for specs, build dispatch, and review. Ask the user when a decision is theirs.
```

For tracker tickets, source is `tickets/<id>.md`. A board-only draft has no ticket file; source names the draft and its spec path when present. The acceptance-environment live run used the test-only built-in versions above. The templates establish the ticket and workflow, not a new policy. No multi-run prompt-behavior experiment is claimed.

## Live scratch run

The acceptance app used port 4784 and `foreman_acceptance_fm-launch`. Unit tests used `foreman_test_fm-launch`. The installed port 4747, its configuration, and its database were untouched.

The live test launched Claude Code 2.1.302 only in `/tmp/fm-launch-scratch`, on temporary socket `fm-launch-live`. Three windows covered an unplanned task, an unplanned bug, and a draft epic. Each reached a planning question on its paired prompt. I accepted the trust dialog only for this scratch repo. Claude used the existing defaults, which displayed auto permission mode on this host. The launcher passed neither a model nor a permission-mode flag and did not change those defaults.

Evidence:

- [live-result.json](../acceptance/fm-launch/live-result.json) compares real `/proc` argv and cwd with the three persisted UUIDs. It also records an unchanged global Claude settings hash.
- [Claude task](../acceptance/fm-launch/claude-task.txt), [epic](../acceptance/fm-launch/claude-epic.txt), and [bug](../acceptance/fm-launch/claude-bug.txt) captures show the paired prompts and questions.
- [restart.json](../acceptance/fm-launch/restart.json) records unchanged pane identities/PIDs and an attached client across a restart of the acceptance web process and liveness monitor. No real installed service was restarted.
- [browser.json](../acceptance/fm-launch/browser.json) records the windows and zero browser errors. The runner clicks Launch from the sheet and list, focuses the same epic window from detail, and tests the clipboard value.

`tools/launch-acceptance.exs`, `tools/launch-acceptance.cjs`, and `tools/launch-restart-check.py` reproduce these checks against the guarded scratch environment. The server requires `MIX_ENV=acceptance`, port 4784, and scratch socket/repo environment variables. No production config is loaded by the runtime worker.

## Browser inspection

Inspected list, epic detail, and sheet captures in light and dark at 390 and 1440 pixels. Launch is reachable; the draft row no longer clips it on mobile. The status card fills the available width, and the attach field aligns with Copy. The full command remains selectable and copyable on narrow screens. Existing epic tables scroll horizontally.

All captures are in [fm-launch acceptance](../acceptance/fm-launch/), named `{list,epic,sheet}-{390,1440}-{light,dark}.png`. The browser runner asserts button bounds, no document overflow, attach/Copy alignment, and no page errors. The shared-sheet desktop and mobile captures were inspected again after the alignment fix.

## Failing-first checks

- Eligibility stub returned false for an unplanned task. Later regressions caught unresolved parents and excluded decision/chore tickets.
- Machine stub stayed in `new` instead of returning `starting` and the open effect. Every requested row and invalid/ignored remainder now has coverage.
- Prompt stub returned empty text. Tests cover each workflow and skill-owned overrides.
- Tmux stub refused launch. Real-server tests then established session/window creation, argv preservation, focus, exit-to-shell, and no automatic server startup. A missing executable regression failed before its guard.
- Session stub failed both persistence and PREVIEW refusal assertions. Subsequent tests caught reopening a manually closed window and tmux's zero-exit socket error. Tests also cover reserved-record recovery after a half-completed launch.
- LiveView tests failed on absent Launch/status controls. Browser checks failed on clipped mobile Launch and input/Copy misalignment before their fixes.

Some added recovery, remainder-matrix, and renamed-window tests passed on first execution. They are additional regression coverage, not claimed red-first evidence. Initial dependency compilation emitted the existing Oban unused-clause warning; the final application gates emitted no warnings.

## Install steps, user approval required

Apply the new migration through the normal approved app deployment. Install the skill templates above through the coordinator's skills change. Then follow [deploy/systemd/README.md](../../deploy/systemd/README.md):

```sh
install -d "$HOME/.config/systemd/user"
install -m 644 deploy/systemd/foreman-tmux.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now foreman-tmux.service
systemctl --user status foreman-tmux.service
tmux -L foreman list-sessions
```

The service runs `tmux -D -L foreman -f /dev/null`. An empty server remains available. If another server already owns that socket, preserve it and schedule a manual migration. Do not restart this service with web or worker deployments. Stopping the tmux unit or rebooting terminates its sessions; logout persistence requires separately approved lingering. The app refuses to auto-start tmux inside its own service cgroup.

## Final gate

Fresh `mix precommit` passed with **5 properties, 490 tests, 0 failures**, seed 87211. [Full output](../acceptance/fm-launch/precommit.txt). Repository hygiene, formatter, compile-with-warnings-as-errors, and the test suite passed. `git diff --check` and `systemd-analyze --user verify deploy/systemd/foreman-tmux.service` also passed.

The final browser runner and restart check both passed after the last UI fix. No open Critical or Important review finding remains. The only external handoff steps are the approved unit installation and coordinator-owned skill-template change. Hooks, waiting notifications, parking, and Relaunch remain deliberately outside this ticket.

Changed: board planning launch, persistence, liveness, UI controls, prompt loading, and the independent unit template.
Verified: real tmux tests, real Claude scratch processes, clipboard and responsive browser checks, restart survival, global-settings hash, and full precommit.
Not installed: the production service or skill templates. No deployment or reboot-persistence claim is made.

Cleanup is verified in [cleanup.json](../acceptance/fm-launch/cleanup.json). The scratch tmux server, its three Claude processes, and the acceptance app are stopped. Port 4784 has no listener. Only this checkout's scratch database and files remain for reproduction.

## Coordinator corrections: Focus and tracker status

Both review findings are fixed.

- The shared control says **Focus** when the latest observed session record has a window in starting, running, or ended state. Ended retains a live shell, so focusing is still correct. With no window or a parked record it says **Launch**. The pending label also changes to Focusing. Relaunch remains outside this ticket.
- Sheet, epic detail, draft rows, and idea-stage epic rows use that same component. Initiative snapshots load planning sessions once and carry them through streamed rows, so reconciliation updates the labels without per-row database queries.
- The sheet's status badge uses the configured repository tracker, not the presence of acceptance checkboxes. Files repos show `open`; beads repos retain `bd: open`. The regression specifically uses a file ticket without acceptance metadata and then switches the configured tracker to verify beads compatibility.

I had treated the launch endpoint's name as the button label even when its action was focus, and had accepted acceptance metadata as a proxy for tracker identity. Prevention is in the shared component and tracker-based rendering, backed by failing-first LiveView tests. No lesson ticket was created because this build session cannot edit tickets or use bd; the coordinator can record this lesson.

The focused suite passed with 5 tests after reproducing both failures. It covers all four control locations, running and ended windows, parked fallback, and tracker-specific status text. The browser runner also asserts Focus and plain `open`.

Refreshed and inspected all 12 sheet/detail/list screenshots at 390 and 1440 pixels in light and dark. Focus fits the controls and the sheet shows plain status without clipping. This correction run used live scratch shell windows in ended state on temporary socket `fm-launch-review`, with the same isolated acceptance database and port 4784. No additional Claude process was needed; the earlier real-Claude evidence remains unchanged. Focus clicks preserved the existing windows, and clipboard, alignment, overflow, and browser-error checks passed. [Browser output](../acceptance/fm-launch/review-browser.txt).

Fresh final `mix precommit`: **5 properties, 492 tests, 0 failures**, seed 303250. [Gate output](../acceptance/fm-launch/review-precommit.txt). No application warnings. Standards review confirms these labels are derived display data, not a new lifecycle; Spec review covers both requested corrections; Risk review found no changes to launch, focus, or tmux ownership behavior. No open finding remains for these corrections. The correction-run acceptance process and scratch tmux server are stopped, and port 4784 has no listener. Installed services and databases were untouched.
