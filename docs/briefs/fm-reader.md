You are a build session in foreman (~/dev/utils/fm-reader, a git worktree on branch `fm-reader`). foreman was called beads-board until today. A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
foreman reads ticket files: for repos switched to `tickets = "files"` in foreman.toml, the worker watches the main checkout's `tickets/` folder and shows those tickets exactly as it shows beads tickets today, cheaply and race-free. Repos still on beads keep working unchanged.

## Read first
- AGENTS.md (app house rules); docs/specs/ticket-files.md (approved; this ticket is Decision 7 and the per-repo switch in Decision 8); ticket bb-axu.2 (`git show main:.beads/issues.jsonl` if needed).
- docs/sessions/bb-files.md (the ticket file format, parser/printer and store from bb-axu.1: reuse the parser, do not write a second one); the current beads reader (Foreman.Beads.*, SyncJob, Runtime, projection) and docs/sessions/bb-read.md / bb-sync.md.

## Tickets
bb-axu.2. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: the per-repo switch in config; the files reader on a temp directory (create, edit, write-then-rename editor saves, delete, malformed file, rescan); projection into the existing (repo, id) identity so overlays, stages, sessions, links and requests carry over; last-good-version on parse errors.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against cfe3d15e54a1042b5e58e81ef9961877b2f7f97d before printing the marker: Standards (incl. the state-machine rule for the reader lifecycle), Spec (bb-axu.2 acceptance), Risk (inotify edge cases, partial writes, a repo switching from beads to files without losing overlay rows). Run the axes one after another; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Spec Decisions 3 and 7: inotify on the one tickets/ directory per repo plus a 60-second rescan; parse with the bb-axu.1 parser; a malformed file keeps its last good version and Settings names the file and error; acceptance progress shown as checked/total.
- The beads reader stays until bb-axu.7 deletes it; do not remove it here.
- Hand edits and `foreman update` edits show within 2 seconds.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree; tests use temporary directories. Spawn no subagents.
- The installed foreman runs on port 4747 as systemd services: do not stop or touch them, their config or their database. Use another port and this checkout's own databases. Use /usr/bin/rm, not rm.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress bb-axu.2 "<milestone; next step>"` at milestones; warnings never block work.

## Done when
- Every bb-axu.2 acceptance item holds with test evidence; a browser check on a scratch repo switched to files (a hand edit appearing within 2 s, a malformed file showing its error on Settings) with screenshots looked at; mix precommit green.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/fm-reader.md: what changed, the reader lifecycle, evidence, review findings per axis, final gate output. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report bb-axu.2 --path docs/sessions/fm-reader.md`. Then print FM-READER DONE alone on the last line.
