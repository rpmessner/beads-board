---
id: fm-axu.7
title: "Remove the beads reader and measure the idle board"
type: task
status: open
priority: 2
parent: fm-axu
blocked_by: ["fm-axu.5","fm-axu.6"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
Delete the beads reading path once no repo uses it, and prove the performance goal on the installed board. Spec Decisions 7 and 8.


## Acceptance
- [ ] bd export reader, journal lock probe, process guard and export scheduler deleted; tickets = "beads" option removed
- [ ] Idle 10 min on the installed board with nothing changing: worker under 2% of a core (baseline 37%); memory, tasks and DB size flat (check 5)
- [ ] Sweep: no .beads, beads hook or bd call in any repo, skill or house file (check 8)
- [ ] mix precommit green
