# fm-reader — bb-axu.2

bb-axu.2 is implemented and verified. No commits, pushes, bd commands, subagents, installed-service changes, or installed-database access. The coordinator brief is untouched.

## What changed

- Config accepts `tickets = "files" | "beads"`, defaults to beads, and records files mode without probing `.beads`.
- `Foreman.TicketFiles` reads regular Markdown files, reuses `Foreman.TicketFile`, maps facts/sections/dependencies into the existing projection, and preserves malformed files' cached rows.
- `Foreman.TicketFiles.Reader` owns one non-recursive watcher, stable sampling, periodic recovery and guarded projection publication. Runtime admits files readers separately from beads export schedules.
- Beads jobs check the source again at publication, so an in-flight old-source job cannot overwrite a files repo after cutover. Files publication likewise rechecks active config under a database lock.
- Settings displays the source and per-file errors. Ticket detail displays checked/total acceptance and human-readable file dates. README documents the switch.

## Reader lifecycle

`ReaderMachine` declares `watching`, `settling`, and `stopped`:

1. A directory hint, startup, explicit rescan, or the 60-second timer moves watching to settling. Additional hints coalesce.
2. Samples are 100 ms apart. Unequal snapshots resample; two equal snapshots publish. CLI write/recovery locks refuse a snapshot rather than interpreting temporary missing paths as deletions.
3. Publication locks active config and the existing repo projection, checks the source/path/enabled identity, then rechecks the filesystem sample. Changed samples retry. A CLI lock retries after 500 ms, including when its release emits no ticket-directory event.
4. Valid files replace their cache rows. Invalid files retain their last good row by filename id, with a Settings error. Absent files leave the projection and mark overlays orphaned, never deleting process facts.
5. Watcher loss or directory identity change stops the reader. Runtime monitors it and starts a replacement. Runtime owns the reader supervisor, so Runtime teardown cannot strand duplicate readers.

An absent ticket directory watches its nearest existing parent until the directory appears; it never projects absence of the whole directory as an empty ticket set. Normal idle operation performs no file scan between 60-second ticks.

## Evidence

| Acceptance | Evidence |
| --- | --- |
| Per-repo switch; beads unchanged | Config default/override/rejection tests; complete existing suite passes; queued beads jobs and late publications reject files repos. |
| Main checkout, inotify, 60-second rescan, rename saves | Real linked-worktree resolver test; real inotify create/edit/rename/delete test; missed-hint test suspends the watcher and sends the periodic event; literal timer is 60,000 ms. |
| Existing identity and process facts | Database test preserves ticket primary key, building stage and non-orphan state, and compares sessions, stage events, approval requests and CR links byte-for-byte across replacement. No schema changes. |
| Acceptance checked/total | Codec test checks 1/2; LiveView checks 1/3; browser screenshot shows 1/2. |
| Last-good malformed file; Settings file/error | Temp-repo and projection tests; Settings LiveView test; browser corrupts the file, observes the named error, then checks the retained title and recovery. |
| Hand and CLI edits within 2 s | Final browser run: hand edit 384 ms, actual built `foreman update` 754 ms including CLI startup. |
| Temp-directory reader tests; precommit | Focused reader/codec/FSM run: 31 tests, 0 failures. Final full gate below: 5 properties, 369 tests, 0 failures. |

Browser server: `tools/reader-acceptance.exs`, port 4779, database `foreman_reader_acceptance_fm-reader`, freshly initialized temporary git repo. It runs the actual Runtime and reader. `tools/reader-acceptance.cjs` uses Playwright, the built escript, DOM assertions, screenshots and browser error checks. No page errors. The scratch server was stopped after verification.

Reproduce with:

```sh
mix assets.build
MIX_ENV=test PORT=4779 mix run --no-start --no-halt tools/reader-acceptance.exs
# In another shell, set NODE_PATH to an installed Playwright node_modules directory:
node tools/reader-acceptance.cjs
```

Screenshots inspected: `/tmp/fm-reader-ticket.png` and `/tmp/fm-reader-settings.png`. The final ticket screenshot has compact, aligned field rows and human dates. Settings wraps the full filename/error and keeps the Enabled control visible. The reproducible scripts remain in the worktree; screenshots are local artifacts.

## Review baseline

`cfe3d15e54a1042b5e58e81ef9961877b2f7f97d` equals HEAD. No commits since it; the three-dot diff is empty. The explicitly requested self-review therefore covers the working-tree diff and new files, excluding the coordinator brief.

## Standards

Reviewed first against both AGENTS files and the house baseline. Reader admission/coalescing/settling/stop is declared in `Foreman.TicketFiles.ReaderMachine`; filesystem and database operations interpret its effects. Runtime's reader registry is supervision plumbing, not a second ticket lifecycle.

- Important: the new file projection exposed ISO dates in the existing generic fields view. Fix with the shared timestamp component.
- Important: Settings error text inherited table nowrap and was clipped in the browser screenshot. Make the error wrap within its cell.
- Test-first coverage is incomplete: config, publication lock, projection date compatibility, progress rendering and Settings errors have observed failing assertions. Some reader adapter code and malformed-retention tests were written before their first run. Final tests do not erase that process gap.

Declined: existing generic beads field presentation outside the changed file-source path. Both presentation findings are fixed; timestamp regression observed red before the fix. A second screenshot caught formatter whitespace enlarging the field rows; moving pre-wrap onto the value span fixed it, and the browser now checks row height. No open Critical or Important implementation finding. Verdict: Ready.

## Spec

Reviewed second against bb-axu.2 and Decisions 7–8. The parser is reused, beads remains the default, files use main-checkout resolution, directory hints and a literal 60-second timer. Projection keeps `(repo, id)` and last-good malformed rows. Settings shows file-specific errors; ticket detail shows acceptance checked/total.

- Important verification gaps: add explicit main-worktree resolution, timer rescan, and source-switch retirement tests. The browser already verifies real CLI writes and hand edits, not only synthetic notifications.
- Screenshot polish: file bodies duplicated Acceptance under Description. Preserve arbitrary prose sections but exclude dedicated Acceptance and Notes from Description.

Declined: migration/count comparison, removal of beads, ten-minute all-repo idle measurement; those are later tickets. No intended scope change. Added main-checkout, missed-hint rescan, source retirement, and process-fact preservation tests. Description duplication is fixed with a failing regression. No open Critical or Important finding. Verdict: Ready.

## Risk

Reviewed third, including pinned `file_system`'s inotify options and backend exit behavior.

- Important, fixed: a sample collected before a newer edit could publish stale content after waiting for the projection lock. Revalidate the snapshot under the lock; retry a changed sample. The regression first published the old sample, then passed with `{:defer, :changed}`.
- Important, fixed: a CLI lock could outlive coalesced directory events and leave the reader waiting until the next minute. The declared retry transition now samples again after 500 ms; a real lock-release test needs no subsequent ticket-directory event.
- Important, fixed: keeping the reader supervisor as Runtime's sibling would leave readers alive after a Runtime restart. Runtime now owns its linked supervisor. A teardown test monitors reader, FileSystem worker, and supervisor; all exit.
- Important, fixed: replacing `tickets/` at the same pathname could leave inotify watching the old inode forever. Reconciliation compares device/inode and restarts the watcher. The pinned backend does not subscribe to move_self; whole-directory replacement therefore recovers on the 60-second rescan, while individual rename saves are immediate.

The load-bearing fact is that the existing projection identity and overlay tables are unchanged. Tests compare session, stage-event, request and CR-link rows before and after beads-to-files replacement, plus ticket primary key/stage/orphan marker. Malformed content retains its persisted previous row; deletion only orphans overlays. Proof level 4, with malformed retention and freshness also exercised in the browser at level 5.

Residual: stable double sampling is not a multi-file filesystem transaction. A hand editor that pauses on syntactically valid intermediate bytes longer than the settle window can expose that valid intermediate version. CLI multi-file publication is protected by its existing git-dir lock. No code acquires a writer lock or modifies ticket files. No claim of power-loss or network-filesystem guarantees.

Declined: changing the existing CLI recovery protocol, cross-machine filesystem locking, and migration itself. Cheapest gate: `mix precommit`, followed by the scratch browser script. The inode-replacement regression passes. No open Critical or Important finding within the supported local-filesystem contract. Verdict: Ready.

## Final gate

```text
$ mix precommit
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 556998, max_cases: 16
Generated escript foreman with MIX_ENV=test
Finished in 40.6 seconds (2.9s async, 37.6s sync)
5 properties, 369 tests, 0 failures
exit 0

$ git diff --check
exit 0

$ NODE_PATH=/tmp/bb-filters-browser/node_modules node tools/reader-acceptance.cjs
hand edit visible: 384 ms
CLI edit visible: 754 ms
Reader browser acceptance PASS; screenshots in /tmp/fm-reader-{ticket,settings}.png
exit 0
```

Initial dependency compilation emitted the already documented upstream Oban unused MySQL-clause warning. No dependency was changed or patched. Final application compilation and precommit emitted no warnings.

Changed: per-repo file-source configuration, worker reader/lifecycle, projection adapter, Settings errors and acceptance progress.

Verified: all bb-axu.2 behaviors through temporary filesystem, real inotify, database, LiveView and scratch-browser checks; final precommit is green. Review axes ran sequentially without subagents. No open Critical or Important implementation findings.

Not verified: deployment, actual repository migration, ten-minute idle CPU measurement, power-loss recovery or network filesystems. These are outside bb-axu.2. The stable-sampling limitation for deliberately paused hand writes is recorded under Risk; no cross-file atomicity claim is made.

## Coordinator correction: warning health and empty Overview content

The coordinator identified two Important presentation errors in the first screenshots. This section supersedes the initial UI acceptance and final gate above.

1. A successfully read folder with malformed files was reported as an outage. The reader now returns a distinct `{:warning, errors}` outcome only after successful projection. `SyncMachine` declares a warning state and records the read as successful. Errors remain a structured JSON list in the existing health reason column; Settings derives the count and displays amber `1 file error` (or plural), with the filenames and reasons below. The sidebar retains its ticket count. Folder-read failure still produces red unreachable/down. CLI publication contention now defers as `writing`, rather than falsely reporting an outage.
2. Overview exposed null/empty-list fields and empty relationship headings. The field selector now excludes nil, empty lists and empty strings. Dependencies and Linked CRs render only with content. The Acceptance section's raw checkbox text is unchanged.

Failing-first evidence:

- Settings LiveView test first failed because the warning outcome lost the named error. It now checks warning/count/no-down, then folder failure/unreachable/down in the same connected view.
- The Overview test first found the unwanted close-reason field. It now rejects close reason, labels, closed-at, Dependencies and Linked CRs when empty.
- The publication-lock regression first received error outcomes instead of deferred/writing; it now passes and still proves lock-release recovery without a subsequent directory event.

Focused verification: 44 reader/Settings/Overview tests passed before the lock classification adjustment; the subsequent reader/Settings run passed 9 tests. The final full suite includes all changes.

Browser rerun used the same isolated port/database setup and a fresh temporary repo. Hand edit: **285 ms**. Built `foreman update`: **751 ms**. The runner now also asserts absent empty fields/headings, a warning badge without sidebar down, missing-folder unreachable/down, and recovery after the folder returns. Whole-directory disappearance uses the documented 60-second rescan. No page errors.

Refreshed screenshots were opened and inspected:

- `/tmp/fm-reader-ticket.png`: only populated ticket fields, no empty relationship headings, Acceptance unchanged.
- `/tmp/fm-reader-settings.png`: amber `1 file error`, full wrapped filename/error, sidebar count `1`.
- `/tmp/fm-reader-unreachable.png`: red unreachable badge and sidebar down for an actually missing directory.

Follow-up review ran Standards, then Spec, then Risk. Standards: warning is a declared FSM state, not a display-only string override. Spec: both requested corrections are covered in LiveView tests and the browser. Risk: warning classification cannot mask a failed projection; failures retain their error outcome, and write contention retains the existing retry path. Existing nonempty fields/relationships and beads tests remain green. No open Critical or Important finding in these corrections.

Lesson: I treated any error as an outage and checked screenshot readability without checking whether the status and empty content made sense. Prevention is structural (rung 1): distinct warning versus failure outcomes and one empty-field filter, backed by LiveView and browser regressions. No lesson bead was created because this session prohibits bd commands; the coordinator can record it from this report.

### Correction final gate

```text
$ mix precommit
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 175725, max_cases: 16
Generated escript foreman with MIX_ENV=test
Finished in 40.8 seconds (2.8s async, 37.9s sync)
5 properties, 370 tests, 0 failures
exit 0

$ git diff --check
exit 0

$ NODE_PATH=/tmp/bb-filters-browser/node_modules node tools/reader-acceptance.cjs
hand edit visible: 285 ms
CLI edit visible: 751 ms
Reader browser acceptance PASS; screenshots in /tmp/fm-reader-{ticket,settings}.png
exit 0
```

The scratch server was stopped after verification. No commits, pushes, bd commands, subagents, installed-service changes or installed-database access. Previously disclosed deployment and filesystem limits are unchanged.
