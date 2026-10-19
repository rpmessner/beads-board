---
id: fm-3c3.4
title: "Parking and relaunch"
type: feature
status: closed
priority: 2
parent: fm-3c3
blocked_by: ["fm-3c3.1","fm-3c3.2"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-19
close_reason: "Merged 0783696: parking and relaunch, live resume proven."
---

## What to build
Idle sessions don't pile up and are never lost: after a day of inaction the window is closed and the ticket offers Relaunch into the same conversation. Spec Decisions 9 (parking rows) and 10.

## Interfaces
Consumes: the session record (ticket 1) and the activity signal (ticket 2).


## Acceptance
- [ ] Activity = a hook event or a tmux client attached to the window; idle_timeout after 24 h (configurable, shortened in tests) parks the session: only that window closes, the record stays
- [ ] Relaunch on a parked or ended session opens a new window running claude --resume with the stored session id; the conversation continues (check 6)
- [ ] A window closed by hand moves the session to parked with Relaunch offered (check 7)
- [ ] Session machine rows idle_timeout and relaunch; tests on a temporary tmux socket; live run with a shortened limit; mix precommit green

## Notes
- 2026-10-18 user: User 2026-10-18: Relaunch must be available from the epics list rows and the epic detail page as well as the ticket sheet.
