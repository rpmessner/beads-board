You are a build session in foreman (~/dev/utils/fm-notify, a git worktree on branch `fm-notify`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Browser notifications for new requests: a native OS notification (Windows toast, macOS Notification Center) once per new pending request across any number of open tabs, opt-in from an explicit control, with the in-app count unchanged.

## Read first
- AGENTS.md (house rules, incl. the clarified copy rule); docs/specs/approvals-inbox.md (Decision 10); tickets/fm-zgd.2.md; docs/sessions/bb-inbox.md (pending count, live broadcasts, tab title).

## Tickets
fm-zgd.2 (in progress, owned by the coordinator; do not edit tickets/).

## Skills
- `tdd` at these seams: the control's visibility per permission state (default, granted, denied); exactly-once delivery across tabs (a tab election or BroadcastChannel/localStorage lock, your call, justified); no permission prompt without a click.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against f1b4f91fdae5b78c37ae88be5a5ce7678ea6265c before printing the marker: Standards (stateful UI on a declared machine where it is a real lifecycle), Spec (fm-zgd.2 acceptance), Risk (duplicate notifications, missed ones after reconnect). One axis after another; no subagents.

## Decisions already made
- Notification API only; no service worker push, no push service. A board tab must be open (background is fine).
- Notification text: the request kind and the ticket ("Push · fm-zgd.4", "Decision · fm-3c3.1"); clicking it focuses the tab on Needs you.

## Rules
- No commits, no pushes, no ticket edits (tickets/ is the coordinator's), no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman runs on port 4747 as systemd services: do not stop or touch them, their config or their database. Use another port and this checkout's own databases.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-zgd.2 "<milestone; next step>"` at milestones.

## Done when
- Every fm-zgd.2 acceptance item holds with Playwright tests for granted and denied permission and two open tabs (exactly one notification per new request); screenshots of the control light and dark at 390 and 1440 px, looked at; mix precommit green.
Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/fm-notify.md (changes, delivery design, evidence, review findings per axis, final gate). Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-zgd.2 --path docs/sessions/fm-notify.md`. Then print FM-NOTIFY DONE alone on the last line.
