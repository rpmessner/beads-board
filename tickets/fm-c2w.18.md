---
id: fm-c2w.18
title: "Documents viewer and Markdown rendering (MDEx)"
type: feature
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.17"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged 3f6b04a: documents viewer and Markdown rendering; 424 tests."
---

## What to build
Read project documents inside the app: specs, ADRs, session reports, briefs, README and AGENTS, rendered with MDEx (Fluxon has no Markdown component), plus Markdown rendering of ticket content. Read-only. User request 2026-10-18; build after the rename, as a sibling of the ticket reader rewrite.


## Acceptance
- [ ] MDEx renders GitHub-flavoured Markdown (task lists, tables, footnotes, autolinks) with syntax highlighting in light and dark themes; raw HTML stripped
- [ ] Documents view per project: README, AGENTS.md and every .md under docs/ in a file list beside the rendered document
- [ ] Brief, report and spec paths in stage history and on draft epics open in the viewer; a path in a removed worktree falls back to the same relative path in the main checkout
- [ ] Ticket sheet sections render as Markdown, acceptance checkboxes included
- [ ] Only files inside configured repo folders: .. escapes and symlinks pointing outside are refused (tests); relative links between docs stay in the viewer
- [ ] Browser-checked light and dark, 390 and 1440 px, screenshots looked at; mix precommit green
