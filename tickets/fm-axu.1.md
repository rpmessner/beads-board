---
id: fm-axu.1
title: "Ticket file format, board check and CLI ticket commands"
type: feature
status: closed
priority: 2
parent: fm-axu
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged 5a6f1c7: ticket file format, board check, offline CLI ticket commands; 330 tests in the slice."
---

## What to build
The ticket file format and the agent toolset that writes it: the `board` CLI creates, edits, closes and links tickets as files in the current checkout, and `board check` validates them. Works offline. Spec Decisions 2-6.

## Interfaces
Produces: the ticket file schema, a parser/printer module shared by the CLI and the board's reader (ticket 2), id generation, `board check` (used by the pre-commit hook in tickets 3, 5, 6).


## Acceptance
- [ ] Format per spec Decision 3: parse then print is identity on canonical files (property test); unknown keys and malformed frontmatter are errors
- [ ] Ids per Decision 4: random top-level code checked against existing files, next free .N for children, prefix from board.toml; board renumber rewrites the file and every reference
- [ ] board check rules per Decision 6: schema, id matches filename, parent and blockers exist, no cycles, no epic blocking its own child; exit nonzero with file and reason
- [ ] new, show, ls, ready, update, close --reason, reopen, dep add|rm, note, tree work in a temporary repo with no server; canonical output gives minimal diffs; --json everywhere
- [ ] ready = open, no open blockers, not an epic
- [ ] mix precommit green
