---
id: fm-vtx.1
title: "Ticket sheet links documents and lists them"
type: task
status: in_progress
priority: 2
parent: fm-vtx
blocked_by: []
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-20
closed: null
close_reason: null
---

## What to build

On the ticket sheet (shared by Initiatives, the epic page and Needs you), every existing `.md` path in session-written text becomes a document link: ticket body, notes, history payload values (not only Brief/Report/Spec/Path keys) and session facts. Use the same resolution rules as request cards today: relative paths try the ticket's repo first, then other configured repos; absolute and `~/` paths only beneath a configured repo root; `..` never links; only `.md`.

Add a Documents section to the sheet listing each distinct linked document found in the ticket's text (history, that ticket's request questions and answers, body, notes). One entry per document, most recent mention first, at most 50; hidden when empty. Computed on render; nothing stored. Links still go to the full document viewer in this ticket (the panel comes in its sibling).

Spec: docs/specs/doc-links.md, decisions 1-4 and 9.

## Interfaces

- Produces: a document collector for a ticket returning ordered `{repo, path, source}` entries (source is `main` here; the worktree ticket adds worktree sources), and a path resolver both the sheet and request cards use.

## Acceptance

- [ ] wa-x0z.5's sheet lists docs/research/addon-ideas.md and its brief in Documents with no hand-written note needed.
- [ ] A history value containing a bare `docs/...md` path renders as a link (was plain text).
- [ ] Duplicate mentions collapse to one entry; order is newest mention first; cap of 50 holds.
- [ ] Non-existent, `..`, non-`.md` and outside-repo paths stay plain text.
- [ ] Request cards on Needs you link exactly as before (existing tests green).
- [ ] LiveView test at the ticket sheet component covers link render and the Documents section.
