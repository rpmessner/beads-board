You are a build session in foreman (~/dev/utils/fm-pane-env, branch fm-pane-env, a worktree of ~/dev/utils/foreman). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Panes foreman starts (the coordinator through `foreman coordinator`, board-launched planning sessions) run with the user's login environment instead of foreman-web's, fall back to the user's shell when Claude exits, keep the coordinator window's name, and `foreman coordinator` refusals print plain sentences. Full scope and acceptance: ticket fm-3c3.7.

## Read first
AGENTS.md; `foreman show fm-3c3.7`; docs/coordinator.md; docs/sessions/fm-coordinator.md (the slice that introduced respawn-pane); lib/foreman/session_tmux.ex (wrapper/2, respawn_coordinator, create, cmd), lib/foreman/coordinator_cli.ex, lib/foreman/cli_transport.ex. Live evidence of the bug: in the current coordinator pane, PATH starts with `~/.local/lib/foreman/releases/<rid>/erts-*/bin` and `.../bin`, has no `~/.asdf/shims`, and `FOREMAN_DATABASE_URL` is set; the foreman-tmux server's own global environment (`tmux -L foreman show-environment -g`) is clean, so the leak comes from the tmux client foreman-web runs.

## Tickets
fm-3c3.7 (ticket files). Start with `foreman update fm-3c3.7 --status in_progress`. The coordinator files new tickets and closes this one; report new work instead of filing it. fm-3c3.8 (epic coordinator) is blocked on this one; do not start it.

## Skills
- `tdd` at these seams: SessionTmux wrapper/command construction (env handling, exit fallback, rename behaviour) and the CLI refusal formatting; one end-to-end check on a scratch tmux server started the way foreman-tmux starts (`tmux -D -L <scratch>` from a clean env) with a stub claude that dumps `env` and argv.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 9a71080 before printing the marker: Standards, Spec (fm-3c3.7), and Risk (it changes how every launched session starts). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding, then re-run the gate.

## Decisions already made
- The pane gets what a new window of the user's own tmux config would get; no service-only variables (`FOREMAN_DATABASE_URL`, `RELEASE_*`, `PHX_*`, `SECRET_KEY_BASE`, release/erts paths). The hooks Claude runs still reach foreman: they carry their token file and URL explicitly already; keep that working.
- Do not change the user's tmux config, dotfiles, systemd units or ~/.config/foreman; the fix lives in foreman's code.
- UI/CLI copy: plain sentences, no taglines.

## Rules
No commits, pushes, deploys or release installs. Do not touch the live `-L foreman` server, its `coordinator` session, the installed release or ~/.config/foreman. Never launch a real `claude` (stub it). Stay inside this worktree.

## Browser checks
None needed unless you change UI; if you do: For a registered app, use the `devserve` skill. In this worktree run `FOREMAN_SESSION=fm-pane-env devserve up` for browser checks and use the printed URL. Confirm `devserve ls --json` shows this worktree with owner `fm-pane-env`; report its unit, URL, database, and browser evidence. If startup or ownership verification fails, report the blocker rather than improvising a server. Leave preview cleanup to coordinator close-out.

## Build loop
Use the `foreman` skill's best-effort sender for `foreman progress fm-3c3.7 "<milestone; next step>"` at milestones; warnings never block work.
For a build-time question you cannot answer, run `foreman ask decision fm-3c3.7 --question "<question>" --option "<A>" --option "<B>" --recommendation "<A>"` directly, then `foreman wait <returned-request-id> --timeout 7200` in your shell, not through the sender and not as a question in this pane. Follow the `foreman` skill's approval outcomes: resume only with `state: answered`, using `outcome.answer` and `note`; exit 0 alone is not an answer. Keep the ID and re-wait after a timeout. Report an unavailable inbox as a blocker rather than guessing.

## Done when
Every fm-3c3.7 acceptance item holds with evidence (scratch-server transcript showing `command -v foreman`, `command -v mix`, the scrubbed env, shell after exit, window name, each refusal message); `mix precommit` green with zero warnings; no `erl_crash.dump` left anywhere.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains; a pure table without its executor is not a stopping point.

## Report back
Write docs/sessions/fm-pane-env.md: what changed, evidence, review findings per axis with what you fixed and what you left open, anything else open, final gate output. Use the `foreman` skill's best-effort sender for `foreman report fm-3c3.7 --path docs/sessions/fm-pane-env.md`; warnings never block the marker. Then print FM-PANE-ENV DONE alone on the last line.
