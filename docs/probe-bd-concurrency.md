# Embedded bd concurrency: reader rule

Probe for bb-c2w.1, 2026-10-17. **Concurrent exports did not fail an agent write.** Across two complete runs, all 4,155 writes and 2,228 exports succeeded. This is evidence for this binary and these stores, not a guarantee for every bd version or arbitrary load.

## Reader rule

Use one `bd export` at a time per repository, on a **3-second nominal schedule**. Never queue catch-up exports. Coalesce CLI pings and file-change signals into the same job. Hash successful output before projecting it; keep the last good projection on failure.

Before opening, passively check whether the embedded journal lock is held. On Linux, match its device and inode against `/proc/locks`. If held, skip this tick; if the lock state cannot be determined, defer rather than acquire a test lock. Do not create, delete, acquire or release store locks. A missing lock file alone is not proof that a writer cannot start.

A check and an open are not atomic. A writer can start between them; **bd's internal retry**, not this check, handles that race on the tested version. Never signal or cancel an agent process. Failures, skips and timeouts belong only in board logs. Never run a repair, migration, server start, export-to-file, or store copy as a read fallback. Existing JSONL may be displayed as a clearly stale snapshot when live reads are unavailable.

Keep **5 seconds as the normal, uncontended freshness target**, not a hard deadline during sustained writes. The probe did not trigger the decision to switch to 30-second polling: no writes failed. It also disproved any unconditional five-second promise: exports sometimes took over 30 seconds. Even a 30-second promise cannot hold under arbitrary contention. Show stale age while deferring; agents take priority over freshness.

Export on the schedule even when cheap signals do not change. A five-minute sweep plus `interactions.jsonl`/git signals cannot meet the create/note target: those operations need not change a watched signal. Do not watch the Dolt manifest to trigger exports; exports themselves mutate it.

The reader's planned 20-second timeout would discard some reads seen here. That is acceptable as a stale-board outcome, but cancellation/reaping and preservation of concurrent writes must be exercised against the implemented reader in acceptance 2a. This probe allowed commands 60 seconds; none reached that limit. Do not claim the live-board gate has passed.

## Measured scenarios

Each scenario used a separate full repository copy under `/tmp/bb-probe/`, with `.git` and symlinks excluded and a new local git directory. Original embedded stores were copied, never opened with bd. The four scenarios ran concurrently on the same host, each with one reader and one serial writer. Results therefore include shared-host load.

The writer repeatedly ran create → update to `in_progress` → note → dependency add (`related` to a probe anchor) → close, with 50 ms between cycles. There were no harness retries. A failed create would skip its dependent commands. Readers ran on a 3-second or 100-ms nominal schedule, without overlapping or catch-up bursts; slow exports necessarily reduced the achieved cadence. A final cycle could finish after the 600-second launch window.

First run:

| Copy | Read interval | Elapsed seconds | Writes failed / attempted | Reads failed / attempted | Max write seconds | Max read seconds |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| form-engine (30 initial issues) | 3 s | 605.433 | 0 / 610 | 0 / 158 | 4.229 | 32.156 |
| form-engine | 0.1 s | 606.174 | 0 / 525 | 0 / 324 | 13.809 | 42.721 |
| ui-o-matic (417 initial issues) | 3 s | 604.811 | 0 / 535 | 0 / 158 | 4.311 | 42.287 |
| ui-o-matic | 0.1 s | 607.597 | 0 / 400 | 0 / 364 | 21.336 | 51.768 |

Each of the five write operations ran 122, 105, 107 and 80 times respectively; all succeeded. Setup and final verification exports are excluded from the table. Final exports retained all 414 created issues, their notes, related dependencies and closed statuses. Update acknowledgments were checked; the final closed status supersedes the transient `in_progress` status.

Final-script rerun, after correcting the lock observer and adding explicit scratch-side-effect guards:

| Copy | Read interval | Elapsed seconds | Writes failed / attempted | Reads failed / attempted | Max write seconds | Max read seconds |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| form-engine | 3 s | 604.597 | 0 / 645 | 0 / 177 | 3.418 | 14.553 |
| form-engine | 0.1 s | 606.349 | 0 / 520 | 0 / 429 | 10.850 | 46.927 |
| ui-o-matic | 3 s | 603.780 | 0 / 560 | 0 / 169 | 6.599 | 13.528 |
| ui-o-matic | 0.1 s | 603.758 | 0 / 360 | 0 / 449 | 22.393 | 27.720 |

Each write operation ran 129, 104, 112 and 72 times respectively in this rerun. Its persistence audit checked all 2,085 successful writes and 417 created issues. The final script disables hooks, auto-push, backups and telemetry, confines export/routing destinations, and rejects unreviewed project config keys. These guards prevent side effects outside scratch; they are not a proposed board configuration change.

**Exact failure text: none** (all exit codes zero). Creates, including anchors, emitted this nonfatal warning 418 times in the first run and 421 times in the final run because the copies deliberately have no original git config:

```text
warning: beads.role not configured (GH#2950).
  Fix: git config beads.role maintainer
  Or:  git config beads.role contributor
```

After the load stopped, five exports per copy took 0.627–0.646 s for form-engine and 0.691–0.716 s for ui-o-matic. These timings support a five-second idle target; they do not prove end-to-end board freshness.

## Which lock, and which retries?

The installed binary reports bd 1.1.0; Go build metadata identifies `github.com/steveyegge/beads v1.1.0`, CGO enabled, and `github.com/dolthub/driver/v2 v2.1.4`.

The live lock is:

```text
.beads/embeddeddolt/<database>/.dolt/noms/LOCK
```

`lslocks` and `/proc/locks` exposed an advisory exclusive `FLOCK`, its PID, device and inode during bd processes on all four copies. A separate passive two-second sample captured 302 held-lock observations. The file remains after bd exits, so testing existence would permanently suppress reads. The lower-case `.beads/embeddeddolt/.lock` is an initialization lock, not the ordinary command lock. The first harness observer searched lower-case names and missed `LOCK`; the committed script fixes this, and the separate passive sample supplies the actual evidence for the first run. The final run observed the real journal lock held in 18,911, 20,149, 13,863 and 14,330 samples respectively. No initialization or backup lock was held in those samples.

Source inspection of the exact installed modules:

- beads `internal/storage/embeddeddolt/store.go`, `newStore`: ordinary opens delegate locking to the driver; the outer flock is only used for initialization.
- beads `internal/storage/embeddeddolt/open.go`, `OpenSQL`: exponential backoff, `MaxElapsedTime = 0` (until context cancellation), `MaxInterval = 5s`.
- driver `connector.go`, `openEngineWithRetry`: retries retryable open errors, including database lock contention; nonretryable errors are permanent. These are open retries, not a blanket replay of failed write transactions.

A controlled scratch-only test held the actual journal flock for two seconds, started `bd export`, observed it still waiting, then released the lock. Export succeeded at 3.803 seconds with empty stderr, then at 3.404 seconds when repeated against a final-run copy. This confirms waiting/recovery empirically; it does not measure the internal retry count. No 30-second lock deadline was observed: several successful reads exceeded 30 seconds.

Exports are logically reads, not physically read-only store opens. They use the embedded engine and can rewrite internal files. `--readonly` is not evidence of a lock-free or filesystem-read-only path. The rule forbids board-authored store changes; it cannot promise zero engine side effects while using this CLI.

## Reproduce and evidence

```sh
python3 tools/probe-bd-concurrency.py --seconds 600
python3 tools/verify-bd-probe.py /tmp/bb-probe/<run-directory>
python3 tools/probe-bd-lock.py /tmp/bb-probe/<run-directory>/form-engine-3s
```

Use only scratch directories for the lock test, after the scenario has finished. The harness copies the two default source repos; optional `--sources` must also name embedded repos with local-only configuration. It strips inherited bd/Dolt/git environment overrides and excludes symlinks and git metadata. Do not use repositories configured to redirect backups/exports to external paths.

Raw commands, exact stderr and per-command stdout remain under `/tmp/bb-probe/run-20261017-230616/` and `/tmp/bb-probe/run-20261017-231817/`, each at `<scenario>/probe-output/`. Raw exports contain ticket content and are intentionally not kept in this worktree. Durable, content-free evidence:

- [First-run counts and raw-log hashes](probe-evidence/concurrency-summary.json)
- [First-run persistence audit](probe-evidence/persistence-audit.json)
- [Final-script counts, lock observations and raw-log hashes](probe-evidence/final-concurrency-summary.json)
- [Final-script persistence audit](probe-evidence/final-persistence-audit.json)
- [Repeated controlled lock test](probe-evidence/final-lock-retry.json)
- [Controlled lock test](probe-evidence/lock-retry.json)
- [Passive lock observations](probe-evidence/passive-locks.json)
- [Idle export timings](probe-evidence/idle-exports.json)

Re-run this probe when bd or its embedded driver changes. Multiple simultaneous agents, process crashes, disk-full conditions, server-mode stores and the actual board's timeout behavior were not tested. Strict writer priority is not an atomic guarantee provided by a passive lock check; these runs establish zero observed failures, not starvation freedom.
