---
id: fm-vtx.3
title: "Documents in build worktrees"
type: task
status: in_progress
priority: 2
parent: fm-vtx
blocked_by: ["fm-vtx.1","fm-vtx.2"]
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-20
closed: null
close_reason: null
---

## What to build

Documents that exist only in a build's worktree open on the board. Resolution tries the main checkout first, then the worktrees the board recorded for that ticket's sessions: the session records' workdir and `workdir`/`worktree` values in the ticket's history payloads (the sources Previews uses), accepted only when they are git worktrees of a configured repo. A document found only in a worktree is labelled with the worktree name ("in worktree fm-epic-coord") in the Documents section and the panel. The panel URL carries the worktree source; the server re-checks it against the recorded set on every read. If the worktree was removed, fall back to the main checkout; found in neither, the panel shows unavailable. Read only.

After deploy, the coordinator opens a real dispatched session's report on the live board.

Spec: docs/specs/doc-links.md, decisions 6 and 8.

## Interfaces

- Consumes: the collector/resolver from the sheet ticket (adds a worktree source) and the panel URL form from the panel ticket (adds the source).

## Acceptance

- [ ] An unmerged report present only in a recorded worktree opens in the panel with the worktree label; after merge it opens from the main checkout without the label.
- [ ] Removed worktree falls back to main; absent everywhere shows unavailable.
- [ ] `/etc/passwd.md`, `../x.md`, and absolute paths in unrecorded directories never link, and a hand-crafted panel URL naming an unrecorded directory or a non-worktree path is refused.
- [ ] Unit tests on the resolver's allowed roots and rejection cases.
- [ ] Post-deploy check on the live board recorded in the ticket notes.
