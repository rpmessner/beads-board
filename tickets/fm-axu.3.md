---
id: fm-axu.3
title: "foreman adopt, proven on beads-board"
type: task
status: in_progress
priority: 2
parent: fm-axu
blocked_by: ["fm-axu.1","fm-axu.2"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
One command that onboards any repo to foreman, migrating beads when present, and its first real use: beads-board's own cutover. User decisions 2026-10-18: adopt may append the repo entry to the user's config itself (only ever appending one entry); the CLI stays an Erlang escript, also on the Mac. Spec Decisions 8 and 10.

## Interfaces
Consumes: format and check (bb-axu.1), files reader (bb-axu.2). Produces: `foreman adopt`, used by bb-axu.5 and bb-axu.6.


## Acceptance
- [ ] foreman adopt [path] is idempotent: a re-run only fixes what is missing
- [ ] Registers the repo: appends one [[repos]] entry (key, path, prefix, github from origin) to the global config and prints it; never rewrites other entries (the web and worker still never write config)
- [ ] Tickets: with .beads present, backup tarball outside the repo, convert every issue incl. closed (fields, all dependency types, labels, comments into dated Notes, ids unchanged), scripted comparison equal against a fresh bd export (check 1), then remove .beads and its hooks; without .beads, create tickets/
- [ ] Agent context: a marked block in the repo AGENTS.md pointing at the foreman skill (no copied instructions); repo beads blocks removed
- [ ] Installs the foreman check pre-commit hook
- [ ] Stops before committing and prints the full change; the commit is made in a clean checkout with user approval
- [ ] Proven on beads-board itself: board switched to files, stages and history unchanged (check 2)
