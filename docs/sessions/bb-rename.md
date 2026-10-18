# bb-c2w.17: repository rename to foreman

## Changed

- OTP app/release/escript: `foreman`; modules: `Foreman.*` and `ForemanWeb.*`.
- Renamed source/test directories, Mix tasks, asset profiles and colocated-hook import.
- App-specific environment variables now use `FOREMAN_*`. Standard `DATABASE_URL`, `PG*`, Phoenix and release variables retain their existing names.
- Config defaults to `~/.config/foreman`, reading `foreman.toml` and `foreman.local.toml` over `priv/foreman.defaults.toml`. The `[board]` settings table is unchanged.
- Service templates are `foreman-web` and `foreman-worker`; release installation uses `~/.local/lib/foreman`. Development uses `foreman_dev`; tests used `foreman_test_bb-rename`. Acceptance database names also use the new prefix.
- Ticket write lock is `.foreman-write-lock`. Notification, advisory-lock, guardian socket, telemetry, cookie and browser-storage namespaces use the new identity.
- Page title, header and favicon accessible name read `foreman`.
- Updated active docs, examples and acceptance tools. Regenerated all machine diagrams, including `filter_restore.md`.
- README install/update/uninstall commands use the new names and link to `rpmessner/foreman`. It includes current CLI configuration and a host migration checklist.
- Extended existing config assertions for the runtime default and environment overrides. Added release-smoke assertions for title/header/favicon names. No new ExUnit cases; no business-logic changes.

No commits, pushes, bd commands, installed-service changes, user-config changes or production database changes were performed. The pre-existing `docs/briefs/bb-rename.md` was left untouched.

## Verification

Final gates all exited 0:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 957369, max_cases: 16
Finished in 37.7 seconds (3.1s async, 34.6s sync)
5 properties, 354 tests, 0 failures
```

Zero warnings in the final precommit, production compile, release or escript gates. Fresh dependency preparation emitted the already-documented Oban unused-clause warning; application compilation did not.

```text
MIX_ENV=test mix foreman.fsm.docs
Generated 18 machine documents

MIX_ENV=prod mix compile --warnings-as-errors
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
Release created at _build/prod/rel/foreman

MIX_ENV=prod mix release --overwrite
Release created at _build/prod/rel/foreman

mix escript.build
Generated escript foreman with MIX_ENV=dev

_build/prod/rel/foreman/bin/foreman version
foreman 0.1.0
```

The overwrite build refreshed the packaged favicon after its accessibility label was added. The first asset attempt, before application compilation, could not resolve the generated colocated-hooks bundle. Following the README's compile-before-assets sequence passed.

```text
python3 tools/release-smoke.py
Artifacts: tmp/release-smoke-rxunrf2r
SMOKE_WEB_READY_NO_WORKERS
SMOKE_WORKER_READY_NO_ENDPOINT_OR_SECRET
SMOKE_WEB_RECEIVED_SYNC_VIA_POSTGRES
SMOKE_WEB_HTTP_200_WITH_SYNCED_REPO_AND_FOREMAN_BRANDING
SMOKE_WORKER_PORT_CLOSED
SMOKE_BOTH_SIGTERM_EXIT_0
SMOKE_DATABASE_DROPPED
```

The smoke test created and dropped its own disposable database, used synthetic exports and checkout-local config, and never opened a real beads store. Logs remain in ignored `tmp/rename/` and the smoke directory above. `git diff --check` passed. Existing migrations, historical reports/briefs and `.beads` files have no diff against the base.

## Old-name grep summary

Searched tracked and nonignored files for `beads-board|Board\.|BOARD_|board_`, before writing this report. No unexpected matches:

| Remaining category | Matching lines / files | Why retained |
| --- | --- | --- |
| `.beads/` | 23 / 2 | Existing issue/history records and repository identity; not edited by this build session. |
| `docs/sessions/` | 129 / 17 | Historical reports retain the names used at the time. |
| `docs/briefs/` | 64 / 19 | Historical briefs and the supplied rename brief. |
| `docs/acceptance/` | 23 / 10 | Captured historical acceptance evidence, not active code. |
| `priv/repo/migrations/` | 11 / 9 | Applied migrations are immutable, including their old module names. |
| `board_config` references | 36 / 22 | Existing SQL table name, intentionally unchanged in code, tests and fixtures. |
| README migration section | 5 / 1 | Names the old installation so the coordinator can migrate it. |

This report also names old identifiers to document the rename. A broader search across `lib`, `test`, `config`, `assets`, `deploy`, `tools`, `mix.exs` and `.gitignore` for old app/module/environment/config/CLI/release/lock names returned no matches. Generic board terminology, the `[board]` config key, UI `bb-` CSS classes and ticket IDs are not app-name leftovers.

## Standards review

Reviewed first, in-process, against `0d5e57dfc93d0aaf6d40e0963dfc1071f3c85742`, including all renamed/untracked files. HEAD is that base; there are no intervening commits. Applied AGENTS.md and the house standards baseline. A normalized file-by-file comparison found identity substitutions and formatter wrapping, plus the requested documentation, accessibility metadata and name assertions. No machine transitions, effects, dependency changes, query structure or UI layout changes.

No findings. Rechecked the final config and smoke assertions after adding them. Declined to judge pre-existing architecture and feature-documentation debt unrelated to this rename. Verdict: Ready.

## Spec review

Reviewed second against the ticket and supplied build instructions. All repository requirements are covered, including unchanged suite count, regenerated diagrams, release/escript names, README migration instructions and zero unexpected grep matches. No missing source files in the old-to-new path mapping.

No open findings. Declined to judge host migration and external skills changes, which belong to the coordinator. Verdict: Ready for repository integration.

## Coordinator cutover / not verified

The installed checkout, services, database, config and external skills still need migration. README lists the sequence. Do not run old and new workers simultaneously: their lock/notification namespaces differ. Persisted Oban rows retain worker module strings; inspect/drain old jobs or remap their worker names while stopped before replay. Reconcile in-flight merge jobs as part of that inspection. Browser sessions and saved filter preferences may reset with the namespace change.

Verify installed stage/session/history counts before and after the database rename, service recovery and CLI delivery. This build did not perform or claim those host checks.
