You are a build session in beads-board (~/dev/utils/bb-probe, a git worktree on branch `bb-probe`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Find out whether the board's planned way of reading beads (`bd export` per repo, every few seconds) can make an agent's concurrent `bd` write fail on the embedded Dolt store, and turn the answer into a read rule the reader will implement. The user's rule is fixed: the board is failure tolerant and never interrupts an agent's bd write. This probe decides how the reader honours it.

## Read first
- docs/spec.md (Decision 5, acceptance checks 2 and 2a) and docs/design.md sections 2 and 4 (what bd's reads write, the change signals).
- `bd --help`, `bd export --help`, and how a bd process opens the embedded store (look for lock files under `.beads/` while a command runs).

## Tickets
bb-c2w.1. The coordinator has already claimed it; do not run bd against this worktree's own store, and run no bd commands in any real repo except read-only `bd --help`.

## Skills
- `tdd` at these seams: none. This is a probe: the evidence is measured runs, not unit tests.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against e6cf1a0335bc077e31b80a0da4a644c1781bac25 before printing the marker: Standards and Spec axes (Spec = bb-c2w.1 acceptance), plus Risk (concurrency). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Agents' writes always win. If reads can break writes, the reader skips while a write is visible (if a lock or marker is detectable) or polls less often, and the freshness target relaxes from 5 s to 30 s. The store is never copied for reading by the board and never written by it.
- Probe on scratch copies only: copy a real repo with an embedded store (e.g. ~/dev/music/form-engine, and the large ~/dev/games/wow-addons/ui-o-matic) into a directory under /tmp/bb-probe/, and run everything there.

## Rules
- No commits, no pushes, no bd writes anywhere except inside /tmp/bb-probe copies. Do not edit any real repo or its .beads. Stay in this worktree for files you keep.
- Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- A script (kept under tools/ in this worktree) reproduces the probe: an export loop at the board's cadence and faster, against a loop of agent-style writes (create, update, note, close, plus dependency add), for at least 10 minutes per scenario, on both repo copies.
- Counts of failed writes and failed reads with their exact error text; whether bd retries internally; whether a lock is visible from outside and how.
- A written rule in docs/probe-bd-concurrency.md: which read strategy the reader uses, why, and the freshness target it can promise. If writes never failed, say so with the numbers.

## Report back
Write docs/sessions/bb-probe.md: what you ran, the numbers per scenario, the chosen read rule, review findings per axis with what you fixed and what you left open, anything else open. Then print BB-PROBE DONE alone on the last line.
