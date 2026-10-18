You are a build session in beads-board (~/dev/utils/bb-views, a git worktree on branch `bb-views`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Initiatives filters as a curated set of view buttons (Open, In flight, Stale, All) with search visible and the full filters in a normally closed advanced section, so the common views are one click and the page stays calm.

## Read first
- AGENTS.md; docs/spec.md Decisions 4 and 13; lib/board/initiatives.ex and lib/board/initiatives/filters.ex, filter_restore.ex; lib/board_web/live/initiatives_live.ex; lib/board/config*.ex and priv/board.defaults.toml (how columns are defined, validated and reloaded); docs/sessions/bb-filters.md.

## Tickets
bb-c2w.13. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: view presets in config (defaults, TOML curation, validation errors keep the last good config), view selection and URL params, advanced section disclosure and its remembered state, the active-advanced-filter count, backward compatibility of old query params.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against dbaa1ad9158cbf6601e80eb2b3a4d56e43597f70 before printing the marker: Standards (house baseline: stateful UI on Board.Fsm; no explanatory copy), Spec (bb-c2w.13 acceptance), Risk (a config contract change, existing links). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Views are named presets in config, [[views]] with a key, a title and filter values (beads statuses, ticket stages, stale); shipped defaults are Open (default), In flight, Stale, All, in that order; the user curates them in board.toml. Config may name stages and statuses, never invent them.
- Buttons use Fluxon's button group look from the existing shell; the active view is clearly selected in light and dark. Search stays a visible input beside the buttons. The project comes from the sidebar.
- Advanced filters (beads status, type, label) sit in a collapsed "Filters" section; closed by default; when filters are active and it is closed, its header shows the count.
- URL: ?view=<key> plus the existing params; precedence and restore-on-return as in bb-filters.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. A dev server runs on port 4747 from the main checkout; use another port if you start one. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; LiveView and config tests for each acceptance item; screenshots light and dark of the default view and of the open advanced section, looked at and clean.
- Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-views.md: what changed, the views config shape, screenshots, review findings per axis, final gate output. Then print BB-VIEWS DONE alone on the last line.
