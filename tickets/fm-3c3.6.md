---
id: fm-3c3.6
title: "Coordinator session: resume or launch from the coord command, tracked on the board"
type: feature
status: open
priority: 2
parent: fm-3c3
blocked_by: []
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-19
closed: null
close_reason: null
---

The user's coordinator (the Claude Code session that plans, dispatches and closes out) is started by hand today and its conversation id is pasted around. Make it a board-tracked session like the planning sessions.

## What to build

- A `foreman coordinator` CLI command, run inside the pane where the coordinator should live (the user's airmux layout runs it in window `coordinator` of session `coordinator` on `tmux -L foreman`). It execs Claude Code in that pane, in `~/dev/music`:
  - If foreman has a recorded coordinator conversation, resume it (`claude --resume <id>`), then deliver the orient prompt.
  - Otherwise, or with `--fresh`, start a new conversation with a new `--session-id`, record it, and deliver the orient prompt.
  - The orient prompt invokes the `orient` skill (skills repo, sk ticket filed alongside) and nothing else.
- The coordinator is recorded the way planning sessions are (durable session id, window, state, activity), but it is not tied to a ticket or a project: one coordinator, keyed as such. It gets the same per-launch hooks so waits reach Needs you (session_waiting, Continue on usage limit).
- The coordinator is never parked by the 24 h idle rule.
- The board shows the coordinator with its state and Focus / Relaunch (Relaunch resumes; a fresh start is offered separately). Placement is the builder's call; keep it small.
- A way to record an existing conversation id as the coordinator (bootstrap the current one: `foreman coordinator --adopt <id>` or similar).

## Non-goals

- Creating the airmux project or changing dotfiles (the coordinator does that).
- Starting systemd units from the CLI (the `coord` shell command does that).
- Any change to how ticket/epic planning sessions launch or park.

## Acceptance

- In a scratch tmux server: `foreman coordinator` with nothing recorded starts Claude with a new session id and records it; running it again after the pane exits resumes that id; `--fresh` records a new id.
- `--adopt <id>` records an existing id; the next run resumes it.
- A coordinator wait shows on Needs you; idle time never parks it.
- Board shows the coordinator's state; Focus selects its window; Relaunch resumes.
- `mix precommit` green.
