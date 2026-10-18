---
id: fm-axu.5
title: "Migrate skills, form-engine and dotfiles"
type: task
status: open
priority: 2
parent: fm-axu
blocked_by: ["fm-axu.3","fm-axu.4"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
Cut over the three smaller repos with the converter and comparison from the beads-board cutover. Spec Decision 8.


## Acceptance
- [ ] Per repo: backup tarball, conversion, comparison equal (check 1), user approval, cutover commit in a clean checkout, board switched to files, stages unchanged (check 2)
- [ ] No .beads, beads hook or bd call left in these repos

## Notes
2026-10-18: cut over with foreman adopt (bb-axu.3), one repo at a time, user approval before each commit.
