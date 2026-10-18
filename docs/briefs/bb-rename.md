You are a build session in beads-board (~/dev/utils/bb-rename, a git worktree on branch `bb-rename`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Rename the app from beads-board to foreman throughout the code, as one mechanical slice with no behaviour change. The user renamed the GitHub repo to rpmessner/foreman. The coordinator will move the checkout folder, the installed services, the database and the skills repo afterwards; this session changes only this repository's files.

## Read first
- AGENTS.md; ticket bb-c2w.17 (read from `git show main:.beads/issues.jsonl` if needed); README.md (install and update steps); deploy/systemd/; the CLI docs (docs/sessions/bb-cli.md) for env vars.

## Tickets
bb-c2w.17 (the code part). The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd`: none for the rename itself (mechanical); the existing suite is the check. Add a test only where behaviour around names is asserted (config dir default, env var names).
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 0d5e57dfc93d0aaf6d40e0963dfc1071f3c85742 before printing the marker: Standards and Spec (completeness of the rename: grep shows no stale beads-board / Board. / BOARD_ / board_ names except where listed below). Run the axes one after another; spawn no subagents.

## Decisions already made
- OTP app `:foreman`; modules `Foreman.*` and `ForemanWeb.*` (the Fsm DSL becomes `Foreman.Fsm`); release `foreman`; escript and CLI command `foreman`; env vars `FOREMAN_*` (FOREMAN_ROLE, FOREMAN_TOKEN_FILE, FOREMAN_URL, FOREMAN_ACTOR, FOREMAN_SESSION, FOREMAN_CONFIG_DIR, FOREMAN_DISCOVERY_ROOT, FOREMAN_DATABASE_URL, ...); config dir default ~/.config/foreman; config files foreman.toml and foreman.local.toml; systemd units foreman-web and foreman-worker; release path ~/.local/lib/foreman; dev/test database names foreman_dev and foreman_test_<checkout dir>; the ticket write lock name inside the git dir becomes .foreman-write-lock.
- Page title, header and favicon alt read foreman.
- Unchanged: ticket ids and their bb- prefix, the beads repo prefix, historical session reports and briefs under docs/ (they record what was true then; do not rewrite them), migrations already applied (do not edit old migration files; table names stay as they are), the GitHub repo URL is now rpmessner/foreman.
- Generated machine diagrams regenerate under their new module names.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. Spawn no subagents.
- Do not touch the installed services, ~/.config, ~/.local, ~/.zshenv.local or the database `beads_board`; the coordinator migrates those. Use /usr/bin/rm, not rm.

## Build loop
Use `bash ~/dev/utils/skills/skills/board/scripts/board-send progress bb-c2w.17 "<milestone; next step>"` at milestones; warnings never block work.

## Done when
- mix precommit green with the same test count as main (5 properties, 354 tests) and zero warnings.
- A grep summary in the report showing what old names remain and why each is allowed.
- The release builds (`MIX_ENV=prod mix release`) as `foreman`, and `mix escript.build` produces `foreman`.
- The README install/update/uninstall steps use the new names, plus a short "Migrating from beads-board" section listing the steps the coordinator will run (stop old units, rename database, move config, install new units).
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/bb-rename.md: what changed, the grep summary, gate output. Use `bash ~/dev/utils/skills/skills/board/scripts/board-send report bb-c2w.17 --path docs/sessions/bb-rename.md`. Then print BB-RENAME DONE alone on the last line.
