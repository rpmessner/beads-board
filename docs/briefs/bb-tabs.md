You are a build session in beads-board (~/dev/utils/bb-tabs, a git worktree on branch `bb-tabs`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The ticket sheet's sections (Overview, Stage history, Sessions, Agent notes) become tabs instead of a row of jump links, showing one section at a time, so the sheet stays short as sections are added (a devserve preview section is coming). The user asked for this after using the installed board.

## Read first
- AGENTS.md (app house rules at the top: status-only copy, human times, Board.Fsm for stateful UI).
- bead bb-c2w.16; the ticket detail component and how InitiativesLive and PullRequestsLive load, refresh and close it; docs/sessions/bb-sheet.md and docs/sessions/bb-filters.md (URL state conventions).
- Fluxon's tabs component in deps/fluxon (use it if it fits; otherwise say why).

## Tickets
bb-c2w.16. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: tab selection from params (valid, unknown, missing), the URL patch on tab change keeping the open ticket and the page's filters, hidden-tab streams still updated.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 4229013b15f332694e3bd6895422066d2462d347 before printing the marker: Standards (incl. the state-machine rule: decide whether the tab is plain URL-derived state or needs a machine, and say why), Spec (bb-c2w.16 acceptance). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Active tab lives in the URL (a `tab` param beside the open ticket); default Overview; unknown values fall back to Overview. Same component on both pages.
- Tab headers are labels, optionally with counts; no explanatory copy.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. Spawn no subagents.
- The installed board runs on port 4747 as a systemd service: do not stop or touch it. Use another port and this checkout's own databases. Use /usr/bin/rm, not rm.

## Done when
- Every bb-c2w.16 acceptance item holds, shown in a browser on both pages, light and dark, narrow (about 390 px) and wide; screenshots looked at.
- mix precommit green.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/bb-tabs.md: what changed, the tab-state decision, screenshots, review findings per axis with what you fixed and left open, final gate output. Then print BB-TABS DONE alone on the last line.
