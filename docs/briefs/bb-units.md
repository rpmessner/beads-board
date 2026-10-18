You are a build session in beads-board (~/dev/utils/bb-units, a git worktree on branch `bb-units`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The board runs whenever agents do, without anyone keeping a terminal open: one mix release, run as two systemd user units, beads-board-web (endpoint) and beads-board-worker (Oban queues, beads reader and scheduler, config watcher), restarted on failure and started at login.

## Read first
- AGENTS.md; docs/spec.md Decision 1 (deployment); README (roles, config, setup); lib/board/role.ex, config/runtime.exs; docs/sessions/bb-exec.md and bb-sync.md (roles and the split-deployment proof).

## Tickets
bb-c2w.10. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: runtime config per role in prod (web needs its secret, worker does not), release boot per role (a release smoke test that starts each role and checks what it runs).
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 8239605a7646da3b214cb8198814748685eaa16a before printing the marker: Standards, Spec (bb-c2w.10 acceptance), Risk (secrets and environment handling, restart behaviour, shutdown ordering). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- One release; BOARD_ROLE selects web, worker or all; two user units with Restart=always, journald logs, WantedBy default.target.
- Environment: the units read an untracked environment file (for example under ~/.config/beads-board/) that the user creates: DATABASE_URL, SECRET_KEY_BASE (web only), the Fluxon variables are build-time only, the API token comes later (ticket .7) from ~/.ssh. Ship an example env file with placeholders only, never real values.
- Postgres stays the host's own service; the units order after it if it is a system unit the user session can see, otherwise they retry on their own (Restart=always covers it).
- Do not install anything: write the unit files and an install/update/uninstall section in the README (commands the user runs: copy units to ~/.config/systemd/user/, daemon-reload, enable --now, journalctl --user -u ...). You may build and run the release locally from the worktree for the smoke test, on non-default ports and the test database, and stop it afterwards.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. Do not write to ~/.config, ~/.local or systemd, and do not enable or start units. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; mix release builds; a smoke test starts the web role and the worker role from the release as separate OS processes, shows web serving and worker syncing with no endpoint, then stops both cleanly.
- Unit files and example env file in the repo; README install, update, logs and uninstall steps; systemd-analyze verify (user mode) passes on the unit files if available.
- Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-units.md: what changed, the unit files, the install steps the user will run, smoke-test evidence, review findings per axis, final gate output. Then print BB-UNITS DONE alone on the last line.
