---
id: fm-axu.2
title: "Board reads ticket files"
type: feature
status: closed
priority: 2
parent: fm-axu
blocked_by: ["fm-axu.1","fm-c2w.17"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged bf974f5: ticket-file reader per repo, last-good on parse errors, edits visible in under 1 s; 370 tests."
---

## What to build
The board reads ticket files instead of `bd export` for repos switched to files, cheaply and race-free, and shows them exactly as it shows beads tickets today. Spec Decision 7 and the per-repo switch of Decision 8.

## Interfaces
Consumes: the parser (ticket 1). Produces: the files reader and the per-repo switch used by every cutover.


## Acceptance
- [ ] board.toml per-repo tickets = "files" | "beads"; beads repos keep working unchanged
- [ ] Files repos: inotify on the main checkout tickets/ folder plus a 60 s rescan; editor-style saves (write then rename) handled
- [ ] Projection into the existing (repo, id) ticket identity: overlays, stages, sessions, links and requests carry over; acceptance progress shown as checked/total
- [ ] A malformed file keeps its last good version on the board and Settings names the file and error (check 4)
- [ ] A hand edit and a board update edit show on the board within 2 s (check 3)
- [ ] Reader tests on a temp dir: create, edit, rename-into-place, delete, malformed, rescan; mix precommit green
