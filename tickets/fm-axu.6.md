---
id: fm-axu.6
title: "Migrate ui-o-matic, cooldown-o-matic and we_go_next_dev"
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
Cut over the three WoW repos, which hold the most tickets and the user's active work. Spec Decision 8.


## Acceptance
- [ ] Per repo: backup tarball, conversion, comparison equal (check 1), user approval, cutover commit in a clean checkout without touching the user's uncommitted work, board switched to files, stages unchanged (check 2)
- [ ] ui-o-matic's 417 issues and the PARITY.md / AGENTS references to wow-### ids still resolve
- [ ] No .beads, beads hook or bd call left in these repos

## Notes
2026-10-18: cut over with foreman adopt (bb-axu.3), one repo at a time, user approval before each commit.
