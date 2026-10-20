---
id: fm-3c3.13
title: "Kanban moves: rank Queued cards"
type: feature
status: open
priority: 2
parent: fm-3c3
blocked_by: ["fm-3c3.12"]
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-20
closed: null
close_reason: null
---

Spec: docs/specs/kanban-moves.md (decision 7). A rank field in ticket files, written by the board through the ticket store; dragging within Queued (and Move up/down in the menu) sets it; foreman ready and the epic page order by it; the coordinator dispatches top-ranked ready tickets first.

Acceptance: reorder writes rank, foreman check passes, page and foreman ready agree; mix precommit green.
