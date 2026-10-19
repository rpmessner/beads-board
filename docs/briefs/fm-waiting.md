You are a build session in foreman (~/dev/utils/fm-waiting, a git worktree on branch `fm-waiting`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
A launched planning session that needs the user reaches them: per-launch Claude Code hooks post a session_waiting request (reason input, permission or usage_limit) that shows on Needs you, the drawer and as a browser notification, and clears when the session works again; usage_limit requests carry a Continue button that sends exactly "continue" + Enter to that window.

## Read first
- AGENTS.md; docs/specs/session-launcher.md (Decisions 6, 6a, 9 waiting rows); tickets/fm-3c3.2.md (incl. notes); docs/sessions/fm-launch.md (launcher, session machine, planning-session records, tmux adapter), bb-inbox.md and fm-push.md (request kinds), fm-notify.md, fm-drawer.md; the pi-wait LIMITED patterns in ~/dev/utils/skills/skills/dispatch/scripts/pi-wait.
- Claude Code hooks: check the installed Claude Code's settings schema for hook events that fire on permission/input waits, on end of turn, on turn start, and on API errors such as usage limits (`claude --help`, its docs if available locally); use only what the installed version supports, and fall back to pane reading for limits if no hook covers them.

## Tickets
fm-3c3.2 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd` at these seams: the session_waiting kind (no action; auto-clear); per-launch --settings JSON with the hooks (global settings untouched); session machine waiting/resumed rows; Continue sends exactly continue+Enter only for usage_limit, only on click, to the right socket/window (foreman's server for launched sessions; the default socket for pi windows reported by the coordinator).
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 151d8dbb50e094145f78d3ad6f7f229e12ea9cb5: Standards, Spec (fm-3c3.2 acceptance), Risk (the board typing into a session: nothing but the one word, never without a click; hooks failing must never break the Claude session). One axis after another; no subagents.

## Rules
- No commits, no pushes, no ticket edits, no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman on 4747 and its database, and the installed foreman-tmux server: do not touch. Live checks use a temporary tmux socket and a scratch repo under /tmp; kill the scratch server afterwards.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-3c3.2 "<milestone; next step>"` at milestones.

## Done when
- Every fm-3c3.2 acceptance item holds: tests; a live scratch launch that stops at a permission prompt produces one session_waiting request within 10 s and clears when answered; a simulated usage-limit stop shows Continue and the click sends continue+Enter; global Claude settings hash unchanged; screenshots light and dark at 390 and 1440 px looked at; mix precommit green.

## Report back
Write docs/sessions/fm-waiting.md. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-3c3.2 --path docs/sessions/fm-waiting.md`. Then print FM-WAITING DONE alone on the last line.
