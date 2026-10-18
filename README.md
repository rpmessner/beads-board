# beads-board

A local board for every beads repo on this machine, organised around epics.
The Phoenix scaffold and `Board.Fsm` library are implemented. Product views and storage follow in later tickets.

- [Approved MVP spec](docs/spec.md) is authoritative.
- [Design](docs/design.md) records the design pass and rationale.
- `docs/mockup/` contains the design canvas, pending the epic-first revision before views are built.
- [FSM build report](docs/sessions/bb-fsm.md) documents the DSL and compile checks.

## Check the scaffold and DSL

```sh
mix deps.get
mix precommit
MIX_ENV=test mix board.fsm.docs Board.Fixtures.Stage Board.Fixtures.Epic
```

`mix test` and `mix precommit` do not start the Repo or create, migrate, or query a database.
`config/test.exs` disables `:start_repo`; enable it and restore database setup when adding persistence tests.
Stage and epic are test fixtures only. Generated docs live in `docs/machines/` and tests compare them byte-for-byte.
Elixir 1.19 scans both `.ex` and `.exs` under `test/`; manually loaded fixture files outside `test/support/` use the `_helper.exs` suffix to avoid discovery warnings.

To run the Phoenix scaffold with Postgres, configure `config/dev.exs`, then run `mix setup` and `mix phx.server`.
Unlike the test commands, `mix setup` creates and migrates a database. The development endpoint listens on `127.0.0.1:4000`.
