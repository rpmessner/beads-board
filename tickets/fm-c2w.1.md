---
id: fm-c2w.1
title: "Probe: can the board's beads reads break an agent's bd write?"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "cc62dcb: zero failed agent writes in 4,155 under concurrent exports (two runs, four scenarios); read rule in docs/probe-bd-concurrency.md"
---

## What to build
The answer to the riskiest unknown before the reader exists: embedded Dolt is opened by every bd process, and even bd export rewrites store files, so a board read could collide with an agent's write. The spec's rule (Decision 5): the board is failure tolerant and never interrupts an agent's bd write. This probe finds out which case we are in and fixes the read rule ticket 4 implements.

## Interfaces
Produces: the read rule (written decision with evidence), consumed by the beads read model.


## Acceptance
- [ ] On a scratch copy of a real embedded-store repo, a bd export loop runs against a loop of agent-style writes (create, update, note, close) for 10 minutes
- [ ] Failed writes, failed reads and their errors counted and recorded
- [ ] Read rule chosen and written in the repo docs: normal reads, skip while a write is visible (how it is detected), or slower polling with the 30 s freshness target
- [ ] No real repo touched

## Notes
Correction: merged in 5fb8e9e (the close reason's cc62dcb was the pre-merge head).
