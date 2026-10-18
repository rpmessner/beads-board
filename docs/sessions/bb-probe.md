# bb-c2w.1 probe session

## Changed

Added `tools/probe-bd-concurrency.py`, `tools/probe-bd-lock.py`, `tools/verify-bd-probe.py`, the measured [reader rule](../probe-bd-concurrency.md), and content-free evidence under `docs/probe-evidence/`.

No commits, pushes, subagents, or bd commands against a real store. The ticket was already claimed; this session did not change its status. The existing `docs/briefs/` is coordinator-owned and untouched.

## Runs and verification

First run: `python3 tools/probe-bd-concurrency.py --seconds 600`, artifacts at `/tmp/bb-probe/run-20261017-230616`.

| Copy / nominal interval | Writes failed / attempted | Reads failed / attempted | Duration |
| --- | ---: | ---: | ---: |
| form-engine / 3 s | 0 / 610 | 0 / 158 | 605.433 s |
| form-engine / 0.1 s | 0 / 525 | 0 / 324 | 606.174 s |
| ui-o-matic / 3 s | 0 / 535 | 0 / 158 | 604.811 s |
| ui-o-matic / 0.1 s | 0 / 400 | 0 / 364 | 607.597 s |

`python3 tools/verify-bd-probe.py /tmp/bb-probe/run-20261017-230616` checked raw-log hashes and counts, all 2,070 successful write acknowledgments or persisted effects, and 414 new issues in final exports. No failure text exists. The only stderr was the missing `beads.role` warning, reproduced exactly in the probe document.

`python3 tools/probe-bd-lock.py /tmp/bb-probe/inspect` confirmed the real journal flock is visible in `/proc/locks`, persists as a file after release, and makes bd wait rather than immediately fail. Export succeeded after release in 3.803 s. Installed-module source confirms exponential open retries until context cancellation. Internal retry counts were not instrumented.

Final-script rerun: the same 600-second command, artifacts at `/tmp/bb-probe/run-20261017-231817`.

| Copy / nominal interval | Writes failed / attempted | Reads failed / attempted | Duration |
| --- | ---: | ---: | ---: |
| form-engine / 3 s | 0 / 645 | 0 / 177 | 604.597 s |
| form-engine / 0.1 s | 0 / 520 | 0 / 429 | 606.349 s |
| ui-o-matic / 3 s | 0 / 560 | 0 / 169 | 603.780 s |
| ui-o-matic / 0.1 s | 0 / 360 | 0 / 449 | 603.758 s |

The final persistence audit checked all 2,085 writes and 417 new issues. Both runs total **0/4,155 failed writes and 0/2,228 failed reads**, across eight ten-minute scenarios. All five operations ran equally often within each scenario. The corrected observer saw the live journal lock in every scenario, with 67,253 held-lock samples in total. Repeating the controlled lock test on a final-run copy succeeded in 3.404 seconds with empty stderr.

## Chosen read rule

Single-flight exports on a nominal 3-second schedule; coalesce signals and pings, skip a passively observed held journal lock, preserve the last good projection, and retry only on later ticks. Never manipulate store locks or agent processes. No store copies by the board. bd's internal retry covers the check/open race on this version.

Keep a five-second **idle target**, not a contention deadline. The first run's longest export took 51.768 seconds; even 30 seconds is not an unconditional promise. No write failed, so the specified failure-triggered 30-second polling fallback was not needed. Cheap signals plus a five-minute sweep alone miss the create/note target; the scheduled export must run even without a signal.

## Review baseline

Fixed point: `e6cf1a0335bc077e31b80a0da4a644c1781bac25`, resolved locally. There are no commits since it and the three-dot committed diff is empty. The explicit no-commits/self-diff request means review includes the new, untracked deliverables as additions against that tree. Coordinator-owned briefs are excluded. Axes run sequentially in this session, without subagents.

## Standards

Reviewed the scripts and report against the parent working agreement, the review baseline, and the prose skills. No local AGENTS.md or language-specific lint configuration exists.

- Important, fixed: the original lock observer matched only lower-case `lock`, missing Dolt's upper-case `LOCK`. It now matches case-insensitively. Separate passive observations validate the first run; the final rerun exercises the corrected observer.
- Important, fixed: a subprocess timeout previously lost the scenario summary. The command wrapper now records a harness timeout as exit 124 with explicit text and retains partial output. No measured command timed out.
- Minor, left open: the probe uses Python standard-library assertions for verification and must be run without `python -O`.

Declined to judge: Phoenix styling and production supervision, because neither exists in this diff. Verdict: ready. The final measured rerun passed, with no remaining Critical or Important standards findings.

## Spec

Reviewed after completing Standards, against the supplied bb-c2w.1 acceptance and spec Decision 5 / checks 2 and 2a.

- Important, fixed: exit-code counts alone could hide missing persisted writes. Added `verify-bd-probe.py` and audited final issue titles, notes, dependencies, closures, and update acknowledgments against raw commands.
- Important, fixed in the written rule: the design's signal-only polling plus five-minute sweep cannot notice every create/note within five seconds. The rule requires scheduled exports even without a changed signal.
- No missing probe operation: create, update, note, dependency add, and close each ran in all four ten-minute scenarios. Exact failure text is absent because there were no failures; nonfatal warnings are recorded separately.

Declined to judge: acceptance 2a's actual live-board implementation, which is downstream of this probe. The probe uses real bd processes but does not pretend to be that board. Verdict: ready, with no remaining Critical or Important findings in bb-c2w.1 scope.

## Risk

Reviewed after Spec. The load-bearing safety fact is that every mutating command opens an independent scratch copy, not a real repo. Proof level 4: executed an importing Python check against `scratch`, `probe_env`, all four final-run copies, and `git rev-parse --show-toplevel`.

```text
outside_cwds_rejected: 3
copies_without_symlinks_or_shared_config_inodes: 4
git_roots_isolated: true
auto_push_and_backups_disabled: true
```

- Important, fixed: inherited git settings and permissive copied configuration could allow an outward side effect. The final script strips inherited bd/Dolt/git overrides, initializes isolated git roots without templates, rejects unexpected project config keys, disables hooks/auto-push/backups, and confines export/routing destinations. The full rerun uses these guards.
- Cleared for these runs: no failed writes, no dropped created issues, no harness retries masking errors, no shared symlink targets. The source-module retry path matches the installed binary.
- Residual: the passive check is not atomic. Exports can delay agents, and retries do not guarantee fairness. The report does not promise strict priority or finite freshness during continuous contention.

Declined to judge: production process cancellation and crash recovery, neither exercised by this probe. Verdict: ready within the probe scope, with no remaining Critical or Important findings. Before merging, rerun the persistence audit and syntax check; before shipping the reader, run acceptance 2a through its actual timeout path.

Review totals: Standards 2 Important fixed / 1 Minor open; Spec 2 Important fixed; Risk 1 Important fixed. No Critical findings. No remaining Important findings within the probe scope.

## Final verification

- `python3 tools/verify-bd-probe.py` against both run directories: all eight scenarios meet the duration requirement, counts match raw logs, and persisted effects match successful writes.
- `python3 -m py_compile tools/*.py`: syntax passes.
- New-file diff whitespace checks and local Markdown evidence links: pass.
- Original fixed-point committed diff remains empty; all deliverables remain uncommitted.

## Open for the coordinator / reader ticket

- Acceptance 2a against the running board remains untested. The reader does not exist in this worktree. Its 20-second cancellation path must be tested; these probes used a 60-second command cap and did not hit it.
- Acceptance 2 cannot be an unconditional five-second guarantee during continuous writes. Stale age must remain visible; never sacrifice an agent write to meet freshness.
- A passive lock check has a race and grants no strict writer priority. Zero observed failures on this binary is not proof against arbitrary load, crashes, or a future bd version.
- Reading through bd can rewrite engine files. A requirement for literally zero filesystem writes would conflict with the chosen bd-export mechanism.
