# bb-units: bb-c2w.10 release deployment

## Review baseline

Reviewed against `8239605a7646da3b214cb8198814748685eaa16a`. HEAD still equals
that baseline, so the committed three-dot diff and commit list are empty.
The requested uncommitted changes and new deliverables are the review input.
The coordinator's pre-existing `docs/briefs/bb-units.md` is excluded and untouched.
Axes ran sequentially in this session, without subagents.

## Standards

Reviewed the changes against both AGENTS files and the house Standards baseline.
The deployment lifecycle belongs to systemd's declared service model; no second
application lifecycle or supervisor was added. The smoke test exercises the
packaged artifact, not mocks of application modules. The synthetic exporter is
the external-process boundary and cannot open an actual beads store.

No Critical or Important finding. Existing production role selection and the
worker's secret exemption already pass; they remain unchanged. Runtime tests
now cover production web secret/port settings, default all-role secret failure,
and worker database requirements. Deliberate mutations prove the existing
worker-secret regression and the release's worker-child check fail when broken.
This is regression/mutation evidence for pre-existing behavior, not a claim that
this session implemented that behavior test-first.

Declined to judge unrelated application and UI design. Verdict: Ready for the
build deliverables, with no open Standards finding.

## Spec

Checked after Standards against Decision 1, the local exported bb-c2w.10
acceptance text, and the dispatch's explicit Done-when list. No bd command was
used to read or change the ticket.

One default Mix release supplies both user units. Both use `Restart=always`,
`WantedBy=default.target`, journald, and untracked environment files. Web has no
queues, scheduler or watcher. Worker has the runtime and watcher, with no endpoint
or signing secret. The release smoke proves fixture projection, Postgres
notification delivery to web, and an HTTP response containing the synced repo.
The earlier browser live-update proof remains in `bb-exec.md`; this session's
release smoke is not a new browser/WebSocket test.

README covers initial build, migration, install, update, logs, uninstall, login,
optional lingering, and operator checks after process death and WSL restart.
System/user managers cannot order across dependency graphs, so no misleading
`After=postgresql.service` was added. Retry is the portable path; a host-specific
user readiness unit can supply ordering if available.

No Critical or Important implementation finding. Declined to execute installed
service recovery or a WSL restart: the dispatch explicitly forbids installation
and starting units. Those host acceptance checks remain for the user/coordinator;
do not present the template verification as proof they ran. Verdict: Ready for
the requested build-only delivery, not a claim of installed-host acceptance.

## Risk

Reviewed after Spec. The safety fact is that both units execute the same packaged
foreground release with separate runtime directories and role-specific children;
the worker receives no endpoint secret and neither process uses distribution.
Proof level 5 for the release boundary: the final real-process smoke printed
all seven success markers below, including worker projection observed by web and
SIGTERM exit 0 for both processes. Unit syntax/specifier/executable checks pass
in user mode with a scratch HOME and the real release linked into the expected
layout. No host unit was installed or started.

Important documentation finding fixed in README's migration block: `unset`
masked a failed migration's exit status before the enable commands. The block
now preserves and tests that status, and installation is a separate step with an
explicit success prerequisite. The migration expression itself runs in the smoke.
No application change was needed. No open Critical or Important finding remains.

Cleared within the tested boundary:

- `web.env` is web-only; worker `UnsetEnvironment` also strips an inherited
  `SECRET_KEY_BASE`. Both units strip Fluxon variables. Examples have placeholders
  only. README requires private, untracked files and does not source them as shell.
- The smoke starts with an allowlisted environment, a random test-only web secret,
  a new disposable database, and an absolute synthetic-exporter PATH. It never
  reads the operator's environment files or runs the host's bd executable.
- RuntimeDirectory mode 0700 and UMask 0077 protect generated runtime config.
  The separate migration command also sets umask 077. Update copies an immutable
  release, stops both services, switches the symlink, migrates, then starts them.
- `Restart=always` and `StartLimitIntervalSec=0` avoid a permanently exhausted
  restart budget during a long database outage. Explicit stop remains stopped.
- `KillMode=mixed` sends initial SIGTERM only to the BEAM, not all reader children
  simultaneously. The application stops watcher/runtime before Oban and Repo;
  Oban's pinned default drain is 15 seconds. The unit allows 90 seconds before
  cgroup SIGKILL. The smoke proves clean idle shutdown, while existing reader
  tests cover subprocess cancellation and owner death.

Declined to judge installed automatic restarts, actual WSL boot/login, a forced
90-second cgroup timeout, and shutdown during a live bd write. Those require the
operator's host gate or the separate reader safety gate; no new claim is made.
Verdict: Ready within the tested build boundary. Cheapest pre-merge checks are
precommit, release smoke, and user-mode unit verification.

## What changed

- `deploy/systemd/beads-board-web.service` and
  `deploy/systemd/beads-board-worker.service`: Type=exec, foreground release,
  Restart=always every five seconds without rate limiting, journald,
  default.target, separate private runtime directories, and bounded shutdown.
- `deploy/systemd/runtime.env.example` and `web.env.example`: database/PATH/port
  placeholders and a separate web secret placeholder. No real values.
- `tools/release-smoke.py` and `tools/release-smoke.exs`: repeatable packaged-release
  checks with real Oban scheduling, watcher, Repo, HTTP and Postgres notifications.
- `test/board/runtime_config_test.exs`: three additional production config checks.
- `.gitignore`: generated digest/compression artifacts and local deployment env
  files. Example files remain visible to Git and the hygiene guard.
- README: installation, migrations, updates, logs, uninstall, smoke usage and
  host recovery checks. Production application code is unchanged.

No commits, pushes, bd commands, subagents, service installation, user-config
writes or ticket mutations. The generated fixture executable named `bd` serves
static test bytes only, as in the existing reader tests. No real store was opened.

## Steps for the user

Run the complete commands in README, in order:

1. Prepare host Postgres, systemd user support and external executables.
2. Copy the two example environment files to the untracked config location,
   mode 0600. Replace placeholders; put the secret only in the web file.
3. Build assets and one production release, copy it to a timestamped directory
   under the deployment location, and create the `current` symlink.
4. Run the release migration as worker. Continue only on success.
5. Copy both unit files to the user unit directory, run user-mode verification,
   daemon-reload, and `enable --now` for both services.
6. Check status, journald, Settings and repository sync. Test main-process death
   and a safe WSL restart. Enable lingering only if wanted for this host.

The units start at login, not while WSL is shut down. System Postgres ordering
cannot cross the user/system manager boundary; retries cover that case. The
README update path never replaces files under a running release. Uninstall
disables and removes only units, leaving data and configuration intact.

## Smoke and regression evidence

Final raw logs are in the ignored `tmp/release-smoke-hw1wv2oo/` directory.
`tmp/smoke-final.log`, `tmp/release-final.log`, and `tmp/precommit-final.log`
contain the final command output. The release was built with production config
and started through its actual `bin/board start`, twice, as separate OS processes.
A VM-args probe checked the children inside each process without enabling RPC.
The web role used an ephemeral non-default loopback port; the worker's distinct
probe port remained closed even with PHX_SERVER set in the test.

```text
SMOKE_WEB_READY_NO_WORKERS
SMOKE_WORKER_READY_NO_ENDPOINT_OR_SECRET
SMOKE_WEB_RECEIVED_SYNC_VIA_POSTGRES
SMOKE_WEB_HTTP_200_WITH_SYNCED_REPO
SMOKE_WORKER_PORT_CLOSED
SMOKE_BOTH_SIGTERM_EXIT_0
SMOKE_DATABASE_DROPPED
```

The worker read the two-record export fixture through the actual guardian and
SyncJob, and web observed the projection after the Postgres notification. Its
HTTP Settings response contained the configured fixture repository. Both release
processes stopped cleanly, and the dedicated database was dropped. No release
process remains running.

Red/green evidence for already-implemented seams:

- Temporarily requiring a secret for worker caused the focused config suite to
  fail exactly the worker-without-secret test: 6 tests, 1 failure. Restoring the
  unchanged role condition gave 6 tests, 0 failures. Evidence in
  `tmp/runtime-config-red.log`.
- Temporarily disabling worker children, rebuilding the release, and running the
  smoke failed the worker runtime PID assertion. Web had started successfully;
  cleanup stopped it and dropped the database. Evidence in `tmp/release-red.log`
  and `tmp/release-smoke-fq1nysw0/worker.log`. Restoring the original role map and
  rebuilding gave the seven markers above. Neither mutation remains in the diff.
- Initial smoke-probe failures were verifier setup issues, not product defects:
  Erlang VM-args quoting and Oban's normalization of `peer: false` to
  `{Oban.Peers.Isolated, [leader?: false]}`. The probe now asserts the observed
  normalized public config. An initial config assertion also incorrectly relied
  on keyword ordering; it now checks the port and IP independently.

## Final gates

All final commands exited 0:

```text
mix precommit
  Repository hygiene: no license material or operator paths detected
  4 properties, 127 tests, 0 failures
MIX_ENV=prod mix compile --warnings-as-errors
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release --overwrite
  Release created at _build/prod/rel/board
python3 tools/release-smoke.py
  all seven markers above
HOME="$PWD/tmp/systemd-home" systemd-analyze --user verify deploy/systemd/*.service
  no output, exit 0
mix format --check-formatted tools/release-smoke.exs test/board/runtime_config_test.exs
Python ast.parse of tools/release-smoke.py
  PASS, no bytecode generated
git diff --check
  clean
```

For unit verification only, `tmp/systemd-home/.local/lib/beads-board/current`
links to the built release. This makes `%h` and ExecStart resolve without writing
to the real home or installing units. The final application gates emitted no
warnings. Initial fresh dependency compilation emitted the already accepted
pinned Oban warning; no dependency source or warning policy changed.

Review totals: Standards has no open finding; Spec has no open implementation
finding and explicitly unrun host acceptance; Risk has one documentation finding
fixed and no open implementation finding.

Changed: deployment templates, examples, operational README and regression tools.
Verified: production build, release processes, fixture sync, HTTP, cross-process
Postgres notification, clean shutdown, precommit and unit syntax.
Not verified: installed systemd recovery, WSL restart, or a new browser live-update
session. The user must run the documented host checks before calling those ticket
acceptance items proven.
