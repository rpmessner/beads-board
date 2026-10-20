---
id: fm-3c3.12
title: "Kanban moves: drag and drop on the epic page"
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

Spec: docs/specs/kanban-moves.md (decision 8). Desktop drag and drop creating the same moves as the menu, with drop targets showing allowed/refused before release. Prefer a small LiveView hook over a new dependency.

Acceptance: Playwright drag of an allowed and a refused pair; same move records as the menu; screenshots light/dark at 1440 inspected; mix precommit green.
