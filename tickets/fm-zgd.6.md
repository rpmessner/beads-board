---
id: fm-zgd.6
title: "Workflow wiring: briefs and close-out use board requests"
type: task
status: in_progress
priority: 2
parent: fm-zgd
blocked_by: ["fm-zgd.1","fm-zgd.3","fm-zgd.4"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
Changes in the skills repo (dispatch, board) so the workflow uses the inbox: build sessions ask questions on the board, and coordinator close-out requests push and PR there. Spec Decision 11.

## Interfaces
Consumes: board ask / board wait for decision (ticket 1), push (ticket 3), open_pr (ticket 4).


## Acceptance
- [ ] dispatch brief template: build-time questions go through board ask decision and wait
- [ ] dispatch close-out: after the commit, post push and open_pr requests and wait instead of asking in the terminal; agents-never-push rule kept with one line pointing at board requests
- [ ] board skill documents ask and wait for every kind
- [ ] A real pi session asks a decision, the user answers on the board, the pane shows it continuing (check 5)
- [ ] A real dispatch close-out pushes and opens its PR through requests, no terminal push or PR question; the agent hook still blocks an agent pushing directly (check 9)
- [ ] skills repo check.py green
