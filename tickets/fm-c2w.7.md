---
id: fm-c2w.7
title: "Agent API and the board CLI"
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
close_reason: "Merged de0b961: agent API and board CLI, Postgres spool, hermetic per-checkout test DBs; token path only from BOARD_TOKEN_FILE; 247 tests"
---

## What to build
How agents keep the board current without ever being blocked by it (spec Decisions 3, 8, 11). The verbs are the contract the skills wiring (tickets 11, 12) builds on.

## Interfaces
Consumes: apply_event and the machines' events (5).
Produces: the board CLI verbs and the HTTP API. Consumed by the skills-repo tickets.


## Acceptance
- [ ] Localhost API with a bearer token kept under ~/.ssh; claimed events only (observed events cannot be posted)
- [ ] board CLI: verbs for every claimed ticket event and the draft-epic events; repo resolved from the bead id prefix, drafts by slug and working directory or --project; --json
- [ ] Out-of-order claim exits 3 printing stage and allowed events; it is logged as invalid (check 4)
- [ ] App down: event written to the spooled-events table, exit 0 with a warning; replayed on boot; Postgres down too: warning, exit 0 (check 5)
- [ ] Each CLI write pings a sync of that repo

## Notes
2026-10-17 (user): add the verb board attach <ticket> --epic <epic> (and detach), writing the board-side epic link; used for cross-repo tickets such as sk-5o2/sk-osj under bb-c2w.
