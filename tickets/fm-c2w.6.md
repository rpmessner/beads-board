---
id: fm-c2w.6
title: "Epic view and ticket sheet"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.5"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged e8530cd: epic view, ticket sheet, URL contract; 184 tests; coordinator review fixes applied"
---

## What to build
The drill-down from an initiative to its tickets and from a ticket to its full history, per the approved mockup.


## Acceptance
- [ ] Opening an epic shows its tickets on config-defined stage columns, planned and fallout apart, with the blocking graph matching bd
- [ ] Ticket sheet: beads fields, stage, stage history (including refused claims), sessions, agent notes, linked CRs, allowed next events
- [ ] Editing columns in board.toml updates the view live (check 10)
- [ ] LiveView tests for both; screenshots light and dark match the approved mockup
