---
id: fm-3c3.7
title: "Session panes start with the user's login environment, not the service's"
type: bug
status: closed
priority: 2
parent: fm-3c3
blocked_by: []
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-19
closed: 2026-10-19
close_reason: "merged 6c99dc21c62b8efecc5eb77b041bc7265eb8e10c; precommit 587/0; scratch pane transcript (CLI/mix on PATH, scrubbed env, shell after exit, window name, 13 refusal messages); deployed 20261019T040027"
---

Panes foreman starts (the coordinator via `foreman coordinator`, board-launched planning sessions) inherit the foreman-web service environment: the release's `bin/` and `erts/bin` come first on PATH, so `foreman` runs the release launcher instead of the CLI escript and `escript` fails to boot (writing `erl_crash.dump` into the cwd); asdf shims are missing, so `mix`/`escript` are not found; service variables (`FOREMAN_DATABASE_URL`, `RELEASE_*`) leak into Claude and everything it launches (pi build windows included).

## Fix
- Claude panes get the user's login environment: the same PATH and variables a new window of the user's tmux config gets, no service-only variables. Builder picks the mechanism (tmux global environment, a login shell wrapper, an explicit env scrub); it must hold for respawn-pane (coordinator) and new-window/new-session (planning sessions).
- When Claude exits, the pane drops to the user's shell (`$SHELL`), not `/bin/sh`.
- The coordinator's window keeps the layout's name (`coordinator`); foreman does not rename it.
- CLI refusal output is a plain sentence, e.g. `Coordinator not launched: claude is not on the foreman service PATH`, not an inspected tuple; same for other `foreman coordinator` refusals.

## Acceptance
- In a launched pane on a scratch tmux server started like `foreman-tmux`: `command -v foreman` is `~/.local/bin/foreman`, `command -v mix` resolves via asdf, `env` has no `FOREMAN_DATABASE_URL`, `RELEASE_*`, `PHX_*` or release paths; `foreman ls --json` works there.
- Exiting the stub claude leaves the user's shell running in the pane.
- Window name unchanged after `foreman coordinator`.
- Each refusal reason prints a readable message and exits non-zero.
- `mix precommit` green.
