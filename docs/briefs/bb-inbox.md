You are a build session in beads-board (~/dev/utils/bb-inbox, a git worktree on branch `bb-inbox`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The backbone of the approvals inbox, proven with the one request kind that writes nothing external: a build session asks a question with `board ask decision`, it waits on a new Needs you page, the user answers or declines there, and the asker's `board wait` receives the outcome.

## Read first
- AGENTS.md (app house rules at the top: status-only copy, human times, Board.Fsm machines); docs/specs/approvals-inbox.md (approved spec; this ticket covers Decisions 1, 7, 8, 9 and the in-app count of 10); ticket bb-zgd.1 (read from `git show main:.beads/issues.jsonl` if needed).
- docs/sessions/bb-cli.md (CLI rules and agent API), docs/sessions/bb-merge.md (one-shot claim and audit pattern), docs/sessions/bb-tabs.md (ticket sheet tabs; the Requests tab goes there).

## Tickets
bb-zgd.1. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: the request machine (every row of spec Decision 7, invalid claimed and ignored observed events), the agent API and CLI for ask and wait, supersede on ticket abandoned or done, the page's answer and decline.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 7118b8b4ebd72fc9f4037dcecbe6593c6b65b28b before printing the marker: Standards (incl. the state-machine rule), Spec (bb-zgd.1 acceptance), Risk (the per-kind extension point later action kinds will use; waiting clients and timeouts; the CLI never failing an agent). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Request kinds, machine, CLI shape and page as in the spec. Only the decision kind is implemented here; push, open_pr and merge come in later tickets, so build the per-kind extension point (creation-time validation, a job on approve) but no action kinds.
- Needs you is the first sidebar item with a pending count badge; the tab title shows the count as `(N) beads-board`. Browser notifications are a later ticket.
- Ticket sheet gains a Requests tab beside the existing tabs.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. Spawn no subagents.
- The installed board runs on port 4747 as a systemd service: do not stop or touch it. Use another port and this checkout's own databases. Use /usr/bin/rm, not rm.

## Build loop
Use the `board` skill's best-effort sender for `board progress bb-zgd.1 "<milestone; next step>"` at milestones; warnings never block work.

## Done when
- Every bb-zgd.1 acceptance item holds; browser-checked light and dark at 390 and 1440 px with screenshots looked at; mix precommit green.
- A transcript in the report: `board ask decision` from a shell, the page answered in the browser, the waiting `board wait` printing the outcome; and a decline with a note.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/bb-inbox.md: what changed, the machine table and diagram, the transcript, screenshots, review findings per axis with what you fixed and left open, final gate output. Use the `board` skill's best-effort sender for `board report bb-zgd.1 --path docs/sessions/bb-inbox.md`. Then print BB-INBOX DONE alone on the last line.
