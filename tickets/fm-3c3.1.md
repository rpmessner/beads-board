---
id: fm-3c3.1
title: "Launch from the board into the board-owned tmux server"
type: feature
status: closed
priority: 2
parent: fm-3c3
blocked_by: ["fm-c2w.17"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-19
close_reason: "Merged 2e5954e; foreman-tmux installed with the user's tmux config (prefix C-s, theme) and running; Launch is live on the board."
---

## What to build
The Launch control and everything under it: the board-owned tmux server as its own service, per-project sessions and per-ticket windows, a Claude coordinator started with the paired workflow prompt, and the session record the rest of the epic builds on. Spec Decisions 1-5, 8, 9 (launch rows), 11.

## Interfaces
Produces: the launched-session record (session id, project, ticket, window), the session machine, the tmux adapter. Consumed by tickets 2 and 4.


## Acceptance
- [ ] foreman-tmux systemd user unit (tmux -L foreman) in deploy/systemd with README install steps; never part of the web or worker units
- [ ] Launch on unplanned tickets and idea/draft epics only; creates the project session if missing and a window named by the ticket; a second Launch focuses the existing window (check 1)
- [ ] Claude runs in the main checkout with --session-id stored on the session record, no --model and no --permission-mode; the window stays open on a shell after Claude exits
- [ ] Opening prompt templates live in the foreman skill and pair with the workflow: draft epic -> /tight-spec, unplanned feature or task -> flow, unplanned bug -> diagnosing-bugs (check 2)
- [ ] Session machine rows launch, started, exited and window_gone on Board.Fsm; ticket shows state and a copyable attach command
- [ ] Restarting both board services leaves launched windows and attached clients untouched (check 3); global Claude settings unchanged (check 8)
- [ ] Integration tests on a temporary tmux socket; live run on a scratch ticket; mix precommit green

## Notes
- 2026-10-18 user: User 2026-10-18: Launch must also be available on draft/idea epic rows in the epics list, not only the detail/sheet. Goal: separate planning sessions from the main coordinator session, which has become a bottleneck.
