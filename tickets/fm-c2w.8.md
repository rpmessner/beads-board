---
id: fm-c2w.8
title: "Forge boundary and read-only PR panel"
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
close_reason: "Merged ebdba9b: forge boundary, GitHub adapter, read-only PR page, cr_* events; acceptance 9 on form-engine's real stack; 210 tests"
---

## What to build
Each project's open change requests in stack order, linked to their beads, behind a forge boundary so another forge later is an adapter plus a config line (spec Decision 9).

## Interfaces
Consumes: apply_event (5). Produces: the Board.Forge behaviour and capabilities, consumed by the merge action (9).


## Acceptance
- [ ] Board.Forge behaviour: change requests (number, title, source/target branch, head sha, draft, checks, mergeable), list, merge with expected head, retarget, declared capabilities
- [ ] Fake in-memory forge; GitHub adapter (token from gh at boot, Req); one contract suite run against both (GitHub on recorded responses)
- [ ] PR sync, stack order, detached bases, linking by bead id in title/branch/body
- [ ] Observed cr_opened / cr_closed / cr_merged move linked tickets per the stage machine
- [ ] form-engine real stack shows in order, linked, read-only; nothing mergeable whose base is not the default branch (check 9)
- [ ] Config names the forge per repo; repos without a remote show no panel
