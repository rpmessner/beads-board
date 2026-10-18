# bb-exec: bb-c2w.4 runtime and Settings

## Result

The runtime and Settings acceptance checks pass. No commits, pushes, ticket
mutations, subagents, home-config changes or bd commands in this worktree.
The coordinator-owned brief is untouched. All bd writes ran on isolated copies
under `/tmp/bb-exec`; original repositories were only read while preparing copies.

Implemented:

- `SyncJob` executes the existing Read protocol through Oban. The owned subprocess
  adapter bounds time/output, cancels on owner death and reaps before returning.
- `Runtime` executes Schedule effects on nominal three-second ticks, five-minute
  sweeps and Postgres-backed pings. Physical aliases share one scheduled export.
- `ReloadJob` executes Reload, persisting accepted config, validation errors,
  discovery and a physical-store catalog in Postgres. Worker-only directory
  watching handles atomic saves, missing directories and watcher loss.
- Configured-repo health transitions use `SyncMachine`. Health changes and
  projection changes invalidate subscribers through Postgres.
- Fluxon 3.2.4, bundled theme/hooks, the app shell and Settings. Settings has
  streamed repo rows, snapshot age, store mode, read-only enabled flags, config
  sources/status/reload, columns and pasteable discovery blocks. It reconciles
  every three seconds after initial fetch, recovering missed notifications.
- Two additive migrations and reproducible scratch/browser acceptance tools.

`/` opens Settings until the initiatives ticket lands. PR navigation is labelled
“soon”, not a nonfunctional action. No release units were installed; those remain
bb-c2w.10.

## Read rule as implemented

1. Resolve the physical repo and `.beads` device/inode. Config aliases share its
   catalog identity and schedule. Recheck aliases before reading.
2. Acquire a nonblocking **Postgres** advisory transaction lock for that identity.
   Passively inspect the embedded journal through the existing JournalLock code.
   Held or indeterminate evidence defers the tick; no store lock is manipulated.
3. Execute one stdout-only `bd export`, with a 20-second deadline and 32 MB cap.
   The guardian strips inherited routing/BD/Dolt/git overrides and Fluxon values;
   it disables hooks, auto-push, backups and telemetry and confines routing.
4. The guardian owns a new process group and a Linux abstract socket keyed by
   physical identity. The socket is not a filesystem entry. It remains held until
   cleanup, closing the BEAM-death/Postgres-lock-release admission race.
5. Timeout, output overflow or port EOF kills only that owned process group.
   Linux subreaping collects descendants. `waitid(...WNOWAIT)` keeps the leader's
   PID reserved until group cleanup; cleanup is not repeated after reaping.
   Timed-out/partial output never projects, even if a late exit succeeds.
6. Before projection, lock the config row for sharing and verify each alias is
   still enabled at the same configured path. Removed/repointed results cannot
   overwrite the new configuration's projection or health.
7. Hash-skip unchanged bytes. Changed exports replace the droppable projection
   transactionally, retaining overlay facts and marking disappeared beads orphaned.
   Failures retain the last good snapshot. There is no repair, store copy, JSONL
   fallback, export-to-file or Dolt server start.

Nominal exports run even when cheap file signals would be unchanged, as required
by the probe. There is no separate redundant signal-only poller: metadata/lock
observation precedes every scheduled export. Pings and sweeps use the same
admission path; completion never starts a catch-up burst. Three seconds is the
nominal cadence, not a freshness promise under contention.

Server-mode metadata **or** a project-config mode override is rejected without
opening a server. This intentionally remains embedded-only support, including
when a server might already be available. Unsupported/ambiguous stores fail closed.

Unchanged healthy exports make no projection or health writes. Oban still writes
its own job lifecycle records. Snapshot age is labelled as such; the UI does not
pretend the persisted snapshot was rewritten on every unchanged read.

## Config contract

Unchanged precedence: shipped `priv/board.defaults.toml`, then
`~/.config/beads-board/board.toml`, then adjacent untracked `board.local.toml`.
Tables merge, columns replace, repos merge by key, and `repos = []` clears them.
Paths are absolute or home-relative. Unknown stages and bad TOML retain the last
accepted Postgres snapshot. The full example is in README.

`BOARD_CONFIG_DIR` and `BOARD_DISCOVERY_ROOT` support isolated runs; this session
used only `/tmp/bb-exec/config` and `/tmp/bb-exec/repos`. Defaults ship no repos.
Web reads Postgres, not home files or stores. Directory watches are non-recursive;
when the target is absent, the watcher moves from its existing parent as the
path appears. A 30-second reload reconciles missed notifications. Discovery
includes nested repos, skips symlinks/dependency/build/store internals and is
bounded to eight levels. The app never edits TOML.

## Acceptance evidence

Durable content-free evidence: [evidence.json](../acceptance/bb-exec/evidence.json).
Raw writer acknowledgments and worker logs remain under `/tmp/bb-exec`.

| Check | Evidence |
| --- | --- |
| 1: configured repos/counts | All seven scratch entries appear. Six embedded counts match `bd list --json --all --limit 0`; server-mode we_go_next_dev is unreachable. Counts below. |
| 2: idle note freshness | Latest post-restart verification: **0.738 seconds** from successful scratch note command to matching projected notes. Earlier clean split-role check: 1.167 seconds. |
| 2: hash skip | SQL-telemetry projection tests reject INSERT/UPDATE/DELETE on identical bytes. Runtime tests cover unchanged health recovery then no further health writes. Running worker logged 1,081 unchanged exports around the ten-minute gate. |
| Projection replacement/deletion | Live verifier created a new unlinked scratch bead, observed its projection, inserted a `building` overlay fact, deleted only that new scratch bead, then observed cache removal with the overlay still `building` and `orphaned_at` set. |
| 2a: live writer safety | **855 writes over 600.492 seconds, zero failures, no harness retries.** Create, update, note, dependency-add and close each ran 171 times. All 171 created issues, notes, dependency edges and closures were audited in the final projection. |
| 10: hot config reload | Playwright changed the scratch TOML column, observed the new column without reloading, saved an unknown stage, observed the error and retained column, then restored valid config. Each live expectation had a five-second bound. |
| Settings | LiveView test covers persisted config, discovered TOML, disabled enabled flags, reload job insertion and reconciliation of validation errors. Browser console had no page errors; 390px viewport had no page-wide overflow. |
| Split deployment | Final ten-minute gate ran independent web and worker BEAM processes. Worker printed `WORKER_ENDPOINT_AND_PEERS: {nil, []}`. Browser reload checks crossed Postgres to/from that worker. Worker log had zero errors. |
| 11: precommit half | Fresh precommit passes, including hygiene. No license material was read or copied. A fresh pinned Oban dependency build emitted the already accepted upstream warning; final application gates are warning-free. |

Latest count comparison (before that verifier's additional freshness create):

| Repo | bd | Projection |
| --- | ---: | ---: |
| beads-board | 12 | 12 |
| cooldown-o-matic | 47 | 47 |
| dotfiles | 3 | 3 |
| form-engine | 619 | 619 |
| skills | 17 | 17 |
| ui-o-matic | 417 | 417 |
| we_go_next_dev | server mode | unreachable |

The server-mode scratch entry contains copied metadata, **not** live server
PID/port files. No live server connection was attempted.

### Screenshots

[Light](../acceptance/bb-exec/settings-light.png),
[dark](../acceptance/bb-exec/settings-dark.png), and
[mobile](../acceptance/bb-exec/settings-mobile.png) were captured and inspected.
Compared with approved Settings/Main: sidebar, header, source/status panel,
repo table, column cards, fixed epic stages, discovery panel and right-hand
read-only preview follow the layout and Fluxon tokens. I fixed awkward wrapped
repo names/paths and an intermediate-theme screenshot artifact. Long paths now
elide with full titles; the table scrolls on narrow screens. Scratch paths/counts
and absent scratch remotes differ from mockup data. Demo-only controls were not
shipped. Screenshot counts precede the verifier's next scratch create.

## Review baseline and axes

Self-review against `3f0de68e528ba3ae23ec935d36ddb89ae83cc70f`, including the
explicitly requested working-tree/new deliverables. HEAD equals the baseline;
the committed three-dot diff is empty. The coordinator brief is excluded.
Axes ran Standards → Spec → Risk in this session, without subagents; fixes were
rechecked and gates rerun.

### Standards

Important findings fixed:

- `lib/board/runtime_state.ex:46`: skipping every unchanged export left deferred
  health stuck forever. Every result now steps SyncMachine; persistence skips
  only genuinely unchanged health. Regression covers recovery and no-write repeat.
- `lib/board_web/live/settings_live.ex:49`: schemaless timestamps are naive UTC;
  the first real Settings request failed in DateTime.diff. Normalize before age
  formatting; real browser requests now pass.
- `lib/board/config/watcher.ex:37`: watcher loss initially stopped outside the
  declared machine. WatchMachine now declares loss, stop and replacement effects,
  with generated golden and lifecycle tests.
- `priv/command_guardian.py:21`: owner death exposed BrokenPipe tracebacks after
  cleanup. Reply delivery now tolerates an absent owner without skipping reaping.

Read, Schedule, Reload, SyncMachine and WatchMachine are the declared workflow
skeletons. The Python guardian is the OS primitive behind the export effect;
Oban/FileSystem own their underlying supervision. UI status formatting is data
presentation, not a second workflow.

Testing limitation: command tests ran red against a stub; some adapter/UI code
preceded its integration tests. I do not claim a complete red-first trail.
Independent in-memory mutations subsequently proved that dropping projection
causes **three** integration failures, and ignoring accepted config causes
**one** failure. Nested discovery was seen fail before its fix. Final suite passes.

Declined: future view workflows and release units. Verdict: **Ready**, with no
open Critical/Important implementation finding; the testing-order limitation is
recorded rather than rewritten as TDD.

### Spec

Important findings fixed:

- `lib/board/beads/sync_job.ex:111`: late output could project after config removal
  or a path change. Shared-row-lock authorization now guards projection and health.
- `lib/board/runtime.ex:46`: the initial scheduler keyed aliases by config key.
  The persisted physical catalog now groups aliases into one schedule/export;
  tests verify a single subprocess updates both symlink aliases and one Oban job
  serves the physical group.
- `lib/board/config/reload_job.ex:76`: discovery stopped at a parent repo, missing
  nested repos. A failing integration test led to bounded traversal that excludes
  `.beads` internals but continues through ordinary children.
- Settings initially omitted store mode and load time; both now render. The TOML
  preview is accurately labelled as loaded columns/repos, not original file text.

Ruling: unconditional three-second reads supersede a separate signal-only poller;
the probe proves those signals cannot satisfy note/create freshness. No Dolt
manifest watch was added. Five-minute sweeps and Postgres pings remain explicit.

Declined: later initiatives/PR/ticket views, server-mode reading, systemd unit
installation and the day-long repo-status half of check 11. Verdict: **Ready**
for this foundation ticket; named Done-when checks have evidence above.

### Risk

The load-bearing safety fact is that only the reader's owned process group is
signalled, and physical admission survives until it is reaped. Proof level 4:
success/nonzero exit, bounded output, timeout, parent death, descendant reaping
and competing abstract-socket admission tests. Proof level 5: the unchanged
reader/scheduler artifact ran against the real scratch writer for ten minutes
with zero failed writes. Source hashes are in evidence.json.

Important findings fixed:

- `priv/command_guardian.py:30,78`: polling/reaping the leader before group cleanup,
  then repeating cleanup, could expose a PID-reuse window. WNOWAIT retains the
  PID, cleanup happens once, and subreaping collects owned descendants.
- `lib/board/beads/store.ex:22`: metadata alone missed a `dolt.mode` override in
  project config. Both must be embedded before export; regression covers the
  override. No server-start behavior is delegated to bd.
- `lib/board/config/watcher.ex:37`: file_system defaults to recursive watching.
  Watching an absent config directory's parent that way was too broad. Watches
  are now explicitly non-recursive and relocate through the machine; the
  missing-directory relocation test passes.

An earlier development run had zero writer failures but **failed** its final
count check after runtime modules were repeatedly hot-recompiled. I excluded it
from acceptance. Its stall was not root-caused; a clean restart recovered the
projection. The final gate used separate clean web/worker processes with no
reader/scheduler edits during the ten minutes. Code hot-upgrades are not a
supported worker deployment path; README requires service restarts for code
changes. TOML hot reload is separately verified, including after the final
watcher/discovery changes.

Residual limits: the passive journal check/open race still relies on the tested
bd retry behavior. Arbitrary host/OOM failures, killing the guardian itself,
malicious descendants escaping their group, and future bd versions are not
proven safe by this gate. No actual bd read timed out in the final run; timeout
and owner-death reaping were forced with synthetic subprocesses. Config discovery
is bounded, and server-mode repos deliberately remain unreachable.

Declined: arbitrary crash injection, server-mode clients and day-long endurance.
Verdict: **Ready within the tested boundary**. Cheapest pre-merge check is
precommit; repeat live acceptance when the reader or bd changes.

## Final gates

Fresh commands, all exit 0:

```text
MIX_ENV=test mix compile --warnings-as-errors --force
  Compiling 49 files (.ex)
  Generated board app
mix precommit
  Repository hygiene: no license material or operator paths detected
  4 properties, 124 tests, 0 failures
BOARD_ROLE=web BOARD_CONFIG_DIR=/tmp/bb-exec/config mix assets.build
  Tailwind and esbuild completed successfully
Python ast.parse over the guardian and tools/*.py
  syntax passes without creating bytecode files
git diff --check
  clean
```

The live reload/browser checks were repeated after restarting the worker with the
final watcher/discovery implementation. Reader, guardian and scheduler source
were unchanged after the successful ten-minute gate; hashes are in evidence.json.
The temporary web/worker processes are stopped at handoff. Scratch copies,
raw evidence and the droppable development database projection remain available.

**Changed:** runtime executors, physical admission, scheduling, persisted config
and health, worker watching, Fluxon shell/Settings and acceptance tools.
**Verified:** the commands, live checks and artifacts above.
**Not verified:** installed systemd/release packaging, day-long endurance,
server-mode reads, arbitrary host/guardian failures and development worker code
hot-upgrades. These are not claimed by the passing foundation gate.
