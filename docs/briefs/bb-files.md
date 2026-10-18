You are a build session in beads-board (~/dev/utils/bb-files, a git worktree on branch `bb-files`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The ticket file format and the agent toolset that writes it: the `board` CLI creates, edits, closes and links tickets as Markdown files with YAML frontmatter in a checkout's `tickets/` folder, with no server running, and `board check` validates them. This is the foundation for replacing beads in every repo.

## Read first
- AGENTS.md (app house rules at the top); docs/specs/ticket-files.md (approved spec: Decisions 2-6 are this ticket); ticket bb-axu.1 (in the spec's epic, read from `git show main:.beads/issues.jsonl` if needed).
- The existing CLI: lib/board/cli*.ex and docs/sessions/bb-cli.md (escript, transport, never-fail rule, --json).

## Tickets
bb-axu.1. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: parse/print round trip (property test on canonical files), each `board check` rule, id generation and renumber, every CLI command against a temporary git repo with no server.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 7118b8b4ebd72fc9f4037dcecbe6593c6b65b28b before printing the marker: Standards, Spec (bb-axu.1 acceptance and spec Decisions 2-6), Risk (file writes in user repos: atomic writes, never clobbering hand edits made between read and write, canonical output stability). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Format, fields, layout, ids and command list exactly as spec Decisions 2-6. Unknown frontmatter keys are errors. Canonical print: fixed key order, sorted lists, one trailing newline.
- The ticket CLI commands write files directly and need no server; existing overlay commands (dispatch, progress, report, ...) keep their current behaviour.
- The parser/printer is a module the board's reader will reuse (next ticket), so keep it free of CLI concerns.
- No new dependency if an existing one fits (check what is already in mix.lock for YAML).

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree; tests use temporary directories, never a real repo's files. Spawn no subagents.
- The installed board runs on port 4747 as a systemd service: do not stop or touch it. Use /usr/bin/rm, not rm.

## Build loop
Use the `board` skill's best-effort sender for `board progress bb-axu.1 "<milestone; next step>"` at milestones; warnings never block work.

## Done when
- Every bb-axu.1 acceptance item holds with test evidence; mix precommit green.
- A short demo transcript in the report: in a temp repo, new epic, two children with a blocker, ready, close, check, tree, renumber, with the resulting files shown.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/bb-files.md: what changed, the format as implemented, the demo transcript, review findings per axis with what you fixed and left open, final gate output. Use the `board` skill's best-effort sender for `board report bb-axu.1 --path docs/sessions/bb-files.md`. Then print BB-FILES DONE alone on the last line.
