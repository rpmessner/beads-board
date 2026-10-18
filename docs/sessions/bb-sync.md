# bb-sync partial handoff

This is **not completion of bb-c2w.4**. The session stops at the permitted partial
boundary. Keep the parent ticket open. No automatic store reads are enabled.

## Review baseline

`b3845feedd834f4c5651ca6d22155638a47d06fa` resolves to HEAD. There are no commits
since it, so the committed three-dot diff is empty. The explicit self-diff and
no-commits instructions make the working-tree changes and new files the review
input. The pre-existing coordinator brief is excluded. Axes run sequentially in
this session, without subagents.

## Standards

Reviewed the diff against both AGENTS files, the house Standards baseline and
`state-machine-skeleton`. Read and schedule transitions live entirely in declared
`Board.Fsm` tables. The reducers interpret effects, not status fields. Both new
machines have generated diagram/matrix goldens. Deployment role is immutable
configuration, not lifecycle state. Oban owns notification connection lifecycle;
the application adds no separate reconnect process or hidden state machine.

No Critical or Important defect found in this implemented subset. No warning
suppression or dependency-source patch was added. The coordinator-accepted Oban
2.23.0 unused MySQL-clause warning occurred on fresh dependency compilation.

Declined to judge runtime subprocess ownership, scheduler supervision and UI
standards because those adapters and views remain unimplemented. Verdict: ready
for a partial handoff, subject to the remaining axes and final gates.

## Spec

Reviewed after Standards against Decisions 1–5, 13–14, the named acceptance
checks and the new two-role deployment requirement.

- Important, fixed: production runtime configuration required the endpoint
  signing secret in worker-only mode. A Config.Reader probe failed with
  `environment variable SECRET_KEY_BASE is missing`. Worker now needs only the
  database configuration. The repeated probe passed, and runtime-config tests
  cover worker without the secret, web still requiring it, the default role and
  rejection of unknown roles.
- Important, deferred under the permitted partial boundary: no actual reader
  subprocess, physical-store admission owner, periodic scheduler, config watcher,
  persisted cross-role config snapshot, sync-status model, discovery, Fluxon or
  Settings view. No real-repo counts, note freshness, ten-minute writer loop or
  screenshots. The pure protocols do not satisfy those acceptance checks.
- Implemented: explicit web/worker/all role selection, Postgres notifications,
  projection-change publication at commit, and no notification on hash skip.
  No store writes, server starts, copies or fallback reads were introduced.

Declined to judge visual fidelity and actual agent-write safety because neither
can be exercised without the remaining runtime. Verdict: not ready to close
bb-c2w.4. The missing runtime is a continuation, not a passing acceptance claim.

## Risk

Reviewed after Spec. No subprocess or automatic repo-read caller exists in this
slice, so these additions cannot contend with an agent's bd writes. The new
operational boundary is the application role and Postgres notification transport.

- Cleared at proof level 5 for deployment separation: started independent web and
  worker BEAM processes with the same test database and no Erlang peers. Web had
  an endpoint and no Oban queues. Worker had no endpoint. Worker published an
  invalidation that web received through Postgres. Output was:

  ```text
  READY
  WORKER_PUBLISHED_WITHOUT_ENDPOINT
  WEB_RECEIVED_POSTGRES_EVENT
  ```

  A separate development worker boot asserted the real `external_reads` queue
  limit was 4, the endpoint was absent and the peer list was empty:

  ```text
  WORKER_QUEUES_WITHOUT_ENDPOINT_OR_CLUSTER
  ```

- Cleared at proof level 4 for projection publication: `events_test.exs` uses a
  second Oban notifier plus raw Postgrex LISTEN, without SQL sandbox wrapping for
  those committed probes. It receives all three product invalidation kinds,
  verifies projection publication after commit, suppresses hash-skip publication
  and verifies rollback sends nothing. The committed projection probe deletes its
  unique cache row afterward. Existing projection tests still pass.
- Cleared at proof level 4 for the pure cancellation contract: deliberately changed
  the cancelling/reaped transition to emit `project` with late output. The timeout
  regression failed on exactly that effect. Restored the table; final tests pass.
- Residual: these machines do not resolve physical aliases, provide cross-worker
  admission or reap OS processes. Their safe protocol is not proof that an adapter
  implements it. A job timeout must never release single flight before cleanup.
- Residual: LISTEN/NOTIFY is transient. Oban owns reconnection, but a disconnected
  subscriber misses events. LiveViews still need initial fetch and periodic
  reconciliation. The config snapshot and validation result must be persisted in
  Postgres before cross-role publication; the existing pure reload snapshot is
  not that persistence layer. Broadcasts do not carry config or ticket bodies.

No Critical or Important defect remains in the implemented subset. Declined to
judge actual subprocess cancellation, real-store concurrency, config recovery
and screenshots because their runtime adapters are absent. Verdict: ready only
for this partial boundary. Cheapest pre-merge check is `mix precommit`; it cannot
replace the outstanding live-reader acceptance.

## Changed

- `Board.Beads.ReadMachine` and `Read` declare passive lock observation, export,
  cancellation, reaping, projection and terminal-result effects. Every completion
  carries the read token. Failed and deferred reads emit no projection effect.
- `Board.Beads.ScheduleMachine` and `Schedule` declare per-store admission,
  coalescing, disable/drain/re-enable behavior and boot/generation correlation.
  The owner supplies monotonic milliseconds and physical identity.
- Added both generated machine goldens to `fsm_docs_test.exs`.
- `Board.Role`, application supervision and `BOARD_ROLE` runtime validation split
  web from worker. Removed the DNSCluster child. No units were installed and no
  home config was read or changed.
- `Board.Events` uses the explicit Postgres Oban notifier for all three product
  invalidation kinds. `Projection.replace/2` publishes only changed transactions.
- README records roles, transient notification recovery, remaining work and the
  coordinator's acceptance of the pinned Oban dependency warning.

No commits, pushes, bd commands, subagents, store copies, user-config changes or
edits to other repositories. The coordinator-owned brief remains untouched.
Dependencies were fetched into this worktree; `mix.lock` did not change.

## Read rule implemented and still missing

The pure schedule accepts nominal three-second ticks even with unchanged signals.
Pings and sweeps use the same admission function. Busy requests do not accumulate
and completion never launches a catch-up read. Disabling an active read enters
`draining`; re-enabling cannot bypass the still-owned child.

The read protocol requests the existing passive journal observer first. Held or
indeterminate evidence finishes as deferred. Clear evidence emits a single export
request with a 20-second limit. Timeout emits cancellation and waits for reaping;
late successful stdout is discarded. Only a successful reaped export emits a
projection effect. There is no fallback, store-copy, repair or server-start effect.

**No effect executor is implemented.** There is no actual bd subprocess, periodic
scheduler, physical-path resolver or cross-process admission lock. The existing
JournalLock check/open race remains; only the tested bd internal retry can handle
a writer starting after observation. No live-board safety or freshness claim is
made by these pure tests.

## Config shape

Unchanged: shipped defaults, global `~/.config/beads-board/board.toml`, then adjacent
untracked `board.local.toml`. Tables merge, columns replace, repos merge by key,
and `repos = []` clears the list. Paths are absolute or home-relative. Unknown
stages and bad TOML retain the last good config in the existing pure reload core.
See README for the full example. No home file was created or read.

`BOARD_ROLE=web|worker|all` is deployment configuration, not a TOML option. It
selects services at boot; changing it requires restart. The deployment target is
two user units from one release, named `beads-board-web` and `beads-board-worker`,
sharing Postgres. `all` remains the development/test default.

## Evidence by acceptance item

| Requirement | Evidence and remaining work |
| --- | --- |
| 1: every configured repo and matching counts | Not run. No external-read job or configured-repo runtime exists. |
| 2: five-second idle note freshness and hash skip | Existing database hash-skip tests pass; a new committed test verifies unchanged exports send no notification. Actual scratch note freshness remains untested. |
| 2a: ten minutes of concurrent writes | Not run. No bd command was executed, including on scratch. Cancellation is a tested protocol, not an OS-process implementation. |
| 10: hot config reload and last-good retention | Existing config core tests pass. Watcher, Oban reload adapter, persisted cross-role snapshot and live validation remain absent. |
| 11: precommit half | Hygiene and full precommit pass. No license material was accessed. No day-long repo-status check was run. |
| Settings and screenshots | Not implemented. No Settings LiveView test or light/dark screenshot exists. |
| Split deployment and cross-node broadcasts | Independent BEAM role/broadcast probe passes. Automated tests verify Postgres delivery, committed projection events, rollback suppression and runtime-role validation. Actual systemd units/release not installed or tested. |

## Test trail

- Schedule's first nominal tick failed against the no-effect stub, then passed.
  Added coverage for busy coalescing, no catch-up, minimum spacing, stale replies,
  disabling and re-enabling during drain.
- Read's initial lock effect, held/indeterminate deferral, success pipeline and
  timeout retention each failed against stubs before implementation. Added failed
  command, stale reply, duplicate result and projection rejection checks.
- Web-role test first failed because queues were still enabled. It passes after
  role-specific child selection. Worker and all preserve configured queues.
- The Postgres notification test failed with an empty mailbox against a no-op
  publisher, then passed with the actual notifier. The projection publication
  test separately failed before wiring publication into the transaction.
- The worker production-config probe failed without `SECRET_KEY_BASE`, then
  passed after restricting the requirement to endpoint roles.
- Fresh dependency compilation reproduced the accepted Oban warning. A one-off
  dependency build also reported a future-mtime reset for Postgrex; final gates
  had neither warning. No dependency source was patched.

## Continue here

1. Implement an owned subprocess adapter and exercise timeout, cancellation,
   parent death and reaping with synthetic commands before any real store read.
   Execute the declared read effects only inside Oban jobs.
2. Resolve physical-store aliases and establish cross-worker single flight. A
   config key or in-memory Schedule snapshot is not sufficient. Add the nominal
   timer, coalesced pings/signals and five-minute sweep without catch-up bursts.
3. Add config reload jobs, directory watcher and failure/restart correlation.
   Persist the accepted config and validation status in Postgres. Web must read
   that snapshot, not watch files or rely on worker-local memory. Route requests
   across Postgres and keep all watcher/scheduler children worker-only.
4. Persist/query configured-repo sync metadata and publish through Board.Events.
   Render stale age while deferred. Preserve projection on failed reads.
5. Install Fluxon, implement the approved Settings/app shell and discovery with
   pasteable TOML. Add LiveView tests and missed-notification reconciliation.
6. Verify scratch copies of every real repo, matching counts, unreachable server
   mode, note freshness, and ten minutes with zero failed writes. Capture and
   inspect Settings light/dark screenshots. Do not use the old probe as this gate.
7. Re-run the three review axes and final gates before closing bb-c2w.4.

## Final gates

Fresh commands, exit 0:

```text
MIX_ENV=test mix compile --warnings-as-errors --force
  Compiling 39 files (.ex)
  Generated board app
mix precommit
  Repository hygiene: no license material or operator paths detected
  Running ExUnit with seed: 23872, max_cases: 16
  4 properties, 104 tests, 0 failures
git diff --check
```

These gates emitted no warnings. They do not erase the accepted upstream warning
on a fresh Oban dependency build. The working tree contains only these uncommitted
deliverables and the pre-existing coordinator brief.

Review totals: Standards has no open subset defect; Spec has one Important fixed
and the explicit deferred parent requirements; Risk has no open subset defect,
but runtime safety remains unproven. No Critical findings.

Changed: pure read/schedule protocols, deployment roles and Postgres invalidations.
Verified: pure protocol regressions, Postgres tests, independent BEAM notification
probe, worker-only boot and final gates. Not verified: actual reader, config
watching, Settings, real/scratch repo acceptance, release units or screenshots.
The completion marker denotes this permitted partial handoff, not ticket closure.
