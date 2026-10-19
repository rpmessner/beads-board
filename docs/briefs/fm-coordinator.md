You are a build session in foreman (~/dev/utils/fm-coordinator, branch fm-coordinator, a worktree of ~/dev/utils/foreman). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Make the user's coordinator a board-tracked Claude session: a `foreman coordinator` command run in a tmux pane resumes the recorded coordinator conversation (or starts and records a new one), sends the orient prompt, and the board shows it with Focus/Relaunch and routes its waits to Needs you. Full scope and acceptance: ticket fm-3c3.6.

## Read first
AGENTS.md; `foreman show fm-3c3.6`; the session launcher epic fm-3c3 (`foreman show fm-3c3`) and its closed slices fm-3c3.1, .2, .4; lib/foreman/sessions.ex, planning_session.ex, session_tmux.ex, session_hooks.ex, session_prompt.ex, session_machine.ex, session_monitor.ex, cli.ex.

## Tickets
fm-3c3.6 (ticket files in this repo). Start with `foreman update fm-3c3.6 --status in_progress`. The coordinator files new tickets and closes this one; report new work instead of filing it.

## Skills
- `tdd` at these seams: the session machine (pure step), Sessions context functions for the coordinator (resume vs fresh vs adopt, never parked), the CLI command's argv-to-launch decision, LiveView for the board's coordinator controls.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 3505996 before printing the marker: Standards and Spec axes (Spec = fm-3c3.6), plus Risk (this touches persistence and the CLI). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding, then re-run the gate.

## Decisions already made
- The orient prompt only invokes the `orient` skill (being built in the skills repo in parallel as sk-dnl); send `/orient` or the equivalent skill invocation; do not inline its content.
- Resume by default; `--fresh` starts a new conversation; there is exactly one coordinator, not per project or ticket.
- The coordinator is never parked by idle time.
- airmux layout and the `coord` shell command (which starts systemd units and runs airmux on `tmux -L foreman`) are done by the coordinator in dotfiles. You only build the foreman side.
- State mechanics go through the house FSM DSL (extend the session machine rather than ad-hoc state).
- UI copy: labels and instructions are fine; no taglines.

## Rules
No commits, pushes, deploys or release installs. Do not touch the live tmux server `-L foreman`, the live `coordinator` session, the installed release, ~/.config/foreman, or anything outside this worktree. Use a scratch tmux socket and scratch config for end-to-end checks; never launch a real `claude` against the user's account in tests (stub the executable).

## Browser checks
For a registered app, use the `devserve` skill. In this worktree run `FOREMAN_SESSION=fm-coordinator devserve up` for browser checks and use the printed URL. Confirm `devserve ls --json` shows this worktree with owner `fm-coordinator`; report its unit, URL, database, and browser evidence. If startup or ownership verification fails, report the blocker rather than improvising a server. Leave preview cleanup to coordinator close-out.

## Build loop
Use the `foreman` skill's best-effort sender for `foreman progress fm-3c3.6 "<milestone; next step>"` at milestones; warnings never block work.
For a build-time question you cannot answer, run `foreman ask decision fm-3c3.6 --question "<question>" --option "<A>" --option "<B>" --recommendation "<A>"` directly, then `foreman wait <returned-request-id> --timeout 7200` in your shell, not through the sender and not as a question in this pane. Follow the `foreman` skill's approval outcomes: resume only with `state: answered`, using `outcome.answer` and `note`; exit 0 alone is not an answer. Keep the ID and re-wait after a timeout. Report an unavailable inbox as a blocker rather than guessing.

## Done when
Every acceptance item in fm-3c3.6 holds with evidence (scratch tmux socket transcript for resume/fresh/adopt using a stub claude that prints its argv; Needs-you entry for a coordinator wait; board screenshot light and dark showing the coordinator controls); `mix precommit` green with zero warnings.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains; a pure table without its executor is not a stopping point.

## Report back
Write docs/sessions/fm-coordinator.md: what changed, evidence, review findings per axis with what you fixed and what you left open, anything else open, final gate output. Use the `foreman` skill's best-effort sender for `foreman report fm-3c3.6 --path docs/sessions/fm-coordinator.md`; warnings never block the marker. Then print FM-COORDINATOR DONE alone on the last line.
