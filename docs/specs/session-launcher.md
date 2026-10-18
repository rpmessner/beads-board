# Session launcher

Status: approved 2026-10-18. Foreman draft epic `draft:session-launcher`. Builds after the rename (bb-c2w.17) and the approvals inbox backbone (bb-zgd.1); names below use foreman.

## Goal

From an unplanned ticket or an idea-stage epic, the user launches a Claude Code coordinator for it in a board-owned tmux server with one click; the board tracks the session, calls the user when it waits, parks it after a day of inaction, and relaunches the same conversation on demand.

## Why

Loose tickets and unspecced epics have no home today: starting work on one means opening a terminal, a tmux window and a Claude session by hand, and a session that stops for input sits unseen (sk-board waited four hours at a prompt). The user wants to start that work from the board, keep projects apart, attach whenever they like, and never lose a session to the app restarting.

## Non-goals

- Launching sessions for tickets inside a ticketed epic: they keep going through the coordinator's `dispatch` to pi (user).
- Launching pi build sessions from the board, or steering a session's conversation from the UI.
- A terminal in the browser. The user attaches with tmux.
- Changing Claude Code's global settings, hooks or permission allowlist; per-launch settings only.
- Worktrees for coordinators (they run in the main checkout).

## Decisions

1. **A board-owned tmux server** (user). One tmux server on its own socket (`tmux -L foreman`), run by its own systemd user service (`foreman-tmux`), outside the web and worker services, started at login like them. Restarting, redeploying or crashing the board never touches it.
2. **Layout** (user). One tmux session per project, named by the config repo key, created on first launch; one window per launched ticket, named by the ticket id. Launching a ticket that already has a live window focuses that window instead.
3. **What can be launched** (user). Unplanned tickets (no parent epic) and epics at idea or draft stage. The Launch control appears on those tickets' sheets and on draft epics, nowhere else.
4. **What is launched** (user). A Claude Code coordinator for that one ticket, in the project's **main checkout**, on the default model (no `--model` flag) and the default permission mode (no `--permission-mode` flag): it asks before edits and before shell commands outside the user's allowlist, like the user's own sessions. It plans, specs, dispatches builds to pi, reviews, and posts inbox requests.
5. **Prompt paired with workflow** (user). The opening prompt names the ticket file and starts the matching house skill: an idea or draft epic starts `/tight-spec` on it; an unplanned feature or task starts with `flow` to pick its route; an unplanned bug starts `diagnosing-bugs`. The prompt templates live in the `foreman` skill, not in the app, so they are maintained with the other skills.
6. **Session waiting reaches the user** (user). Each launch passes per-launch Claude Code settings (`--settings`) with two hooks: one that fires when the session needs permission or input, one when it finishes a turn and waits. Both run `foreman ask session_waiting <ticket> --session <id>` (a new request kind on the approvals inbox: no action, cleared automatically). The request links to the window's attach command and clears when the session works again. It shows on Needs you, in the badge and as a browser notification like any request.
6a. **Usage limits** (user, 2026-10-18). Session waiting carries a reason: input, permission or usage_limit. A provider limit (Codex usage limit, Anthropic extra-usage refusal, HTTP 429) on a launched session is reported through a per-launch API-error hook if Claude Code offers one, else by reading the pane; on a pi build session the coordinator reports it when `pi-wait` exits LIMITED. The request names the provider and the reset time when the message gives one, and clears when the session produces output again. Its **Continue** button sends exactly `continue` and Enter to that window, only on the user's click; it is the only text the board ever types into a session, and only on usage_limit requests.
7. **Notification drawer** (user). A drawer opened from the Needs you badge on any page lists pending requests, session waiting included, so the user can act without leaving the page; Needs you stays the full page.
8. **Tracking** (user). Each launch gets a fixed Claude session id (`--session-id <uuid>`) stored on the board's session record with project, ticket, window and launch time. The ticket shows the session's state and a copyable attach command (`tmux -L foreman attach -t <project>` plus the window). The board reads liveness from tmux (window present, pane process alive) and activity from the hooks.
9. **Session machine** (agent call), on `Foreman.Fsm`:

   | From | Event | To | Effects |
   |---|---|---|---|
   | — | launch | starting | create tmux session if missing, open window, record session id |
   | starting | started (observed: pane alive) | running | |
   | running | waiting (hook) | waiting | ask session_waiting |
   | waiting | resumed (hook: turn started) | running | clear the waiting request |
   | running, waiting | exited (observed: Claude exited, window open on a shell) | ended | clear waiting request |
   | running, waiting, ended | idle_timeout (24 h without activity or attachment) | parked | close the window, keep the record |
   | parked, ended | relaunch | starting | new window running `claude --resume <session id>` |
   | starting, running, waiting, ended | window_gone (observed) | parked | keep the record |
   | everything else: claimed events invalid, observed events ignored | | | |

   "Activity" is a hook event or a tmux client attached to that window. Only parking closes a window; nothing else kills one.
10. **Window lifecycle** (user). When Claude exits, the window stays open on a shell so its output can be read. After 24 hours with no activity and no one attached, the session is parked: its window closes and the ticket shows Relaunch, which reopens the same conversation.
11. **Overturns an MVP non-goal** (user): the board now launches and parks tmux sessions, only for this feature and only on its own server.

## Acceptance checks

1. Launch from an unplanned ticket creates the project's tmux session and a window named by the ticket on `tmux -L foreman`, running Claude in the main checkout with the paired prompt; a second Launch focuses the same window.
2. Launch from a draft epic starts `/tight-spec` on it; from an unplanned bug starts `diagnosing-bugs`.
3. Restarting both board services leaves every launched window running and attached clients connected.
4. A launched session that stops at a permission prompt produces one session waiting request within 10 seconds, with a browser notification; answering in tmux clears it.
5. The notification drawer opens from the badge on every page and lists the same pending requests as Needs you.
6. A session idle and unattached for the parking limit (shortened in a test configuration) is parked: window gone, record kept, Relaunch shown; Relaunch opens a window whose conversation continues the earlier one.
7. A window closed by hand moves the session to parked and offers Relaunch.
8. The user's global Claude Code settings file is unchanged by any launch.

## Verification plan

- Machine tests for every row of Decision 9.
- Integration tests against a real tmux server on a temporary socket: create session and window, focus existing, liveness reads, park closes only the target window.
- Hook tests: the per-launch settings produce the two hook commands; the CLI posts and clears session waiting.
- A live run with a real launched Claude session for checks 1, 2, 4 and 6, using a scratch ticket and a shortened parking limit.
- Browser runs for the Launch control, ticket session state, attach command and drawer; light and dark, 390 and 1440 px; screenshots looked at.

## Ask-first boundaries

- Installing or enabling the `foreman-tmux` service on the user's machine.
- Any change to the user's global Claude Code settings or hooks.
- Launching a session against a real project ticket during the build (use a scratch ticket).

## Left to the builder

- Exact hook events used (provided they cover permission prompts and end of turn).
- How liveness is polled from tmux and how often.
- Drawer layout within the house design language.
- Slicing into tickets.
