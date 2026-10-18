---
id: fm-c2w.5
title: "Initiatives view: epics as the spine"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.3","fm-c2w.4"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged c18c59f: overlay, stage/epic machines, epic tree, Initiatives home; acceptance 2b on real repos; 143+ tests"
---

## What to build
The board's home: every initiative across projects and where it stands, with the work under it, the fallout it produced, and the few orphans (user: work derives from epics). Introduces the overlay and the two machines everything else moves.

## Interfaces
Consumes: Board.Fsm (3), the projection and config (4).
Produces: Board.Stage and Board.Epic event names and states, Board.Overlay.apply_event, the epic tree query. Consumed by tickets 6, 7, 8.


## Acceptance
- [ ] Ticket-stage and epic machines declared with Board.Fsm exactly as spec Decisions 7 and 8; generated docs committed
- [ ] Overlay tables and apply_event (lock, step, record event, run effects in one transaction, broadcast after commit); invalid claims logged
- [ ] Backfill: closed beads done, open queued; beads epics ticketed or done; epics never get a ticket stage
- [ ] Epic tree derived: planned (parent-child, any depth), fallout (discovered-from under the epic), orphans
- [ ] Home view per the approved mockup: epic rows with derived stage, progress, histogram, fallout count; drafts on top; Unplanned lane; filters
- [ ] fe-813 and fe-lwp match bd; a discovered-from ticket shows as fallout; an orphan shows in Unplanned (check 2b)
- [ ] Events applied from iex move rows live

## Notes
2026-10-17 (user, mockup review): fallout wins over parent-child; cross-repo tickets join an epic via board-side links (overlay table, set by board attach); sub-epics are expandable rows with rolled-up counts; Unplanned collapsed, grouped by project. See spec Decisions 8 and 13.
