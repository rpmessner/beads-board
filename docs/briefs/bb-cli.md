You are a build session in beads-board (~/dev/utils/bb-cli, a git worktree on branch `bb-cli`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Agents keep the board current without ever being blocked by it: a localhost HTTP API plus a `board` CLI with verbs for every claimed ticket and epic event, board-side epic links, and an offline spool, so a pi session or the coordinator can say "dispatched", "progress", "report", "review", "commit" and the card moves.

## Read first
- AGENTS.md; docs/spec.md Decisions 3, 7, 8, 11 and acceptance checks 4, 5; docs/design.md section 8 (agent tools, commands per workflow step); bead bb-c2w.7 and its notes (attach/detach verbs).
- lib/board/overlay*.ex (apply_event, allowed_events), lib/board/stage.ex, lib/board/epic.ex, lib/board/events.ex, lib/board/role.ex, config/runtime.exs; docs/sessions/bb-init.md and bb-sheet.md.

## Tickets
bb-c2w.7. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: the API (auth, claimed events only, 200 with stage and effects, 409 with stage and allowed events, 404 after one forced sync), the CLI (repo from id prefix, drafts by slug and cwd or --project, --json, exit codes), the spool (app down: row in spooled_events, exit 0; Postgres down too: warning, exit 0; replay on boot exactly once, in order), attach/detach.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against c41cd42b25dd7e193b4366eef7bcb4216f235acc before printing the marker: Standards (house baseline: workflow and spool lifecycle on Board.Fsm), Spec (bb-c2w.7 acceptance and notes), Risk (auth, a public API and CLI contract the skills wiring depends on, never failing an agent). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- API on the web role at /api; bearer token read from a file under ~/.ssh (path from an env var with a documented default; the app never writes into ~/.ssh: if the file is missing, the API refuses and the CLI spools; document how the user creates the token file with mode 600). Observed events (bead_*, cr_*) are not accepted from the API.
- The CLI is an escript built from this repo, installed by the user to ~/.local/bin/board (document; do not install). Verbs: dispatch, progress, report, review, changes (request_changes), commit, abandon, revive for tickets; epic create, spec, approve, ticket, abandon, revive for drafts and epics; attach and detach (board-side epic links); show and ls. --actor defaults from BOARD_ACTOR, --session from BOARD_SESSION.
- Never fail an agent: any error other than an out-of-order claim (exit 3) exits 0 with a one-line warning; the spool is a Postgres table the CLI writes directly when the API is unreachable, replayed by the worker on boot and periodically.
- Each CLI write pings a sync of that repo.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree; do not write to ~/.ssh, ~/.local or ~/.config. A dev server runs on port 4747 from the main checkout; use another port and the test database for your runs. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; API and CLI tests for every acceptance item; an end-to-end run against a dev server on another port: dispatch, progress, report, review, commit on a scratch ticket, the card moving in the browser (screenshot), an out-of-order claim refused with exit 3, the app stopped then a spooled event replayed on start.
- Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-cli.md: what changed, the API and CLI contract (every verb with an example), token setup steps for the user, evidence, review findings per axis, final gate output. Then print BB-CLI DONE alone on the last line.
