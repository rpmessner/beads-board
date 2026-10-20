---
id: fm-3c3.10
title: "Kanban moves: move one card end to end (Queued to In flight)"
type: feature
status: open
priority: 2
parent: fm-3c3
blocked_by: ["fm-3c3.8"]
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-20
closed: null
close_reason: null
---

Spec: docs/specs/kanban-moves.md (decisions 1, 2, 4, 5, 6, 8 menu half).

Move records with the move state machine (house FSM DSL); the Move to... menu on epic-page cards; refused drops state why and create nothing; the visible, cancellable queue on the epic page; delivery to the epic coordinator as one message when its session is idle, under the Reply screen check; launching or relaunching the coordinator when it has none. Only Queued -> In flight is wired; the card moves when the dispatch event lands and the move becomes done.

Acceptance: the spec's first four acceptance checks for this move kind, with a stub epic coordinator on scratch tmux; menu at 390 px and by keyboard; screenshots light/dark at 390 and 1440 inspected; mix precommit green.
