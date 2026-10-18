You are a build session in beads-board (~/dev/utils/bb-init, a git worktree on branch `bb-init`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The board's home: every initiative across projects and where it stands, with the work under it, the fallout it produced, and the few orphans, so the user can open the board and see beads-board's own build-out (epic bb-c2w) alongside everything else. Introduces the overlay that the stage and epic machines move.

## Read first
- AGENTS.md; docs/spec.md (authoritative: Decisions 7, 8, 13 and acceptance check 2b); docs/design.md section 5 (overlay tables).
- The approved mockup: docs/mockup/Main.dc.html (Initiatives) and Machine.dc.html.
- lib/board/fsm.ex, lib/board/stage.ex, test/support/machines/epic.ex, docs/machines/; the read model and runtime from ticket 4 (docs/sessions/bb-exec.md, bb-sync.md).

## Tickets
bb-c2w.5. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: apply_event (lock, step, record event, effects in one transaction, broadcast after commit; invalid claims logged); backfill rules; the epic tree (planned at any depth, fallout via discovered-from winning over parent-child, board-side cross-repo links, orphans, sub-epic roll-up); derived epic stages; the Initiatives LiveView.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 8239605a7646da3b214cb8198814748685eaa16a before printing the marker: Standards (house baseline: workflow, business flow and stateful UI on declared Board.Fsm machines), Spec (bb-c2w.5 acceptance, its 2026-10-17 note, spec Decisions 7, 8, 13), Risk (persistence, a public overlay contract later tickets build on). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Board.Epic moves from test fixture to the app as Board.Stage did; both machines exactly as spec Decisions 7 and 8; generated docs committed.
- Overlay tables are keyed by (repo key, bead id), never by projection foreign keys; a projection rebuild never touches them. Board-side epic links get their table now (the CLI verb is ticket .7; seed none).
- Backfill: closed beads to done, open to queued; beads epics to ticketed or done; epics never get a ticket stage; backfill recorded as events.
- Epic tree: planned = parent-child at any depth; fallout = discovered-from to anything under the epic, and it wins over parent-child; board-side links attach cross-repo tickets; sub-epics are expandable rows with rolled-up counts; the rest are orphans.
- Initiatives view per the approved mockup: drafts on top, epic rows (derived stage, progress, histogram, fallout count, open CRs placeholder until ticket .8), Unplanned collapsed by default and grouped by project, filters (project, type, label, beads status, stale). Make it the home route.
- Polish from the ticket 4 review, fix first: (1) the active sidebar item is not highlighted in light mode; (2) the Settings read-only TOML panel overflows its box (long paths run past the edge); (3) relative times show raw seconds ("2101 s ago"): use human units; (4) remove explanatory copy: the sidebar footer ("Synced via bd export / Agents take priority over freshness"), the Settings header sentence about the board never writing and Postgres, and the help lines under the repo table and columns. On-screen text is labels, status and controls only; no taglines or explanations anywhere in the app.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree; do not touch the user's home config, dotfiles or other repos. Read-only bd against real repos is allowed; any bd write only on scratch copies under /tmp/bb-init/. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; LiveView tests for Initiatives; acceptance 2b against the real repos read-only (fe-813 and fe-lwp rows with derived stages and progress matching bd; fallout shown under its epic; an orphan in Unplanned; bb-c2w visible with its children).
- Screenshots light and dark compared with the mockup and looked at; the four polish fixes visible.
- Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-init.md: what changed, the overlay schema, the epic tree rules as implemented, screenshots, review findings per axis, final gate output. Then print BB-INIT DONE alone on the last line.
