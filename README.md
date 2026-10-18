# beads-board

A local board for every beads repo on this machine, organised around epics.
The Phoenix scaffold, `Board.Fsm`, config validation core, Oban/Postgres bootstrap,
and export projection are implemented. Automatic repo reads, runtime config
watching, Fluxon, and product views are not wired yet (bb-c2w.4 continuation).

- [Approved MVP spec](docs/spec.md) is authoritative.
- [Design](docs/design.md) records the design pass and rationale.
- `docs/mockup/` contains the approved epic-first design canvas.
- [FSM build report](docs/sessions/bb-fsm.md) documents the DSL and compile checks.

## Check the scaffold and DSL

```sh
mix deps.get
mix precommit
MIX_ENV=test mix board.fsm.docs
```

`mix test` and `mix precommit` create and migrate `beads_board_test` on local
Postgres and start Repo and Oban. Database tests use the SQL sandbox; test jobs
run only when explicitly requested. `MIX_TEST_PARTITION` adds a database suffix.
`Board.Stage` is the production pure machine; its persistence effects are not wired yet.
Epic remains a test fixture. Generated docs live in `docs/machines/` and tests compare them byte-for-byte.
Elixir 1.19 scans both `.ex` and `.exs` under `test/`; manually loaded fixture files outside `test/support/` use the `_helper.exs` suffix to avoid discovery warnings.

To run the Phoenix scaffold with Postgres, configure `config/dev.exs`, then run `mix setup` and `mix phx.server`.
Development uses `beads_board_dev` and listens on `127.0.0.1:4747` (`PORT` overrides
the port, not the loopback bind). Migrate before starting Oban. Production still
requires `DATABASE_URL` and `SECRET_KEY_BASE`; no systemd unit is installed.

## Export projection boundary

`Board.Beads.Export.decode/1` validates a complete JSONL export, keeps raw fields,
and normalizes known enums through explicit tables. Unknown enum strings become
`{:unknown, value}`. Bad records reject the entire export, never a partial snapshot.
`Board.Beads.Projection.replace/2` takes a repo key and successful export bytes;
call it only after the reader has checked the command's exit status. It hashes
bytes and skips all projection writes for an unchanged hash. Changed exports
replace that repo's JSONB bead rows in a transaction. Embedded comments and edges
remain in `raw`; separate indexed edge/comment tables are not needed yet.

The `tickets` table reserves the overlay identity and stage fields. Projection
replacement marks missing tickets orphaned and clears the marker on reappearance,
without changing stages or deleting facts. Stage backfill remains unimplemented.
To rebuild the cache, delete its `bead_repos` row (cascading to `beads`), not only
its bead rows; the hash belongs to that same cache. Overlay rows have no cache FK.

`Board.Beads.JournalLock.check/2` passively matches journal device/inode against
Linux `/proc/locks`. Missing, unreadable or ambiguous evidence defers the read.
It never acquires a lock. This observer is **not a reader**: physical-repo single
flight, scheduled exports, subprocess cancellation/reaping, and Oban read jobs
must be implemented before wiring it to configured repos. The probe's
[read rule](docs/probe-bd-concurrency.md) remains mandatory.

Oban 2.23.0 emits an unused MySQL-pattern compiler warning on Elixir 1.19 when
MyXQL is absent. The required pin is retained without suppressing the warning or
adding an unused database driver. App compilation and precommit can be checked
independently; a fresh dependency build still has this upstream warning.

## Config contract

The intended runtime reads `~/.config/beads-board/board.toml`, then
`board.local.toml` beside it, over `priv/board.defaults.toml`. The app never writes
these files. No user files are needed to run the tests; they use temporary directories.
The runtime watcher and Settings view are still pending.

```toml
[board]
swimlanes = "project" # project | epic | none
stale_session_after = "2h" # positive integer with s, m, h, or d

[[repos]]
key = "sample"
path = "~/dev/sample"
github = "example/sample" # optional
forge = "github" # github | none; inferred from github if omitted
color = "violet"
enabled = true

[[columns]]
title = "Working"
stages = ["dispatched", "building"]
collapsed = false

[backfill]
closed = "done"
default = "queued"

[epics."sample-123"]
pin = true
collapse = false
color = "violet"
```

Tables merge recursively. A supplied `columns` array replaces all inherited
columns. Repo entries merge by `key`, preserving order; a local entry can contain
only `key` and `enabled = false`. `repos = []` clears the inherited list. Defaults
ship **no repos**, so a fresh install never opens a store without configuration.
Missing user files are optional; unreadable files, malformed TOML, unknown options,
duplicate keys/expanded paths, and unknown ticket stages are errors. Paths must be
absolute or start with `~/`; no environment-variable expansion occurs. Path
validation does not open or resolve repository stores or symlinks.

`Board.Config.load(directory)` returns `{:ok, config}` or `{:error, message}`.
All keys and configured enum values remain strings. `Board.Config.parse_layers/2`
accepts named TOML contents for pure tests. Validation uses `Board.Stage`'s declared
states, not an independent stage list.

`Board.Config.Reload` holds the last good config through its declared machine.
Its read/broadcast effects are data, not executed callbacks. The runtime must run
reads through Oban and supply every terminal result, including job failure, before
another reload can start. Bad edits retain the previous config and expose an error.
This contract is tested; it is not yet connected to the application supervisor.

## Repository hygiene

`mix precommit` runs `mix board.hygiene` over tracked and nonignored untracked
files. The guard rejects local operator paths, literal Fluxon license assignments,
and exact license environment values when present. It reports categories only,
never matching content or secret paths. It does not read credential files.
Without those environment values, unlabelled license blobs cannot be identified
reliably; the guard is a safety net, not a general secret detector. Never put
license material into the repository, including ignored files.
