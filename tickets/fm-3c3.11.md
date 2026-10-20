---
id: fm-3c3.11
title: "Kanban moves: request changes, approve, close and abandon"
type: feature
status: open
priority: 2
parent: fm-3c3
blocked_by: ["fm-3c3.10"]
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-20
closed: null
close_reason: null
---

Spec: docs/specs/kanban-moves.md (decisions 3, 6, 9). Adds the remaining moves from the table: Review -> In flight with a note, Review -> Shipping (approve: commit), Shipping -> Done (close, after merge or push where the forge requires it), any live column -> Abandoned (stop a running build). The coordinator-side prompt template change lives in the foreman skill and is the coordinator's to make.

Acceptance: each move delivers its instruction and completes on its real stage event; contrary events supersede; refused drops for every disallowed pair; mix precommit green.
