# bb-files: bb-axu.1

## Scope

The working-tree changes implement Decisions 2–6 of `docs/specs/ticket-files.md`. No commits, pushes, bd commands, subagents, service restarts, or installation changes were made. The coordinator-owned brief is untouched.

The review baseline is `7118b8b4ebd72fc9f4037dcecbe6593c6b65b28b`, which still equals HEAD. The three-dot diff and commit list are empty. This requested self-review covers the working tree and new files instead.

## Changes

- `Board.TicketFile` parses and prints ticket Markdown independently of the CLI.
- `Board.TicketStore` validates files and their graph, generates IDs, and publishes edits with stale-snapshot protection.
- `Board.TicketCLI` implements the offline commands. `Board.TicketStatusMachine` declares the file status lifecycle separately from overlay stages.
- The config schema accepts a repo `prefix`. Config defaults are compiled into the module because an escript cannot read its bundled `priv` path with `File.read`.
- No YAML library existed in `mix.lock`. Added `yaml_elixir` and its `yamerl` dependency. No existing dependency version changed.
- Tests cover the codec, validation, commands, stale writes, and the built escript. `tools/ticket-files-demo.py` reproduces the demo below with both service destinations pointed at a closed port.

## Format and commands

Files live at `tickets/<id>.md`. All thirteen frontmatter keys are required and printed in this order:

```text
id title type status priority parent blocked_by related discovered_from labels created closed close_reason
```

Types are `epic`, `feature`, `task`, `bug`, and `decision`. Statuses are `open`, `in_progress`, `closed`, and `deferred`. Priority is an integer from 0 through 4. References are ticket IDs, dates use `YYYY-MM-DD`, and absent scalar values use `null`. Lists are sorted. Titles and close reasons use JSON-compatible YAML quotes. Files have one final newline. The body remains Markdown with arbitrary sections. Notes append dated actor lines inside `## Notes`, before a subsequent section if present.

Unknown keys, duplicate keys, malformed YAML, invalid field types, filename mismatches, missing parents or blockers, parent or dependency cycles, and epics blocking their descendants are rejected. Related and discovery references must have valid ID syntax but may refer to absent tickets, as Decision 6 only requires parents and blockers to exist.

`new "Title"` also accepts `--title`. New and update accept `--type`, `--status`, `--priority`, `--parent`, `--blocked-by`, `--related`, `--discovered-from`, `--labels`, and `--body`. List flags take comma-separated values. An empty list flag clears the list; `null` clears an optional reference. Other commands are `show ID`, `ls`, `ready`, `close ID --reason TEXT`, `reopen ID`, `dep add|rm ID BLOCKER`, `note ID TEXT [--actor ACTOR]`, `tree [ID]`, `renumber OLD NEW`, and `check`. List and ready support `--status` and `--type` filters.

The CLI finds the checkout root with git. New reads global `board.toml`, followed by optional `board.local.toml`, from `BOARD_CONFIG_DIR` or `~/.config/beads-board` when unset, matching the worker. The checkout root is never an implicit config fallback. One `[[repos]]` entry must match that checkout's path and supply `prefix`. Top-level codes contain three random base36 characters and retry collisions. Children take the lowest unused positive suffix.

All commands accept `--json`. Invalid input and failed validation exit 2. Writer contention and filesystem unavailability warn with exit 0; check still fails closed on an incomplete snapshot. Overlay claims retain their existing exit codes and transport. Show and list use files when the checkout has a tickets directory or a matching configured prefix. Otherwise they retain the old overlay behavior. `--overlay`, `--stage`, `--project`, or `--repo` explicitly select overlay reads.

## Standards

Reviewed first against the root and local AGENTS files, the house baseline, and the formatter and test configuration.

- The file status lifecycle uses `Board.Fsm`; it does not reuse or change the overlay stage machine. Its generated matrix is in `docs/machines/ticket_status_machine.md`.
- Input keys remain strings. The codec has no CLI, database, HTTP, or git dependency. File operations and command parsing are separate modules.
- Test processes use supervision. Temporary directories are removed by test teardown. Tests do not write ticket files in a real checkout.
- TDD evidence starts with a failing canonical property, nine failing store checks, and a failing command workflow against stubs. Later field-validation and publication-race tests were added against working code, so this is not a complete failing-first history for every assertion.

No open Critical or Important standards finding. Declined to judge the pre-existing UI and reader, which this ticket does not change. The approved file spec supersedes the app's older prohibition on repo ticket files.

## Spec

Reviewed second against the bb-axu.1 acceptance items and Decisions 2–6.

- Important, fixed: saving one ticket initially canonicalized unrelated handwritten files. A regression reproduced the lost comment. The store now publishes only semantically changed tickets; a repeated update leaves bytes unchanged.
- Important, fixed during implementation: renumber initially missed Markdown links ending in `.md` and IDs followed by sentence punctuation. The failing regression now passes while longer child IDs remain intact.
- Important, fixed during implementation: an empty configured checkout routed `ls` to the server. It now returns an empty local list. That failing test made one read-only request to the installed service before the routing fix; no server state changed.
- Important, fixed during implementation: irrelevant command flags were accepted and ignored. Command-specific allowlists now reject them before writing.
- The parser rejects every schema-field mutation tested. Check reports file and reason. The escript test exercises every required verb with HTTP and Postgres unavailable.

No open Critical or Important spec finding. Declined to judge Decisions 7–9: the reader, migration, hooks, and skill cutovers belong to later tickets. No editor launch was added.

## Risk

Reviewed third for file publication, CLI compatibility, config loading, and validation cost.

- Critical, fixed: a normal snapshot check followed by rename-over can destroy an editor save in the intervening window. The store now claims each old directory entry, verifies the claimed bytes, and publishes with a no-replace hard link. Race tests inject a hand edit at rename and a new editor file at publication. The editor's bytes survive in both cases. Another failing regression exposed writes through an already-open descriptor; originals are checked again after publication and retained on conflict.
- Important, fixed: a symlinked ticket caused check to treat a `File.Stat` as a parsed ticket and crash. It now produces a file-specific error. Symlinked ticket directories are refused too.
- Important, fixed: validation revisited shared dependency paths exponentially. A 36-ticket acyclic graph exceeded the regression's two-second limit. Traversal now retains one visited set across the search and the same test passes.
- Important, fixed: readers could accept a partial write snapshot. Load and check refuse an active or recovery lock; load also verifies the loaded snapshot before returning.
- Important, fixed during implementation: the real escript could not load config defaults from an archive path. Compiled defaults fixed the failing offline escript test.

The safety fact is that publication never replaces an existing directory entry. Tests exercise the real filesystem with injected operations at the filesystem boundary, including recovery originals. Proof level 4. The subprocess workflow proves offline behavior at level 5.

Publication makes complete files visible atomically, but it is not a multi-file transaction. Claimed ticket paths are briefly absent while the git-dir write lock is held. The lock and recovery area live at `<git-dir>/.board-write-lock`, where git-dir comes from `git rev-parse --path-format=absolute --git-dir`. This resolves a linked worktree's own administrative directory, not the shared common directory. Prepared files and recovery originals never enter `tickets/` and cannot be staged by `git add tickets`. If publication fails after some files were published, the store never deletes a competing writer's file to roll back. It retains unrecovered originals under that lock and refuses further reads and writes until a person reconciles them. A process crash also leaves the lock for inspection. There is no automatic stale-lock deletion. These recovery limits are deliberate, not a promise of crash-atomic renumbering.

No open Critical or Important implementation finding. Declined to judge power-loss durability, network filesystems, and writers that keep mutating an old file descriptor after publication has finished. The supported environment is the local Linux filesystem. No systemd or real-repo migration was tested. The cheapest merge gate is `mix precommit`; the demo checks the built executable independently.

## Demo

Fresh run of `python3 tools/ticket-files-demo.py`, using a temporary git repo. Both service destinations were unavailable. Commands all exited 0. JSON stdout is condensed here to the relevant fields.

```text
$ board new 'Offline epic' --type epic --json
id: demo-ste
$ board new Foundation --parent demo-ste --json
id: demo-ste.1
$ board new Consumer --parent demo-ste --blocked-by demo-ste.1 --json
id: demo-ste.2; blocked_by: [demo-ste.1]
$ board ready --json
[demo-ste.1]
$ board close demo-ste.1 --reason 'Tests passed' --json
status: closed; close_reason: Tests passed
$ board ready --json
[demo-ste.2]
$ board check --json
{"errors":[],"valid":true}
$ board tree --json
demo-ste
  demo-ste.1 closed
  demo-ste.2 open
$ board renumber demo-ste.1 demo-ste.4 --json
id: demo-ste.4
$ board check --json
{"errors":[],"valid":true}
```

Resulting files, shown in full:

`tickets/demo-ste.md`

```yaml
---
id: demo-ste
title: "Offline epic"
type: epic
status: open
priority: 2
parent: null
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---
```

`tickets/demo-ste.2.md`

```yaml
---
id: demo-ste.2
title: "Consumer"
type: task
status: open
priority: 2
parent: demo-ste
blocked_by: ["demo-ste.4"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---
```

`tickets/demo-ste.4.md`

```yaml
---
id: demo-ste.4
title: "Foundation"
type: task
status: closed
priority: 2
parent: demo-ste
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Tests passed"
---
```

## Verification

Focused gate after review fixes:

```text
mix test test/board/ticket_file_test.exs test/board/ticket_store_test.exs test/board/ticket_cli_test.exs test/board/ticket_escript_test.exs
1 property, 43 tests, 0 failures
```

A full `mix precommit` passed at seed 921169:

```text
Repository hygiene: no license material or operator paths detected
Generated escript board with MIX_ENV=test
Finished in 32.7 seconds
5 properties, 327 tests, 0 failures
```

Earlier full runs intermittently failed the existing `BoardWeb.LiveViewClockTest` test "a test's clock allowance does not leak to an independent process" at its 100 ms `assert_receive`. The isolated file passed. Seed 909275 reproduced the timeout even with all four new test files excluded and the new `Mimic.copy(File)` registration removed: 4 properties, 284 tests, 1 failure. Serializing the new filesystem tests did not cure it. No clock test or timeout was weakened. The full-suite timing flake remains a disclosed verification risk; its root cause is not established.

The actual escript initially failed offline new because its config defaults path was inside the archive. That failure is covered by the passing subprocess regression. Initial dependency compilation printed the existing Oban unused-clause warning; final application compilation has no warnings.

`git diff --check` and `mix format --check-formatted` pass. The demo exits 0. No service was stopped or reconfigured, and no ticket migration occurred.

Initial handoff gate, superseded by the coordinator correction below:

```text
mix precommit --seed 921169
Repository hygiene: no license material or operator paths detected
Generated escript board with MIX_ENV=test
Finished in 33.7 seconds
5 properties, 327 tests, 0 failures
exit 0

git diff --check
exit 0
```

Changed: the reusable file codec and store, offline ticket CLI, status machine, and prefix configuration.

Verified: all bb-axu.1 acceptance behaviors through unit, property, temporary-repo, and actual-escript tests; the full gate and demo above.

Not verified: deployment, migration, power-loss recovery, or network filesystems. The existing full-suite clock timeout remains reproducible at seed 909275, including with the new test files and File mock registration excluded.

## Coordinator correction: config defaults and git-dir recovery

The coordinator found two Important gaps in the initial self-review. Both are fixed.

1. I used the checkout root as the implicit config directory. The fixtures used the same arrangement, so they hid the production failure. `TicketCLI` now uses the worker's exact resolution: `BOARD_CONFIG_DIR`, otherwise `~/.config/beads-board`. `Board.Config.load` applies global `board.toml` and then `board.local.toml`. An actual-escript regression uses a temporary HOME, removes the environment override, and plants a misleading checkout config. Before the fix it created `wrong-*` instead of `local-*`. After the fix it proves the local override, the global fallback, and refusal when only the checkout config exists. Unit fixtures now set an explicit isolated config directory and restore the environment afterward.
2. I placed recovery files inside `tickets/`, where a crash could make them commit candidates. `TicketStore` now resolves the checkout's git dir and stores the lock, prepared files, and originals there. Refusal messages include the full recovery path. Check rejects a leftover lock even when the ticket files themselves are valid. The migrated tests had five failures before the fix. They now verify preserved originals, exclusion from `git add tickets`, a separate-git-dir checkout, and independent locks in a real linked orphan worktree. No temporary repository needed a commit.

The updated demo uses an explicit config directory separate from its checkout files. Its rerun created `demo-lzh`, children `.1` and `.2`, showed only `.1` ready, closed `.1`, then showed `.2` ready. Check and tree succeeded. Renumber moved `.1` to `.4` and rewrote `.2`'s blocker. The final check returned `{"errors":[],"valid":true}`. All commands exited 0 with both service destinations unavailable. File contents match the full demo above with `demo-lzh` replacing `demo-ste`.

Follow-up review checked Standards, then Spec, then Risk. Environment-mutating unit tests are serial and restore the previous value. The codec still has no config or git dependency. Recovery uses the per-worktree git dir rather than `.git` path concatenation or `--git-common-dir`. Existing no-replace publication and snapshot checks remain intact. Local hard-link publication requires the git dir and checkout to share a filesystem. Cross-filesystem moves or links fail without overwriting ticket files. No open Critical or Important finding remains in these two corrections.

The prevention is structural: recovery files live outside git's worktree, and the escript regression rejects checkout-local default resolution. Lesson: fixture convenience hid a runtime default, while keeping temporary files beside tickets made crash artifacts stageable. No lesson bead was created because this session forbids bd commands; the coordinator can record this lesson from the tests and report.

### Correction gates

```text
mix test test/board/ticket_file_test.exs test/board/ticket_store_test.exs test/board/ticket_cli_test.exs test/board/ticket_escript_test.exs
seed 8892
1 property, 46 tests, 0 failures
exit 0

python3 tools/ticket-files-demo.py
all commands succeeded; final check valid
exit 0

mix precommit --seed 921169
Repository hygiene: no license material or operator paths detected
Generated escript board with MIX_ENV=test
Finished in 35.0 seconds
5 properties, 330 tests, 0 failures
exit 0
```

The preceding unseeded `mix precommit`, seed 211785, hit the same disclosed clock-test timeout: 5 properties, 330 tests, 1 failure. No test assertion or timeout was weakened. The pinned rerun passed. `git diff --check` is clean. No commits, bd commands, installation changes, or service restarts were performed.
