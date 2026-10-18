You are a build session in foreman (~/dev/utils/fm-launch, a git worktree on branch `fm-launch`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Launch planning sessions from the board: a Launch control on unplanned tickets and idea/draft epics (sheet, epic detail and epic list rows) starts a Claude Code coordinator for that ticket in a board-owned tmux server, with the opening prompt paired to the right workflow skill, and the board tracks the session. This separates planning from the user's main coordinator session, which has become a bottleneck.

## Read first
- AGENTS.md (house rules, clarified copy rule); docs/specs/session-launcher.md (approved; this ticket is Decisions 1-5, 8, 9 launch rows, 11); tickets/fm-3c3.1.md (incl. the user's note about list rows); the foreman skill (~/dev/utils/skills/skills/foreman/SKILL.md) for where prompt templates belong.
- docs/sessions/bb-cli.md (session records), bb-sheet.md, bb-tabs.md, fm-preview.md (Foreman.Preview: under PREVIEW=1 launching must be refused).

## Tickets
fm-3c3.1 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd` at these seams: launchability (unplanned tickets and idea/draft epics only); the session machine's launch/started/exited/window_gone rows; the tmux adapter against a real tmux server on a temporary socket (create project session if missing, window per ticket, focus existing instead of a second, never kill); the opening prompt per kind; refusal under PREVIEW=1.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 759d0f45a1bfc095bb5923e7a62166b0ef826881 before printing the marker: Standards (Foreman.Fsm machine; status-and-instructions copy only), Spec (fm-3c3.1 acceptance + the user note), Risk (argv quoting of prompts, a launch that half-fails, the board never killing a window). One axis after another; no subagents.

## Decisions already made
- Spec decisions as written: tmux -L foreman, one session per project key, one window per ticket id; claude with --session-id, no --model, no --permission-mode, in the project's main checkout; window stays open on a shell after Claude exits.
- Prompt templates live in the foreman skill (skills repo); put the proposed template text in your report and read them from a path the skill owns, with a built-in fallback for tests. The coordinator will commit the skill change.
- The foreman-tmux systemd unit goes in deploy/systemd with README steps; installing it is the user's approval, not yours.

## Rules
- No commits, no pushes, no ticket edits, no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman on port 4747: do not touch it, its config or database. Use another port and this checkout's own databases.
- Live check: launch a real Claude session only against a scratch ticket in a scratch repo under /tmp, on a temporary tmux socket, and kill that scratch server afterwards; never against a real project ticket, never on the user's tmux server.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-3c3.1 "<milestone; next step>"` at milestones.

## Done when
- Every fm-3c3.1 acceptance item holds (except installing the unit): tests on a temporary tmux socket; the live scratch launch shows the project session and ticket window with Claude started on the paired prompt, a second Launch focusing it, and the board showing state and attach command; browser-checked Launch on sheet, epic detail and list rows, light and dark, 390 and 1440 px, screenshots looked at; mix precommit green.
Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/fm-launch.md (changes, machine, prompts, live run, evidence, review findings per axis, final gate, the proposed skill template text, install steps for foreman-tmux). Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-3c3.1 --path docs/sessions/fm-launch.md`. Then print FM-LAUNCH DONE alone on the last line.
