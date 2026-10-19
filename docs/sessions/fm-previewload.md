# fm-previewload: fm-c2w.20

## Changed

`Foreman.Role.children/2` now disables worker children and Oban execution under
`PREVIEW=1`, unless `FOREMAN_PREVIEW_READERS=1`. The endpoint selection, Repo, and
Postgres notifier remain unchanged. A default preview serves its copied cache.

Disabling the queues as well as the scheduler prevents copied pending read jobs
from syncing repositories. Config watching, credentials, spool consumption,
session monitoring, and preview polling also stay off. No worker lifecycle or
new state machine was added: this is a static startup policy.

The opt-in restores the selected role's existing workers and queues, not just
read jobs. It respects the web-only role and runtime disablement. The existing
execution-time `PREVIEW` write guard is unchanged. README documents the flag,
restart requirement, and stale snapshot behavior.

No commits, pushes, ticket changes, bd invocations, subagents, installed-service
changes, or user configuration edits. The coordinator-owned brief is untouched.

## Verified

- Regression first failed because the preview retained `[external_reads: 4]`
  instead of disabling queues. [Assertion-level red](../acceptance/fm-previewload/red.txt).
  Initial dependency setup required `mix deps.get`; that setup failure is not
  counted as red evidence.
- The same role test passed after the fix. Supplementary coverage checks all
  roles, worker absence, notifier retention, explicit opt-in, rejected flag
  values, runtime disablement, and unchanged write refusal.
- `mix test test/foreman/role_test.exs test/foreman/push_test.exs test/foreman/merge_job_test.exs`:
  **52 tests, 0 failures**. [Output](../acceptance/fm-previewload/focused-tests.txt).
- `mix precommit`: **5 properties, 559 tests, 0 failures**.
  [Output](../acceptance/fm-previewload/precommit.txt). Tests use this checkout's
  isolated database. `git diff --check` passed.

### Live copied-cache check

Started exactly one preview with `devserve up "$PWD"`, through the existing user
registration. Devserve performed the authorized source copy; this session did not
connect to or modify the source database directly. The preview used port 4880 and
unit `devserve-foreman-fm_previewload-66021fe7b7c5.service`.

`curl -fsS http://127.0.0.1:4880/` returned the board with copied ticket `fm-c2w`.
The complete bounded `devserve logs` output retained startup and the request:
**93 lines, HTTP 200, no sync activity or application errors**. SQL SELECTs of
`repo_sync`, `beads`, and `forge_snapshots` are cache reads, not external sync.
The preview remained running through the full 62-second test gate without
additional polling output. [Live log](../acceptance/fm-previewload/live-log.txt).
Tailwind reported missing optional `watchman`, then completed its build.

`devserve down devserve-foreman-fm_previewload-66021fe7b7c5.service --drop-db`
returned `removed`; `devserve ls --json` then returned `previews: []`. Both main
units remained active. Devserve owns database-drop verification; no direct
installed-database query was used.

## Review scope

Fixed point: `cd4f443c0c294dc41c9ed39f03f1cff36d3adb10`, also HEAD.
The three-dot committed diff and commit list are empty because commits are
forbidden. Review therefore covers the requested uncommitted implementation,
tests, README, and evidence against that fixed point. Axes ran sequentially,
without subagents.

### Standards

Ready. Reviewed AGENTS.md and the house standards baseline. The policy stays at
the existing supervision seam; no lifecycle is implemented with ad hoc state.
Environment-changing tests are synchronous and restore both environment and app
configuration. No UI, dependency, schema, or external-command changes.

Declined to judge unrelated existing runtime design. No findings.

### Spec

Ready. Default previews have neither readers nor queued read execution; the
copied board remains available. Opt-in restores existing worker behavior while
write refusal remains active. Disabling all worker execution is deliberate:
it keeps copied jobs and spool events from changing the snapshot, rather than
merely stopping future scheduling. No ticket or installed configuration changes.

Declined to judge live external-reader opt-in against real repositories: enabling
that would recreate the load this task removes. The startup opt-in and write
policy are covered by executable tests. No findings.

### Risk

Ready. The safety fact is that preview suppression changes only worker startup
and execution, not endpoint selection, cache persistence, or the write guard.
Proof level 4: the 52-test focused run exercises the production role function and
existing write jobs. Proof level 5: the real devserve copy served cached tickets
without sync output. Existing non-preview role tests pass unchanged.

Normal workers still receive their configured queues. A web role cannot acquire
workers through the opt-in. Queues, plugins, and peer leadership are disabled
together, using the existing web-role Oban configuration rather than introducing
a second execution mechanism. The notifier remains available.

Expected limitation: a default preview does not refresh sync/session status or
consume spool events. The documented opt-in restores the full worker set and
can again impose repository load. This is not an OS sandbox: explicit direct
calls to reader modules are outside the startup policy.

Declined to judge hostile environment changes and future workers bypassing the
role seam. Cheapest pre-merge check: `mix test test/foreman/role_test.exs`.
No findings.

Review summary: Standards 0, Spec 0, Risk 0 open findings.

## Not verified

No browser screenshot or connected-LiveView interaction was run; there are no UI
changes. Live acceptance checked the actual HTTP board and copied ticket data.
Live opt-in against external repositories was intentionally not run. Coordinator
owns integration and ticket closure.
