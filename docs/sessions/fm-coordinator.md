# fm-3c3.6 coordinator session

## Changed

`foreman coordinator` resumes the singleton conversation or creates one; `--fresh` replaces it and `--adopt <uuid>` records it without launching. The authenticated service checks the requesting tmux socket and pane before replacing that pane. Claude runs in `~/dev/music` with `/orient` and the existing per-launch hooks.

`Sessions`, `SessionMachine`, `SessionTmux`, the command handler and waiting-request routing now recognize the reserved `__foreman__/coordinator` identity. It needs no project, ticket overlay or migration. The FSM owns resume/fresh/adopt eligibility and prevents idle parking. The Initiatives page shows state, Focus, Relaunch and a separately confirmed Start fresh.

See [usage and tmux gotchas](../coordinator.md).

## Evidence

- Failing-first checks covered FSM eligibility/no-parking, Sessions identity selection, CLI argv decisions and LiveView controls. Additional regressions reproduced transaction refusal and adoption-collision errors before their fixes.
- The real built escript called an isolated HTTP endpoint from a scratch tmux pane. Stub Claude printed its arguments. First launch, repeat resume, fresh and adopt passed: [transcript](../acceptance/fm-coordinator/tmux-transcript.txt).
- The integration suite clicked board Focus/Relaunch against scratch tmux, checked the resumed UUID, invoked the real `session-hook StopFailure` command, found its usage-limit request on Needs you and verified that Continue sent exactly `continue` plus Enter. A zero-second idle limit left the coordinator ended, not parked.
- [Risk regression run](../acceptance/fm-coordinator/risk-tests.txt): 55 tests passed, including existing planning-session, tmux, waiting and CLI transport tests.
- Playwright checked connected LiveView controls, overflow and browser errors. Inspected screenshots: [1440 light](../acceptance/fm-coordinator/board-1440-light.png), [1440 dark](../acceptance/fm-coordinator/board-1440-dark.png), [390 light](../acceptance/fm-coordinator/board-390-light.png), [390 dark](../acceptance/fm-coordinator/board-390-dark.png). Controls remain readable and fit on mobile. Browser fixtures live only in the preview database; functional launch checks used scratch tmux.

## Sequential self-review against 3505996

### Standards

One Important finding, fixed. `Sessions.prepare_coordinator/2` originally checked active states outside the machine and reset through `:new`. Declared coordinator transitions now select identity effects and reject active launches. The pure-step regression passed after failing on the missing transition. No open Standards findings.

### Spec

No remaining acceptance gaps. Reviewed against fm-3c3.6 and the parent launcher decisions. Declined dotfiles, service startup and the contents of the external `orient` skill, as instructed. No open Spec findings.

### Risk

Fixed three Important findings:

1. Nested launch rollback left the receipt writer inside an aborted transaction. The command boundary now rolls back before writing a receipt and returns the refusal cleanly.
2. Adopting another planning session's UUID raised a constraint error. It now returns `session_id_in_use` without changing either identity.
3. Unknown coordinator hooks could enter external-session fallback. They now return `unknown_session` before consulting an external tmux server.

The safety checks ran real code: failed fresh launch preserves the prior identity, active launch refuses replacement, and existing planning launch/parking/resume tests pass. No Critical or Important finding remains open.

Residual operational risk: tmux and Postgres cannot commit atomically. A hard service crash between pane replacement and database commit may require adopting the UUID retained in the tmux window option. Crash-injection recovery across all session launchers is a follow-up candidate for the coordinator, not a verified guarantee here.

## Preview and handoff

Ownership verified with `devserve ls --json`:

- Owner: `fm-coordinator`
- Unit: `devserve-foreman-fm_coordinator-2f7e0503542c.service`
- URL: http://127.0.0.1:4880
- Database: `foreman_preview_fm_coordinator_2f7e0503542c`
- Worktree: `~/dev/utils/fm-coordinator`

Preview remains running for coordinator close-out. No commits, pushes, releases, installs or real-Claude launches. Live tmux and the installed coordinator were untouched. The coordinator owns ticket closure.

## Final gate

[Full output](../acceptance/fm-coordinator/precommit.txt): `mix precommit` passed with zero warnings, **5 properties, 579 tests, 0 failures**. `foreman check` and `git diff --check` also passed.

Not verified against a real Claude account, by instruction. The external `orient` skill remains the parallel skills session's responsibility.
