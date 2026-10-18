You are a build session in beads-board (~/dev/utils/bb-sheet, a git worktree on branch `bb-sheet`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The drill-down: opening an epic shows its tickets on the configured stage columns (planned and fallout apart) with the blocking graph and the epic's own stage history; opening a ticket shows a sheet with its beads fields and everything the board knows about it. The ticket sheet is also the surface where per-ticket controls will live (preview servers next, bb-c2w.14), so build it with a clear place for actions.

## Read first
- AGENTS.md; docs/spec.md Decisions 7, 8, 13; the approved mockup docs/mockup/Epic.dc.html and Ticket.dc.html (and Main.dc.html for the shell).
- lib/board/overlay*.ex, lib/board/initiatives*.ex, lib/board/stage.ex, lib/board/epic.ex, lib/board_web/live/; docs/sessions/bb-init.md, bb-filters.md, bb-views.md.

## Tickets
bb-c2w.6. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: epic view data (columns from config, planned vs fallout, blocking edges, epic history), ticket sheet data (stage history including refused claims, sessions, notes, linked CRs, allowed next events from Board.Stage), routing and URL state (an open sheet is in the URL; closing returns to where you were with filters intact).
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 376973a55d3af07b76932bc43c79dd72a46b933d before printing the marker: Standards (house baseline: stateful UI on Board.Fsm; no explanatory copy), Spec (bb-c2w.6 acceptance, spec Decisions 7, 8, 13), Risk (routing, live updates on open views). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Epic view at its own route (e.g. /epics/:repo/:id); ticket sheet as a slide-over sheet on top of whatever page opened it (Fluxon sheet), addressable by URL (e.g. ?ticket=repo:id), so links and back/forward work and the page's filters stay as they were.
- Both update live from the existing Postgres-backed events.
- Allowed next events come from the machine (__fsm__), never hard-coded.
- Ticket sheet layout per the mockup: header (id, title, stage, beads status, type, priority), tabs or sections for overview (description, acceptance, dependencies), stage history, sessions and agent notes; an actions area in the header for per-ticket controls, empty for now (no placeholder copy; .14 fills it).
- Rows on Initiatives and cards on the epic view open the sheet; the epic title on Initiatives opens the epic view.
- On-screen text is labels, status and controls only.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. A dev server runs on port 4747 from the main checkout; use another port if you start one. Read-only bd against real repos is allowed. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; LiveView tests for both views and the URL behaviour; the epic view for bb-c2w and fe-lwp (which has fallout) and a ticket sheet for a ticket with history, screenshotted light and dark, looked at and compared with the mockup.
- Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-sheet.md: what changed, routes, screenshots, review findings per axis, final gate output. Then print BB-SHEET DONE alone on the last line.
