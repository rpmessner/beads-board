# fm-3c3.7 pane environment

## Changed

- `SessionTmux` clears the service client's environment before calling tmux. The server/session environment supplies the baseline; an interactive login `$SHELL` initializes the pane. The wrapper removes `FOREMAN_DATABASE_URL`, `RELEASE_*`, `PHX_*` and `SECRET_KEY_BASE` before Claude and returns to `$SHELL` after exit.
- Coordinator respawns disable automatic renaming before replacing the pane. Invalid working directories and tmux failures retain distinct, serializable refusal reasons.
- Hooks resolve `foreman` on the initialized pane PATH; their explicit URL and token configuration remains intact.
- Coordinator CLI refusals are plain sentences with exit status 1. Transport responses retain the error code alongside the existing warning.

## Sequential self-review against 9a71080

The review includes uncommitted changes, as requested. HEAD is still `9a710801353aec2c37512615ec50c9c16ab7bfec`; no commits were made.

### Standards

One Important finding, fixed: the first pane regression depended on installed user tools. `test/foreman/pane_environment_test.exs` now uses a fixture login shell and tools by default. `FOREMAN_HOST_ACCEPTANCE=1` opts into the real user environment. Both modes run `foreman ls` against a scratch Git repository with a local ticket, not the live board. Both passed after the change.

Reviewed against local `AGENTS.md` and the house baseline. Startup remains adapter plumbing under the existing session machine; no new lifecycle states or bypassed transitions. No open Standards findings. Declined: UI review (no UI changes), changing user shell configuration (forbidden). Verdict: Ready.

### Spec

One Important evidence gap, fixed: the old integration test hand-built a hook command. It now executes the StopFailure hook from the actual `--settings` payload, with deliberately wrong ambient URL/token settings. The hook reaches the isolated HTTP endpoint and produces the expected Needs you request; Continue still reaches the stub Claude. The two coordinator integration tests passed.

Checked every fm-3c3.7 requirement: new-session, new-window and respawn startup; user PATH and shell; scrubbed environment; preserved coordinator window name; all refusal messages and nonzero exits. No open Spec findings. Declined: fm-3c3.8, real Claude and live-server deployment (outside scope or forbidden). Verdict: Ready.

### Risk

One Important regression, reproduced and fixed: clearing the tmux client environment caused `new-session` to mask the server's `SSH_AUTH_SOCK` and `DISPLAY`. `SessionTmux.open_window/4` now uses `new-session -E`. The regression failed on the missing socket before the change and now verifies both values across new-session, new-window and respawn.

The safety fact is that tmux retains its clean server/session environment while excluding the service client's PATH and variables. Proof level 4: the scratch-server test drives the shipped adapter with a polluted client and asserts both exclusion and preservation. The broader risk run passed **47 tests**, covering session lifecycle, parking, focus, resume, prompt quoting, hooks, transport and coordinator CLI.

Other fixes made during implementation: preserve `invalid_launch_target` instead of reporting missing Claude; normalize coordinator tmux failures so the HTTP response is serializable; resolve hook executables in the pane rather than the release; wait for actual startup states in existing timing-sensitive tests. Each production fix has failing-first coverage.

No open Critical or Important findings. Declined: guaranteeing arbitrary user startup scripts, non-POSIX shell syntax, real Claude behavior or atomic tmux/Postgres recovery; this change retains the existing shell-script and transaction boundaries. Login startup can take longer than the former non-login wrapper. Cheapest pre-merge check: the pane environment test plus coordinator integration test. Verdict: Ready.

## Evidence and final gate

- Failing-first checks reproduced the polluted PATH, inspected refusal tuples, release-bound hook executable, masked working-directory error, non-serializable tmux error, startup-only service variables, and lost server environment values. Mutation checks also failed when pre-respawn rename protection was removed and when `/bin/sh` replaced the user's fallback shell. All mutations were restored.
- `FOREMAN_HOST_ACCEPTANCE=1 mix test test/foreman/pane_environment_test.exs` passed. The [scratch transcript](../acceptance/fm-pane-env/pane-transcript.txt) shows `foreman` at `~/.local/bin/foreman`, `mix` at `~/.asdf/shims/mix`, successful offline `foreman ls --json`, stub argv, scrubbed environment names, `zsh` after exit, and the unchanged window name. Environment values are withheld.
- The [coordinator transcript](../acceptance/fm-pane-env/coordinator-transcript.txt) covers the built CLI through an isolated HTTP endpoint and scratch tmux, including resume, fresh, adopt and unchanged window name.
- The built escript returned exit status 1 for [all 13 refusal cases](../acceptance/fm-pane-env/refusals.txt). The CLI tests retain sentence assertions for those cases.
- [Risk checks](../acceptance/fm-pane-env/risk-tests.txt): 47 tests passed.
- Final gate: `mix precommit --max-cases 1` passed with zero warnings, **5 properties, 587 tests, 0 failures**. [Full output](../acceptance/fm-pane-env/precommit.txt). No tests were excluded. `foreman check` and `git diff --check` passed. A worktree-wide search found no `erl_crash.dump`.

## Open and unverified

Default-concurrency `mix precommit` passed earlier, but later runs hit intermittent `{:error, :invalid}` token verification in unrelated Initiatives and Pull Requests LiveView tests. A failing test passed alone without code changes; the final full suite passed with one test case at a time. The signature matches the issue in `docs/known-issues.md`, but clock rollback was not independently measured here. No signing behavior or tests outside the session changes were altered. The coordinator can follow up on this existing suite instability.

No UI changed, so no browser or preview was needed. No real Claude ran. The live tmux server, installed release and user configuration were not modified. No commits, pushes or deployments were made. The host acceptance invokes the installed CLI read-only against a local fixture. Login-shell startup itself remains user-controlled; the post-Claude shell reads the user's ordinary startup files again.

fm-3c3.7 remains `in_progress` for coordinator verification and closure. fm-3c3.8 was not started. The pre-existing dispatch brief was left untouched.
