---
id: fm-c2w.9
title: "Merge action with stack and head-sha guards"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.8"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Live run on rpmessner/beads-board-scratch passed every check (refusals, merge commit at confirmed head, retarget, branches kept, observed merged); real fixtures recorded. Merged 88a4220."
---

## What to build
The one write the board makes: merging the bottom of a stack, safely, with confirmation (spec Decision 10).


## Acceptance
- [ ] Merge-action machine (idle, confirming, merging, retargeting, merged, failed) on Board.Fsm; guards read forge capabilities
- [ ] Rules enforced in the job: bottom of stack only, not draft, checks passing or absent, mergeable, merge commit, expected head sha; audit table
- [ ] Confirm dialog names CR, target, head sha, linked beads and the follow-up retarget; then the child retargets; no branch deletion
- [ ] Ask the user before creating the scratch GitHub repo; live run there: top of stack refused, bottom merged at the confirmed sha, child retargeted, moved head refused, ticket goes merged and the bd close suggestion shows (check 8)
- [ ] Recorded responses from the live run refresh the contract fixtures
