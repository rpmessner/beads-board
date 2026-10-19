You are a build session in foreman (~/dev/utils/fm-park, a git worktree on branch `fm-park`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Idle planning sessions don't pile up and are never lost: a launched session idle and unattached for 24 h is parked (only its window closes, the record stays), and Relaunch on the ticket sheet, the epic detail page and the epic list rows reopens the same conversation with claude --resume in a new window; a window closed by hand also parks with Relaunch offered.

## Read first
- AGENTS.md; docs/specs/session-launcher.md (Decisions 9 parking rows, 10); tickets/fm-3c3.4.md (incl. the user's note on list/detail Relaunch); docs/sessions/fm-launch.md and fm-waiting.md (session records, machine, tmux adapter, hooks as the activity signal).

## Tickets
fm-3c3.4 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd` at these seams: activity = a hook event or a tmux client attached to that window; idle_timeout configurable (24 h default, shortened in tests); park closes only that window; relaunch with the stored --session-id; window_gone parks; the session machine rows idle_timeout and relaunch.
- `verify-before-claiming`; `code-review` against b5ebeabe0d6c87e9cd3baeb8a54ea9b19927f8c4 (Standards, Spec, Risk: never closing a window someone is attached to; never resuming the wrong conversation). No subagents.

## Rules
- No commits, no pushes, no ticket edits, no bd. Stay inside this worktree. Use /usr/bin/rm, not rm.
- The installed foreman on 4747, its database and the installed foreman-tmux server: do not touch. Live checks on a temporary tmux socket and a scratch repo under /tmp; kill the scratch server afterwards.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-3c3.4 "<milestone; next step>"` at milestones.

## Done when
- Every fm-3c3.4 acceptance item holds (incl. the user note); a live scratch run with a shortened limit parks a session and Relaunch continues the same conversation; screenshots light and dark at 390 and 1440 px looked at; mix precommit green.

## Report back
Write docs/sessions/fm-park.md. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-3c3.4 --path docs/sessions/fm-park.md`. Then print FM-PARK DONE alone on the last line.
