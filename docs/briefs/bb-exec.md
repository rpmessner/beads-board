You are a build session in beads-board (~/dev/utils/bb-exec, a git worktree on branch `bb-exec`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
This is part 4b-3 and should finish bb-c2w.4. Merged so far: 4a (config, reload machine, hygiene; docs/sessions/bb-shell.md), 4b-1 (runtime, export decoding, journal lock, projection; bb-read.md), 4b-2 (read and schedule machines, BOARD_ROLE web/worker/all, Postgres-backed events; bb-sync.md). The machines exist and are tested as pure tables; what is missing is everything that makes them run. Read bb-sync.md "Continue here" and build: the effect executors (the real bd export subprocess with timeout, cancel and reap; the periodic scheduler; physical path resolution and per-store admission), the config watcher wired through the reload machine in the worker role, configured-repo sync status and broadcasts, Fluxon wiring, the app shell and the Settings view per the approved mockup, then the real-repo acceptance. Do not redo merged work.

**Pace: do not stop early.** Previous sessions handed off at about half their context with the ticket unfinished. Keep working until every Done-when item is met, or until your context is genuinely near its limit (above about 85%), and only then stop at a clean, green point with a precise list of what remains. Building pure tables without their executors is not a stopping point.

The app boots, knows which repos to read from its config, and keeps a live, droppable projection of every configured beads repo without ever disturbing an agent's `bd` write; the Settings view shows what it sees. This is the foundation every view and the agent CLI build on (spec Decisions 1-5, acceptance checks 1, 2, 2a, 10 and the precommit half of 11).

## Read first
- AGENTS.md (the generated Phoenix guidelines) and ~/dev/AGENTS.md Elixir house rules.
- docs/spec.md (authoritative; Decisions 1-5, 13, 14 and the checks named above), docs/design.md sections 3-5 and 7 (architecture, reading beads, data model, config shape), docs/probe-bd-concurrency.md and docs/sessions/bb-probe.md (the read rule you must implement).
- The approved mockup: docs/mockup/Settings.dc.html and Main.dc.html (layout and Fluxon styling for the Settings view and the app shell).
- lib/board/fsm.ex and docs/sessions/bb-fsm.md (the DSL; any stateful part you add sits on it).

## Tickets
bb-c2w.4. The coordinator has already claimed it; do not run bd in this worktree. Splitting again is allowed only near the context limit, as described in the Goal.

## Skills
- `tdd` at these seams: config load/validate/merge (global + local override + shipped defaults; unknown stage names and bad TOML are errors that keep the last good config); the bd export reader against fixture exports (normalisation, unknown values, unreachable repo); the sync job (hash skip, projection upsert and delete, orphan marking) against a scratch copy of a real repo; the read rule from the probe.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 3f0de68e528ba3ae23ec935d36ddb89ae83cc70f before printing the marker: Standards (the house baseline: workflows, sync and job pipelines, connection to external systems and resource lifecycles must sit on declared Board.Fsm machines; status fields interpreted by case chains are Important findings), Spec (bb-c2w.4 acceptance), Risk (persistence, a config contract, concurrency with agents' bd writes). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding, then re-run the gates.

## Decisions already made
- Stack: Oban (Postgres engine) for every external read; versions as gw2 pins (Oban 2.23.0, Req 0.6.1). Bound to 127.0.0.1.
- Fluxon UI 3.x from its private hex repo; the license comes from environment variables FLUXON_LICENSE_KEY and FLUXON_KEY_FINGERPRINT. The hex repo is already configured in ~/.hex. Never print, copy or commit license material or the path of any file holding it; add a `mix precommit` guard that fails on license material or local operator paths.
- Storage is Postgres only (database beads_board_dev / _test on the local server). The only non-database files are the TOML config (settings) and the API token (a later ticket).
- Config: global `~/.config/beads-board/board.toml` plus an untracked `board.local.toml` beside it, merged over defaults shipped in priv/; home-relative paths. Do not create or edit those files in the user's home: tests use temp dirs; document the shape in the README. Hot reload by directory watch; a bad edit keeps the last good config and shows the error.
- Reading beads: one `bd export` per repo per sync; cheap file signals every few seconds plus a 5-minute sweep; an unchanged export hash is a no-op; never copy or write a store; never start a Dolt server (we_go_next_dev shows unreachable). The board is failure tolerant and never interrupts an agent's bd write: follow the probe's read rule exactly.
- Unknown bd statuses, types and dependency types map through explicit tables; never String.to_atom.
- Settings view per the approved mockup: config source, validation result, reload, repos with sync state, repos found under ~/dev with a `.beads` dir but not configured (with the TOML block to paste).

- Coordinator decisions already given: the Oban 2.23.0 unused-clause dependency warning is accepted (recorded in the README). You are authorised to run read-only `bd export` and `bd list --json --all` against the real configured repos; every bd write (the 10-minute concurrent-write acceptance, the note freshness check) runs only on scratch copies under /tmp/bb-exec/. Deployment is two systemd user units (web, worker) from one release; the unit files themselves are ticket bb-c2w.10, not this one.
- Fluxon: run mix deps.get against the private repo already configured in ~/.hex. If it fails for lack of credentials, stop that part only, say exactly what failed, and continue the rest with a plain Phoenix layout styled to the mockup's tokens so Fluxon can be swapped in.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree; do not touch the user's home config, dotfiles or other repos. Use /usr/bin/rm, not rm. Spawn no subagents.
- Zero compile warnings; mix precommit green.

## Done when
- `mix precommit` green; LiveView test for Settings; the sync runs against scratch copies of every real repo (counts match `bd list --all`; we_go_next_dev unreachable), and a `bd note` in a scratch copy shows in the projection within the target.
- The probe's agent-write loop against the running sync: zero failed writes over 10 minutes.
- A screenshot of Settings, light and dark, compared with the mockup.

## Report back
Write docs/sessions/bb-exec.md: what changed, the read rule as implemented, config shape, evidence for each acceptance item, review findings per axis with what you fixed and what you left open, final gate output. Then print BB-EXEC DONE alone on the last line.
