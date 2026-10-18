---
id: fm-c2w.14
title: "Preview servers from the ticket sheet, tied to the ticket's stage"
type: task
status: in_progress
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.6"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
User direction (2026-10-18): worktree preview servers are launched from the board on demand, from the ticket they belong to, and cleaned up when that ticket moves forward, so there are no orphan servers. The ticket sheet (bb-c2w.6) is the surface for the controls.


## Acceptance
- [ ] The ticket sheet shows a Preview control for a ticket with a session worktree: start, open URL, follow logs, stop
- [ ] Start runs the worktree app as a transient systemd user service through devserve (skills initiative sk-9ro); never started automatically
- [ ] The preview lifecycle is a Board.Fsm machine; moving the ticket past review (merged, done, abandoned) stops and cleans up its preview, including its dev database
- [ ] Previews with no ticket or a vanished worktree are listed and can be stopped; nothing is left running unowned
- [ ] Blocked on devserve existing (sk-9ro, skills repo): check it before starting

## Notes
2026-10-18: devserve is specced and ticketed (skills sk-9ro; foreman as first app is sk-9ro.2). Start this after sk-9ro.2 lands.
