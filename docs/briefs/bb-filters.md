You are a build session in beads-board (~/dev/utils/bb-filters, a git worktree on branch `bb-filters`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Filters on Initiatives survive navigation, and the sidebar's project list is the project filter, so the user can click a project, go to Settings and back, and still be looking at that project.

## Read first
- AGENTS.md; docs/spec.md Decision 13; the approved mockup docs/mockup/Main.dc.html; lib/board_web/live/ (Initiatives and Settings LiveViews, the layout and sidebar); lib/board/initiatives.ex; docs/sessions/bb-init.md.

## Tickets
bb-c2w.12. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: URL params to filters and back (handle_params), restoring the last filters after navigating away, sidebar click sets/clears the project and the active highlight.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against c83890d945fca3279d224f834e3444c103c969bb before printing the marker: Standards (house baseline: stateful UI on Board.Fsm machines where there are states; no explanatory copy), Spec (bb-c2w.12 acceptance), Risk (shared layout, every page). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Filters are URL query params on the Initiatives route (push_patch on change; handle_params reads them); invalid values fall back to defaults without crashing; never String.to_atom on params.
- The last filters are remembered per browser (for example in the session via a small controller hook, or localStorage restored by a hook on mount) so that returning to Initiatives without params restores them; an explicit URL always wins.
- The sidebar project links patch the project filter; the active project is highlighted with the same treatment as the active nav item in light and dark; clicking the active project clears it. The project list keeps its counts.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. A dev server is running on port 4747 from the main checkout; if you start one, use another port. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; LiveView tests for each acceptance item; screenshots (light and dark) of a filtered Initiatives page with the sidebar project highlighted, looked at and clean.
- Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-filters.md: what changed, how filters persist, screenshots, review findings per axis, final gate output. Then print BB-FILTERS DONE alone on the last line.
