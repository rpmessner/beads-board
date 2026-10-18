---
id: fm-axu.4
title: "Skills and house rules switch to board ticket commands"
type: task
status: in_progress
priority: 2
parent: fm-axu
blocked_by: ["fm-axu.3"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
The house workflow moves from `bd` to the `board` ticket commands once beads-board has migrated. Spec Decision 9.

## Interfaces
Consumes: the CLI ticket commands (ticket 1).


## Acceptance
- [ ] to-tickets, dispatch (incl. dispatch from ready across repos via board ready), wayfinder and the board skill use board ticket commands; no bd left in skills
- [ ] House AGENTS.md beads section replaced by a short tickets section
- [ ] board ready across repos lists the same tickets bd ready did for the same state (check 6)
- [ ] A real dispatch close-out and a /to-tickets run work end to end on ticket files with no bd on PATH (check 7)
- [ ] skills check.py green
