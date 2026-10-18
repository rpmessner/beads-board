You are a build session in foreman (~/dev/utils/fm-adopt, a git worktree on branch `fm-adopt`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
`foreman adopt [path]`: one idempotent command that onboards any repo to foreman, migrating its beads when present, proven by preparing foreman's own cutover from beads to ticket files. The cutover commit itself is the coordinator's, after the user approves it.

## Read first
- AGENTS.md; docs/specs/ticket-files.md (approved; Decisions 8 and 10 are this ticket); ticket fm-axu.3 (`git show main:.beads/issues.jsonl` if needed).
- docs/sessions/bb-files.md (ticket file format, store, CLI) and docs/sessions/fm-reader.md (the files reader and the per-repo `tickets` switch).

## Tickets
fm-axu.3. The coordinator has already claimed it; do not run bd writes in this worktree (reading with `bd export` / `bd list --json` from a scratch copy is fine, see Rules).

## Skills
- `tdd` at these seams: the converter (every field, all dependency types, labels, comments into dated Notes, closed issues, ids unchanged) on fixture exports; the comparison against a beads export; adopt's steps on a temp repo with and without .beads (idempotent re-run fixes only what is missing); config append (only appends one [[repos]] entry, never rewrites others; refuses a duplicate key or path).
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against fb24954220996328ae5e8f5f94450984c1a53757 before printing the marker: Standards, Spec (fm-axu.3 acceptance, Decisions 8 and 10), Risk (data loss in conversion; writing user config; removing .beads only after a backup and an equal comparison). Run the axes one after another; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- adopt: append the repo entry to the user's config (FOREMAN_CONFIG_DIR, else ~/.config/foreman/foreman.toml) and print it; with .beads: backup tarball outside the repo, convert, compare equal, then remove .beads and its hooks; without: create tickets/; add a marked AGENTS.md block pointing at the foreman skill; install the `foreman check` pre-commit hook; stop before committing and print the full change.
- The CLI stays an escript.

## Rules
- No commits, no pushes, no bd writes, no edits to ~/.config/foreman or any real repo other than this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- **Prove it on foreman without touching the real store:** copy this worktree's `.beads` export (`git show main:.beads/issues.jsonl`, or `bd export` against a copy) into a scratch clone under /tmp/fm-adopt-dry, run `foreman adopt` there with FOREMAN_CONFIG_DIR pointing at a scratch config, and show the comparison equal and the resulting tickets/ tree. The real cutover (in ~/dev/utils/foreman) is the coordinator's step after the user approves.
- The installed foreman runs on port 4747: do not touch it, its config or its database.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-axu.3 "<milestone; next step>"` at milestones; warnings never block work.

## Done when
- Every fm-axu.3 acceptance item that does not need the real cutover holds with test evidence; the dry run on a scratch copy of foreman shows: 40 tickets converted, comparison equal (counts, statuses, parents, all dependency types, labels, comment counts), `foreman check` valid, adopt re-run is a no-op.
- The report ends with the exact commands the coordinator will run for the real cutover.
- mix precommit green.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/fm-adopt.md: what changed, the converter mapping, the dry-run evidence, the real-cutover commands, review findings per axis, final gate output. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-axu.3 --path docs/sessions/fm-adopt.md`. Then print FM-ADOPT DONE alone on the last line.
