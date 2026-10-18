---
id: fm-c2w.13
title: "Curated view buttons instead of filter dropdowns"
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
close_reason: "Merged 1d2e8de: view presets in config, button group, collapsed advanced filters; 167 tests"
---

## What to build
User feedback on the demo (2026-10-18): dropdown filters feel heavy. Replace them with a curated set of preset view buttons, with the full filters tucked into a normally closed advanced section.


## Acceptance
- [ ] A row of view buttons replaces the dropdown row: Open (default: everything not closed), In flight (dispatched, building, reported, in_review), Stale, All; search stays visible; project still comes from the sidebar
- [ ] Views are data: named filter presets shipped in the defaults, curated in board.toml [[views]] (add, remove, reorder), validated like columns (unknown stage or status names are load errors), hot-reloaded
- [ ] Advanced filters (beads status, type, label) in a collapsed Filters section, closed by default; open/closed remembered per browser; any advanced filter active shows on the closed section header as a count
- [ ] URL carries the view (?view=stale&project=...); existing URL, back/forward and restore-on-return behaviour keeps working; old ?status=/type=/label= links still apply as advanced filters
- [ ] Disclosure and view selection on Board.Fsm where they have states; LiveView tests; screenshots light and dark looked at; no explanatory copy
