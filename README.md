# beads-board

A local board for every beads repo on this machine, organised around epics.
The worker reads configured repos through Oban and keeps a droppable Postgres
projection. Settings shows config validation, sync health, columns and discovered
repos using Fluxon 3. Initiatives, ticket/epic workflows and the agent CLI remain
later slices; `/` currently opens Settings.

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
requires `DATABASE_URL`, plus `SECRET_KEY_BASE` for web/all; no systemd unit is installed.

## Deployment roles and notifications

One release supports two systemd user services, `beads-board-web` and
`beads-board-worker`, without Erlang clustering. Set `BOARD_ROLE=web` in the web
unit and `BOARD_ROLE=worker` in the worker unit. Both use the same database and
Oban schema prefix. Set `RELEASE_DISTRIBUTION=none` in both release units.
`BOARD_ROLE=all` is the default for development and tests; unknown values fail boot.
Role and code changes require a service restart; only TOML configuration is
hot-reloaded. Do not use development code reloading as a worker deployment path.

- Web starts Phoenix and a queue-less Oban instance for Postgres notifications.
  It disables Oban plugins and leadership. It must not start readers or watchers.
- Worker starts Oban queues, the nominal scheduler and config directory watcher,
  but no Phoenix endpoint. Runtime readers are disabled in the test environment.
- Both start Repo. Phoenix.PubSub remains for endpoint internals, not cross-role
  product events. DNS clustering is not started.

`Board.Events` publishes versioned `config_changed`, `sync_status_changed`, and
`projection_changed` invalidations through `Oban.Notifiers.Postgres`. Subscribers
receive `{:notification, :board_events, payload}`. Changed projection transactions
publish at commit; unchanged export hashes publish nothing. A rolled-back
transaction cannot notify. Tests exercise independent notifiers and a raw
Postgres LISTEN connection, not an in-memory notifier replacement.

Notifications are transient. Settings fetches Postgres on mount and every three
seconds to recover missed notifications. Config installation and validation are
persisted before publication. `Board.Runtime.ping/1` sends a `sync_requested`
notification across roles; it uses the same admission path as ticks and sweeps.
Release packaging and installed systemd units remain later work.

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
It never acquires a store lock. `SyncJob` executes this check before each export.
The probe's [read rule](docs/probe-bd-concurrency.md) remains mandatory.

Oban 2.23.0 emits an unused MySQL-pattern compiler warning on Elixir 1.19 when
MyXQL is absent. The required pin is retained without suppressing the warning or
adding an unused database driver. App compilation and precommit can be checked
independently; a fresh dependency build still has this upstream warning. The
coordinator accepted this pinned-dependency warning; application code must still
compile with zero warnings.

`Board.Beads.Read` and `Schedule` now define the pure read/admission protocols,
with declared machines and generated goldens. Read timeout retains admission
until the owned subprocess is reaped and discards late stdout. Schedule accepts
three-second ticks even without changed signals, coalesces busy requests, and
never launches catch-up reads on completion. Tokens include an owner epoch and
generation so stale completions cannot release a newer flight. These modules
perform no IO. `Runtime` executes schedule effects; `SyncJob` executes read effects.
Physical aliases share a catalog identity and one scheduled export, projected to
all their configured keys. Postgres advisory admission plus a Linux abstract
socket prevent concurrent exports across workers, including the BEAM-death/reap
window. Neither lock touches the store or creates a file.

The bundled Python guardian owns a fresh process group, enforces a 20-second
limit and 32 MB stdout cap, kills only its group, and reaps before replying.
Owner/port death cancels it; partial or timed-out output never projects. Linux,
Python 3, `realpath`, `inotifywait`, and the tested bd binary must be on the service
PATH. Embedded-only reads reject redirects, ambiguous locks and server mode;
there is no repair, store copy, JSONL fallback or Dolt-server startup.

Every enabled physical store gets a nominal three-second request even without a
changed signal. This replaces the insufficient signal-only heuristic, rather
than watching Dolt files that exports themselves modify. Five-minute sweeps and
pings coalesce; completion never queues catch-up work. Unchanged exports make no
projection or health writes (unless health is recovering). Oban's own job records
still change. Settings labels snapshot age separately from health; it does not
pretend an unchanged snapshot was freshly written.

## Config contract

The worker reads `~/.config/beads-board/board.toml`, then
`board.local.toml` beside it, over `priv/board.defaults.toml`. The app never writes
these files. No user files are needed to run the tests; they use temporary directories.
`BOARD_CONFIG_DIR` overrides the directory for isolated runs; `BOARD_DISCOVERY_ROOT`
overrides the default `~/dev` discovery root. Non-recursive directory notifications handle
atomic editor saves; a 30-second reconciliation recovers missed notifications.
If the config directory is absent, the watcher follows its nearest existing
parent and moves to the config directory when it appears.
Discovery skips symlinks and build/dependency trees and is bounded to eight levels.
No home config is created. Accepted config, last error, load time and physical
store catalog live in Postgres so web-only nodes need no filesystem access.

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
`ReloadJob` executes this contract transactionally. Worker restarts enqueue a new
reload; a failed job cannot leave an in-memory reload stuck in loading. The
previous persisted config survives. A shared row lock at projection commit
rejects late results for removed, disabled or repointed config entries.

## Scratch acceptance

Only run these with permission to write scratch copies. They never open original
stores with bd. Server-mode acceptance uses copied metadata, not live PID/port files.

```sh
python3 tools/prepare-board-acceptance.py
BOARD_CONFIG_DIR=/tmp/bb-exec/config BOARD_DISCOVERY_ROOT=/tmp/bb-exec/repos mix phx.server
# In another shell, with the board running:
python3 tools/board-write-acceptance.py
python3 tools/verify-board-acceptance.py
```

The writer runs for ten minutes, without retrying failed writes. Verification
compares `bd list --json --all --limit 0`, checks persisted notes/dependencies and
measures idle note freshness. Raw artifacts stay under `/tmp/bb-exec`; see
[the session report](docs/sessions/bb-exec.md) for measured evidence. The harness
uses `psql -X` to ignore personal psql settings. Python bytecode caching is disabled
because embedded operator paths in `.pyc` files correctly fail the hygiene gate.

Fluxon is fetched from the preconfigured private Hex repo. Keep its authentication
and `FLUXON_LICENSE_KEY` / `FLUXON_KEY_FINGERPRINT` in the environment, never here.
The CSS theme and JS hooks are bundled through app.css/app.js, with no CDN scripts.

## Repository hygiene

`mix precommit` runs `mix board.hygiene` over tracked and nonignored untracked
files. The guard rejects local operator paths, literal Fluxon license assignments,
and exact license environment values when present. It reports categories only,
never matching content or secret paths. It does not read credential files.
Without those environment values, unlabelled license blobs cannot be identified
reliably; the guard is a safety net, not a general secret detector. Never put
license material into the repository, including ignored files.
