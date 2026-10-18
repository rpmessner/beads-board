# bb-shell: 4a boundary

## Result

**Partial delivery, not completion of bb-c2w.4.** This uses the permitted 4a/4b
split. The config core and hygiene gate are implemented; the running foundation,
reader, and Settings view still need 4b. Do not close the parent ticket.

No commits, pushes, bd commands, or subagents. No user config or other repository
was changed. The coordinator-owned `docs/briefs/bb-shell.md` remains untouched.

## Changed

- `Board.Config`: named TOML layers, shipped defaults, optional global/local file
  reads, merge, validation, and path expansion. Tests use temporary directories.
- `Board.Config.Schema`: types, unknown options, duplicate repo identities,
  durations, and stages checked against `Board.Stage`.
- `Board.Config.ReloadMachine` and `Reload`: pure single-flight reload lifecycle;
  invalid edits keep the last good value. Effects remain data for the future Oban
  adapter. No config worker is started by the app yet.
- Promoted the existing stage fixture unchanged to `Board.Stage`; all existing
  stage behavior, properties, and golden tests now exercise the production module.
  The overlay still does not interpret its effects.
- Added `toml_elixir` 3.2.1 (TOML 1.0 decoding); pinned Req to 0.6.1.
- Added `mix board.hygiene` to `mix precommit`: tracked plus nonignored untracked
  files, operator-path checks, literal license assignments, exact environment
  secret values when present. Findings contain categories, never matched content.
- README describes the implemented contract and the missing runtime wiring.

## Config shape

See README for the pasteable example. Precedence is shipped defaults, global
`board.toml`, then neighboring `board.local.toml`. Tables merge recursively;
columns replace in full; repos merge by key; an empty repo list clears inherited
entries. Repo paths accept absolute or home-relative paths. Defaults contain no
repos, deliberately avoiding unsolicited store reads on a fresh install.

Board options: swimlanes and positive duration for stale sessions. Columns: title,
stages, collapsed. Repos: key, path, optional GitHub slug, forge, color, enabled.
Backfill: closed/default stages. Per-epic options: pin, collapse, color. Unknown
options and stages are errors. Missing optional files use defaults; other read
failures are errors. Values and keys remain strings; no input atom creation.

## Read rule

**Not implemented in this slice.** No beads reader or store operation was added.
The continuation must implement `docs/probe-bd-concurrency.md` exactly: per-repo
single-flight scheduled exports every three seconds even with unchanged signals;
coalesce pings; passively inspect journal lock device/inode against `/proc/locks`;
defer on held or indeterminate lock; no acquiring locks, repair, migration, server
start, store copies, or export-to-file fallback. Preserve projection on every read
failure. Hash skip successful unchanged exports. Five seconds is an idle target,
not a contention deadline. Test timeout cancellation/reaping through the actual
reader without ever signaling an agent process.

## Review baseline

Resolved `ee9d02347c18cc4c60f20af09b3aa798f33a007f`. It is HEAD; the committed
three-dot diff and commit list are empty. Reviewed the explicitly requested
uncommitted self-diff plus new files against that tree. No subagents. Axes run
sequentially; the following verdicts apply to 4a, not the whole parent ticket.

## Standards

Inputs: root working agreement, local Phoenix guidelines, formatter, and the
house Standards baseline. The reload lifecycle is declared in `Board.Fsm`;
state changes come only from `step`, and read/broadcast effects remain data.
Parsers, merge transforms, and filesystem plumbing do not interpret lifecycle
status fields.

- Important, fixed: the new reload machine initially lacked a golden-file test.
  Added it to `fsm_docs_test.exs` alongside stage and epic.
- Minor, fixed: the docs task and README still called the promoted stage a test
  fixture. Updated both.
- No Critical findings. No remaining Important findings in the 4a scope.

Declined to judge runtime supervision, Oban job pipelines, and UI styling: none
is introduced here. Verdict: Ready for the 4a handoff after final gates.

## Spec

Reviewed after Standards, against Decisions 1–5, 13–14 and checks 1, 2, 2a, 10,
and 11. Config validation/merge and retention are implemented at the public
boundary. Stage promotion adds no transition changes or persistence behavior.

- No Critical or Important implementation defects found in the 4a contract.
- Parent acceptance remains incomplete: no runtime config watcher, Oban,
  Postgres projection, Fluxon wiring, Settings, discovery, or read-rule adapter.
  These are the explicit 4b continuation, not passing acceptance claims.
- Hygiene is a guard, not proof that arbitrary unlabeled secrets are absent.
  License environment variables were absent in this session; tests use synthetic
  values and do not access Hex credentials.

Declined to judge live UI and sync behavior because they do not exist. Verdict:
Ready for 4a handoff; **not ready to close bb-c2w.4**.

## Risk

Reviewed after Spec. Safety fact: this slice has no runtime caller that opens a
beads store; it only transforms config or reads named config files. Stage's
transition/guard body is byte-identical to the prior tested fixture.

- Important, fixed: an older async reload result could be accepted during a new
  reload. Added generation-tagged read effects and a declared machine guard;
  mismatched completions are ignored. The regression first failed by replacing
  the new config with the late value, then passed. The future runtime must also
  isolate replies across worker restarts and deliver failed/timed-out job results.
- Important, fixed: the first TOML package emitted deprecated-charlist warnings
  on Elixir 1.19. Replaced it with `toml_elixir`; its fresh compilation and the
  config corpus tests passed without warnings. It preserves string keys.
- Cleared: stage promotion changes no transitions or guard code (executed byte
  comparison against the baseline); all original machine tests still pass.
- Cleared at proof level 4: executed the shipped config/load/reload code with
  `mix run --no-start`: defaults load, rejection preserves them, Repo is absent.
- Guard limitation: it scans the working tree, not a mismatched staged index;
  the separate global commit hook remains the commit-time backstop. Exact-value
  detection needs the license environment variables. No credentials were read.

Declined to judge live bd contention, database orphan marking, watcher recovery,
and job cancellation: these belong to the unimplemented runtime. Verdict: Ready
for 4a handoff. Before integration rerun `mix precommit`; before closing the parent,
run all 4b acceptance checks below. No open Critical or Important defect in 4a.

## Evidence by acceptance item

| Check | Evidence / remaining work |
| --- | --- |
| 1: every repo, matching counts | Not implemented. No projection, Oban jobs, or real-repo reads. |
| 2: note freshness, hash skip | Not implemented. No sync loop or hash writes. |
| 2a: ten-minute writer loop | Not run. No actual reader exists; the prior probe is not a substitute. |
| 10: config reload and invalid retention | Core proven by temp-directory tests for load/merge, bad TOML, unknown stage, retention, recovery, and stale completion. Directory watch, broadcasts, and live columns are not wired. |
| 11: precommit half | Guard passes on the tree. Three planted violations were blocked without echoing material: operator path, literal license assignment, synthetic environment value. Full secret absence is not proven. |
| Settings / screenshots | Not implemented; no LiveView test or light/dark screenshots. |
| App boots / configured databases | Scaffold only; database names, port, release, Oban 2.23.0, and Fluxon wiring still need 4b. |

## Test trail

- Config merge test: failed against `{:error, "not implemented"}`, then passed.
- Unknown-stage test: failed when `speccing` was accepted, then passed. Malformed
  shapes first crashed the normalizer; schema validation now returns errors.
- File loader: failed against its stub, then passed using temporary directories.
- Reload retention: failed on missing read effects, then passed. A deliberate
  mutation clearing config on rejection failed the retention assertion; restored.
- Hygiene: both path and license tests failed against the stub, then passed.
- Generation regression: failed on late completion replacing the active config,
  then passed after the guard. Reload golden was regenerated and checked.
- Malformed TOML corpus: invalid UTF-8, incomplete syntax, duplicate keys and bad
  dates returned errors, not exceptions. No atom conversion exists in app config
  code; the pinned decoder returns string keys.

## Continue as 4b

1. Wire Oban/Postgres with the requested pins, names, loopback port and migrations;
   no config reads outside jobs. Add the directory watcher and a supervised config
   owner around `Reload`, including startup defaults, job failures and restart-safe
   correlation. Watch directories so rename-save works; do not write user config.
2. Implement reader normalisation, passive lock checks, safe subprocess lifetime,
   per-repo single flight, schedule/signals/sweep, hash skip, transactional droppable
   projection, and orphan marking without deleting overlay facts. Resolve physical
   repo aliases before scheduling so symlink paths cannot bypass single flight.
3. Wire Fluxon and Settings to real state, discovery and live config updates.
4. Verify scratch copies of every repo, counts, idle note target, ten minutes of
   concurrent writes through the actual reader/timeout path, and light/dark UI.
   The brief's blanket no-bd rule conflicts with those scratch verification commands;
   get the coordinator to explicitly authorize scratch-only bd before running them.
5. Repeat sequential reviews and gates. Keep bb-c2w.4 open until these pass.

Review totals: Standards 1 Important fixed, 1 Minor fixed; Spec no 4a defects,
parent acceptance deferred; Risk 2 Important fixed. No Critical findings.

## Final gates

Fresh run, exit 0, no warnings:

```text
mix format --check-formatted
mix compile --warnings-as-errors --force
  toml_elixir: Compiling 11 files (.ex)
  board: Compiling 27 files (.ex)
mix precommit
  Repository hygiene: no license material or operator paths detected
  Running ExUnit with seed: 102677, max_cases: 16
  4 properties, 61 tests, 0 failures
git diff --check
```

The working tree holds only the intended uncommitted deliverables and the
pre-existing coordinator brief; the planted hygiene file was removed.
**Changed:** config core, stage promotion, hygiene gate. **Verified:** the commands
above and the isolated boundary probes. **Not verified:** the running product,
storage, sync safety/freshness, or Settings. The completion marker denotes this
permitted partial-session handoff only.
