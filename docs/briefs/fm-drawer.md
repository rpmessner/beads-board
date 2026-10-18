You are a build session in foreman (~/dev/utils/fm-drawer, a git worktree on branch `fm-drawer`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
A notification drawer: from the Needs you badge on any page, a drawer opens listing the same pending requests as the Needs you page, with the same actions, so the user can answer, approve or decline without leaving the page they are on.

## Read first
- AGENTS.md (house rules, clarified copy rule); docs/specs/session-launcher.md (Decision 7); tickets/fm-3c3.3.md; docs/sessions/bb-inbox.md (Needs you, request cards, pending count), fm-push.md (push card), fm-notify.md (sidebar control, count hook), bb-tabs.md (sheet patterns).

## Tickets
fm-3c3.3 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd` at these seams: the drawer lists exactly the pending requests (same source as Needs you); actions from the drawer resolve requests exactly as on the page (shared card component, no second implementation); live updates while open; keyboard (Escape closes, focus returns to the badge) and focus trap.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 9bac717f039da142c93752cd2176b3ed265fa420 before printing the marker: Standards (open/closed drawer state on a declared machine only if it is more than URL data; say which), Spec (fm-3c3.3 acceptance), Risk (an action taken twice from page and drawer). One axis after another; no subagents.

## Decisions already made
- Fluxon sheet or drawer component if it fits. The badge opens it on every page; Needs you stays the full page.
- The open-PR and merge request kinds are being built in parallel (fm-zgd.4, fm-zgd.5): reuse the shared card component so new kinds appear in the drawer without drawer changes.

## Rules
- No commits, no pushes, no ticket edits, no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman on port 4747: do not touch it, its config or database. Use another port and this checkout's own databases.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-3c3.3 "<milestone; next step>"` at milestones.

## Done when
- Every fm-3c3.3 acceptance item holds with tests; browser-checked on Initiatives, Pull requests, Settings and Documents, light and dark, 390 and 1440 px, screenshots looked at; mix precommit green.
Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/fm-drawer.md (changes, evidence, review findings per axis, final gate). Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-3c3.3 --path docs/sessions/fm-drawer.md`. Then print FM-DRAWER DONE alone on the last line.
