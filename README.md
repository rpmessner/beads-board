# beads-board

A local board for every beads repo on this machine, organised around epics.
The Phoenix scaffold, `Board.Fsm`, and config validation core are implemented.
Runtime config watching, product views, and storage are not wired yet (bb-c2w.4b).

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

`mix test` and `mix precommit` do not start the Repo or create, migrate, or query a database.
`config/test.exs` disables `:start_repo`; enable it and restore database setup when adding persistence tests.
`Board.Stage` is the production pure machine; its persistence effects are not wired yet.
Epic remains a test fixture. Generated docs live in `docs/machines/` and tests compare them byte-for-byte.
Elixir 1.19 scans both `.ex` and `.exs` under `test/`; manually loaded fixture files outside `test/support/` use the `_helper.exs` suffix to avoid discovery warnings.

To run the Phoenix scaffold with Postgres, configure `config/dev.exs`, then run `mix setup` and `mix phx.server`.
Unlike the test commands, `mix setup` creates and migrates a database. The development endpoint still listens on `127.0.0.1:4000`.
The foundation continuation must change the database names and port before running the product.

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
