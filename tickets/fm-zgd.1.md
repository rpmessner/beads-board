---
id: fm-zgd.1
title: "Requests and decisions end to end"
type: feature
status: closed
priority: 2
parent: fm-zgd
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged d5aa7cf: request backbone, decisions end to end, Needs you, counts, Requests tab; browser-checked; 308 tests."
---

## What to build
The request backbone with the one kind that writes nothing external: build-time decisions. A session asks a question through the CLI, it waits on the Needs you page, the user answers or declines, and the asker's `board wait` gets the outcome. Spec Decisions 1, 7, 8, 9 (page and Requests tab), 10 (in-app count only).

## Interfaces
Produces: the request record (kind, ticket or epic, asker actor and session, facts, state, outcome, note), the request machine and its events (ask, approve, answer, decline, withdraw, facts_changed, start, succeeded, failed, orphaned), `board ask` / `board wait`, and a per-kind extension point for action kinds (fact validation at creation, a job for approve). Tickets 2-6 consume these.


## Acceptance
- [ ] Request record and request machine on Board.Fsm with every row of spec Decision 7 tested (invalid claimed and ignored observed events included); diagram golden
- [ ] board ask decision <ticket> returns the request id at once; board wait <id> prints the outcome as JSON when resolved; timeout prints current state; both exit 0 (CLI never fails an agent)
- [ ] Needs you page first in the sidebar: pending oldest first; decision cards show question, options with the recommendation marked, free text; Answer and Decline with optional note; recent outcomes collapsed
- [ ] Sidebar count badge and tab title (N) beads-board track the pending count live
- [ ] Ticket sheet Requests tab lists that ticket's requests
- [ ] Ticket abandoned or done supersedes its pending requests; asker's wait reports it
- [ ] Decline with a note reaches board wait with the note; nothing executes (check 6)
- [ ] Browser-checked light/dark, 390/1440; mix precommit green
