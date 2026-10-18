---
id: fm-c2w.12
title: "Durable filters and sidebar project filter"
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
close_reason: "Merged dbaa1ad: URL filters, per-browser restore, sidebar project filter with highlight; 157 tests"
---

## What to build
User feedback from the first demo (2026-10-18): filter state is lost when navigating to Settings and back, and the sidebar project list should act as the project filter with the active one highlighted.


## Acceptance
- [ ] Initiatives filters (project, beads status, type, label, search, stale) live in the URL query; back/forward and reload keep them; a copied URL reproduces the view
- [ ] Leaving for Settings (or any page) and returning restores the last filters, kept per browser
- [ ] Clicking a project in the sidebar sets the project filter; the active project is highlighted in the sidebar (light and dark); clicking it again clears it
- [ ] The filter UI is a declared Board.Fsm machine if it has states beyond plain values; LiveView tests for each item; screenshots looked at
- [ ] No explanatory copy added
