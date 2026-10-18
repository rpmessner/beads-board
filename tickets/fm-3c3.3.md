---
id: fm-3c3.3
title: "Notification drawer"
type: feature
status: open
priority: 2
parent: fm-3c3
blocked_by: ["fm-zgd.1"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
Act on pending requests from any page without leaving it. Spec Decision 7.

## Interfaces
Consumes: the request backbone and Needs you list (bb-zgd.1).


## Acceptance
- [ ] A drawer opens from the Needs you badge on every page and lists the same pending requests as Needs you, with the same actions
- [ ] Live updates while open; keyboard and focus handled
- [ ] Browser-checked light and dark, 390 and 1440 px, screenshots looked at (check 5); mix precommit green
