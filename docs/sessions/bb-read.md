# bb-read: partial 4b handoff

## Result

**Not completion of bb-c2w.4.** This session stops at the permitted partial boundary:
Postgres/Oban bootstrap, export decoding, passive lock observation, and transactional
projection storage. No automatic reads or product views are enabled. Keep the
parent ticket open.

No commits, pushes, bd commands, subagents, home-config edits, or changes to other
repos. The coordinator's `docs/briefs/bb-read.md` is untouched. Tests create synthetic
files in temporary directories and use the local Postgres test database. No real
beads store was opened or copied.

## Changed

- Pin Oban 2.23.0 and Ecto SQL 3.14.0; Req remains 0.6.1. Supervise Repo and Oban
  with the Postgres Basic engine. Oban's migration is pinned to schema version 14.
- Use `beads_board_dev` / `beads_board_test` and loopback port 4747 by default.
  Tests now create/migrate their database and use SQL sandbox ownership. Oban test
  mode is manual; no test job runs in a background queue.
- `Board.Beads.Export`: complete JSONL validation, byte hash, explicit enum tables,
  dates, labels, comments, edges, and raw-field retention. Unknown enum strings
  become `{:unknown, value}` without atom creation. Malformed or duplicate records
  reject the whole export with a line number, not its potentially sensitive content.
- `Board.Beads.JournalLock`: passive Linux journal device/inode matching against
  `/proc/locks`, with fail-closed handling of absent or ambiguous evidence.
- `Board.Beads.Projection`: per-repo-key database transaction lock, hash skip,
  JSONB upsert/delete, and orphan marking/clearing without deleting overlay facts.
  `bead_repos` and `beads` are droppable; `tickets` has no projection foreign key.
  Comments and edges remain embedded in raw JSONB, not separate indexed tables.
  The overlay table reserves identity/stage fields; stage backfill is not implemented.
- README documents setup, the changed database-backed test gate, and boundaries.

## Read rule implemented so far

`JournalLock.check/2` stats every discovered embedded database's existing regular
`.dolt/noms/LOCK`, reads proc lock evidence, then checks identities again. It matches
both device and inode, including blocked-waiter rows. Held locks return
`{:defer, :held}`. Missing stores/locks, symlinked store components, unreadable paths,
malformed proc data, or changed identities return `{:defer, :indeterminate}`.
The initialization `.lock` is not mistaken for the journal lock. The observer never
opens, acquires, creates, deletes or releases a store lock.

`:clear` is an observation, not permission protected by a lock. A writer can start
immediately afterward. The future reader must rely on bd's tested internal retry
for that race, not signal the writer. A real flock on a synthetic empty journal is
observed as held; after release the same still-existing file is clear.

**Not implemented:** the bd subprocess, exit-status handling, cancellation/reaping,
physical-path alias resolution, per-physical-repo single flight, three-second ticks,
coalesced signals/pings, five-minute sweep, and unreachable/stale presentation.
Do not wire these boundary modules into a scheduled job until those pieces exist.
Do not treat the database lock in `Projection` as reader single flight: it protects
projection replacement by config key only, not an external process or physical path.

`Projection.replace/2` must receive only complete output from a successful command.
An empty successful export deliberately deletes that repo's cached beads. Never
pass empty stdout from a failed command. The projection's malformed-input rejection
preserves the last good rows, but it cannot infer a command's exit status.

## Config shape

Unchanged from 4a: shipped defaults, global `board.toml`, adjacent untracked
`board.local.toml`; recursive table merge, columns replaced in full, repos merged
by key, `repos = []` clearing the inherited list. Paths are absolute or home-relative.
Board options, ticket-stage columns, repos, backfill and per-epic display options
are documented with TOML in README. No home config is read by the new bootstrap;
no watcher is running. The existing reload machine still retains invalid edits
in unit tests, not in a live Settings view.

## Review baseline

Fixed point `b594094da2d886eeea4cbad3fd6daa44c76ee5a9` resolves to HEAD. The commit
list and three-dot diff are empty. Per the explicit self-diff/no-commits request,
review covers the working-tree modifications and new files as additions against
that tree, excluding the coordinator brief. Axes run sequentially in this session.

## Standards

Inputs: local Phoenix guidelines, parent working agreement, house Standards
baseline, and `state-machine-skeleton`. The new modules are a decoder, passive
filesystem adapter and transactional projection adapter. None retains a lifecycle
state or interprets a status field to decide transitions. No app-owned job pipeline,
watcher or subprocess lifecycle is introduced without a machine; those remain open.

- Important, unresolved dependency constraint: a fresh compile of pinned Oban
  2.23.0 under Elixir 1.19 reports `expected_error?/1`'s MySQL clause as unused
  (`deps/oban/lib/oban/repo.ex:253`). MyXQL is absent. No dependency source was
  patched, no correctness warning suppressed, and no unused database driver added.
  A pin/toolchain change needs coordinator/user approval. This prevents claiming
  a warning-free clean dependency build even when the app's final gate passes.
- No other Critical or Important Standards finding in the implemented boundary.

Declined to judge: runtime FSM coverage and UI standards, because no application
read job, watcher, or view was added. Verdict: partial handoff only; dependency
warning remains open.

## Spec

Reviewed after Standards against Decisions 1–5, 13–14 and checks 1, 2, 2a, 10,
and the precommit half of 11. The bootstrap uses Postgres only; the new code
never invokes bd or writes to a repo. The export projection preserves full ticket
content and unknown enum spellings. Its byte-hash skip makes no INSERT, UPDATE or
DELETE, verified by repository-query telemetry in the SQL sandbox.

- Important, deferred under the permitted partial split: the app still cannot
  read configured repos or show Settings. Automatic sync, config watching, Fluxon,
  discovery, live validation, and UI verification remain absent. This is not a
  passing implementation of checks 1, 2, 2a, 10 or Settings acceptance.
- The projection stores comments/edges in JSONB rather than the design's suggested
  separate tables. Content is retained; indexed graph queries remain future work.
- No unrequested writes, server startup, migrations of beads stores, or fallback
  copies were introduced. Board database migrations are the only storage setup.

Declined to judge: scratch-repo counts/freshness/concurrency and screenshots; neither
the runtime nor authorization for scratch bd commands is present. Verdict: **not
ready to close bb-c2w.4**; the implemented subset is ready for continuation.

## Risk

Reviewed after Spec. The safety fact is that these adapters have no automatic
caller opening a store, and projection replacement validates the whole export
before changing rows. Overlay identity is independent of the cache. Proof level 4
for those boundaries: real Postgres tests verify malformed-input retention,
repo isolation, note upsert, deletion, orphan marking/reappearance, and a cache
rebuild that leaves the overlay stage intact. A real synthetic flock verifies
Linux device decoding and held/released behavior without bd or agent processes.

- Important, fixed: the SQL telemetry assertion's regex was over-escaped in
  `test/board/beads/projection_test.exs`. A deliberate mutation that rewrote an
  unchanged export initially failed only the timestamp assertion. Corrected the
  regex; the same mutation then failed on the actual INSERT message. Restored
  hash skip and reran all boundary tests: 18 tests, zero failures.
- Cleared at proof level 5 for bootstrap only: started the endpoint with Repo and
  Oban, queried `current_database()`, checked Basic engine, and received HTTP 200
  at `127.0.0.1:4747`. No product-view or sync claim follows from this scaffold page.
- The first HTTP probe failed because its temporary override set `live_reload`
  to `false`; Phoenix LiveReload 1.7 expects a keyword list. Retried with `[]` and
  got 200. No application change was needed. For headless probes, disable both
  watchers and live reload with empty lists, not a boolean.
- Residual: the observer has a check/open race and assumes proc visibility for
  the agents' PID namespace. It grants no strict writer priority. Database-key
  locking is not physical-store single flight. Failed command stdout must never
  reach the projection adapter. Those contracts belong to the future reader.
- Dev database setup created `beads_board_dev`; tests created/migrated the test
  database. No old `board_dev` or `board_test` database was dropped or renamed.

Declined to judge: real-store concurrency, cancellation, config-watcher restart
behavior and UI behavior. They are not implemented. Verdict: partial adapters
ready for continuation; the live-reader safety gate remains unproven. Cheapest
pre-merge check is `mix precommit`; it cannot replace the future 10-minute gate.

Review totals: Standards has one unresolved upstream warning constraint; Spec has
the explicit deferred 4b requirements; Risk has one Important test gap fixed.
No Critical finding. Parent completion remains blocked.

## Evidence by acceptance item

| Item | Evidence and remaining gap |
| --- | --- |
| App boots / Decision 1 | Running scaffold returned HTTP 200 on loopback 4747 with `beads_board_dev` and Oban Basic. Release and systemd setup not tested. |
| 1: every configured repo, matching counts | Not run. No reader job or configured-repo runtime exists. No bd commands were authorized. |
| 2: note freshness and hash skip | Synthetic fixture note upsert and actual SQL hash-skip tests pass. Live note freshness and sweep behavior are unimplemented. |
| 2a: zero failed writes over ten minutes | Not run. No bd commands, scratch copies, writer loop, or actual reader cancellation path exists in this slice. |
| Projection persistence | SQL sandbox tests cover complete replacement, scoped deletion, invalid-input retention, orphan preservation, reappearance, and droppable-cache rebuild. Fixtures are synthetic, not scratch copies of every real repo. |
| 10: hot config reload / invalid retention | 4a core tests still pass. No watcher, job adapter or live Settings validation exists. |
| 11: precommit half | Hygiene and precommit pass on the final tree. No license material was read. Clean dependency compilation still emits the pinned Oban warning. |
| Settings / light and dark screenshots | Not implemented or captured. No LiveView Settings test. |

## TDD trail

- Export fixture assertion failed against `{:error, :not_implemented}`, then passed
  with normalization. Malformed `labels: false` first slipped through a nil/default
  shortcut. The corrected regression failed, then passed after rejecting false.
  The test uses distinct IDs so duplicate detection cannot mask malformed records.
- Journal observation failed both clear and held assertions against its stub.
  Real Linux flock tests passed after implementing passive device/inode matching.
- Projection replacement failed against its stub, then passed against Postgres.
  The orphan test then failed on a nil marker and passed after transactional
  marking/clearing. The hash-skip mutation test is recorded in Risk above.
- Bootstrap configuration and generated migrations used executable checks rather
  than test-first scaffolding. Existing config tests were retained, not rebuilt.

## Continue here

1. Resolve the pinned Oban clean-build warning with the coordinator. Do not hide
   it with a new unused driver or edit downloaded dependency code.
2. Implement the actual reader and job/scheduler machines. Resolve physical repo
   aliases, coalesce ticks/signals/pings, always schedule at nominal three seconds,
   sweep every five minutes, and preserve data on every failed or deferred read.
   Verify owned subprocess cancellation/reaping before enabling any real reads.
3. Wire the config reload machine through Oban with restart-safe result correlation,
   terminal failure delivery and directory watching. Keep the existing config API.
4. Add configured-repo sync metadata and broadcasts. The current cache only has
   successful export hashes/timestamps, not unreachable or stale status. Complete
   query projections/indexes as the views need them, without coupling overlay FKs.
5. Install and wire Fluxon, build the approved Settings/app shell, discovery and
   pasteable TOML blocks, and test live reload/invalid retention in LiveView.
6. Obtain explicit scratch-only bd authorization. Then verify every real-repo copy,
   counts, note freshness, timeout behavior, and ten minutes of concurrent writes.
   Capture light/dark screenshots and compare them with the approved mockup.
7. Repeat all three review axes and gates before closing the parent ticket.

## Final gates

Fresh commands, exit 0:

```text
mix format --check-formatted
mix compile --warnings-as-errors --force
  Compiling 30 files (.ex)
  Generated board app
mix precommit
  Repository hygiene: no license material or operator paths detected
  Running ExUnit with seed: 638230, max_cases: 16
  4 properties, 79 tests, 0 failures
git diff --check
```

This final app compile and precommit output had no warnings. It does not erase the
fresh-dependency Oban warning documented above. The working tree contains only
these uncommitted deliverables and the pre-existing coordinator brief.

**Changed:** runtime bootstrap and tested reader/projection boundaries.
**Verified:** database-backed tests, synthetic real-lock observation, hash-skip
mutation check, scaffold HTTP boot, and the gates above.
**Not verified:** the live product, actual bd reader, scratch concurrency/freshness,
config watching, Fluxon, Settings or screenshots. The marker is a partial-session
handoff, not acceptance of bb-c2w.4.
