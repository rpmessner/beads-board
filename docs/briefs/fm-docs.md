You are a build session in foreman (~/dev/utils/fm-docs, a git worktree on branch `fm-docs`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Read project documents inside foreman: a Documents view per project (README, AGENTS.md and every .md under docs/), brief/report/spec paths that open in the viewer, and ticket content rendered as Markdown, all with MDEx. Read-only.

## Read first
- AGENTS.md (app house rules: status-only copy, human times, Foreman.Fsm for stateful UI); ticket fm-c2w.18 (`git show main:.beads/issues.jsonl`); docs/sessions/bb-tabs.md (ticket sheet tabs) and docs/sessions/fm-reader.md (ticket file sections).
- MDEx's docs for the pinned version you add (GFM extensions, syntax highlighting themes, HTML sanitizing).

## Tickets
fm-c2w.18. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: path resolution (only files inside configured repo folders; `..` escapes and symlinks pointing outside refused; a worktree path that no longer exists falls back to the same relative path in the main checkout); rendering (task lists, tables, code highlighting, raw HTML stripped); relative links between docs staying in the viewer.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against fb24954220996328ae5e8f5f94450984c1a53757 before printing the marker: Standards, Spec (fm-c2w.18 acceptance), Risk (path traversal, symlinks, HTML injection, large files). Run the axes one after another; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- MDEx (Fluxon has no Markdown component); GFM; light and dark highlighting themes matching the app; raw HTML stripped.
- Documents view: file list beside the rendered document, per project. History and draft-epic paths link into it. Ticket sheet sections render as Markdown, acceptance checkboxes included.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. Spawn no subagents.
- The installed foreman runs on port 4747: do not touch it, its config or its database. Use another port and this checkout's own databases. Use /usr/bin/rm, not rm.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-c2w.18 "<milestone; next step>"` at milestones; warnings never block work.

## Done when
- Every fm-c2w.18 acceptance item holds with test evidence; browser-checked light and dark at 390 and 1440 px on a scratch repo with real-looking docs (a long spec, a table, code blocks, a ticket with checkboxes), screenshots looked at; mix precommit green.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/fm-docs.md: what changed, the path rules, screenshots, review findings per axis, final gate output. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-c2w.18 --path docs/sessions/fm-docs.md`. Then print FM-DOCS DONE alone on the last line.
