# fm-format: fm-axu.8

Implemented in the `fm-format` worktree without commits, pushes, ticket edits, bd writes, real-repo edits, or installed-board changes. The coordinator's brief is untouched.

## Changes

- `TicketFile` accepts `chore` and the `supersedes` id list. Older files default the missing list to `[]`; canonical writes include it after `related`. Explicit nulls and invalid ids are rejected.
- `TicketCLI` supports `--supersedes` on new/update, sorted JSON output, clearing the list, and reference rewrites during renumber. Absent supersedes targets do not block validation or readiness.
- `BeadsConversion` maps convoy to epic and tracks to related. Chore and supersedes keep their names. The independent comparison maps source kinds before comparing edges and types. Lists retain duplicate edges so a tracks edge and related edge to the same target are both counted.
- `TicketFiles` projects supersedes into the existing dependency display. A LiveView regression loads an actual ticket file and asserts that the sheet displays `supersedes · demo-old` even when that target is absent.
- Decisions 3, 6 and 10 in `docs/specs/ticket-files.md` record these rules. `tools/adopt-format-dry-run.py` repeats the three export replays without contacting a live beads store.

## Standards

Self-review baseline is `5e35ddf60f2700c43697609394566dd5e36c56ab`, which still equals HEAD. The three-dot diff and commit list are empty because commits were forbidden. This review covers the working-tree diff and new replay script instead.

Reviewed against both AGENTS files, `.formatter.exs`, and the house standards baseline. Changes stay in the codec, CLI, conversion/comparison, and reader boundaries. No workflow or lifecycle changed, so no new state machine is needed. Existing adoption and ticket-status machines remain unchanged. The comparison deliberately keeps its independent projection rather than sharing the conversion implementation.

No open Critical, Important, or Minor finding. Declined to judge unrelated UI styling and existing adoption filesystem mechanics. Standards verdict: Ready.

## Spec

Reviewed the ticket and Decisions 3, 6, and 10 after Standards. All requested mappings, validation rules, round trips, comparison checks, and sheet display are covered. The optional-field rule preserves existing files without mass ticket edits. The CLI flag and renumber support keep supersedes usable after migration.

The supplied `dry.py` runs `bd export` in the real repo and calls the installed CLI. Running it unchanged would violate this session's boundaries. The new replay script follows its scratch-clone/config sequence but reads the supplied exports and clones the already-existing scratch clones. It uses this worktree's escript, refuses existing destinations, checks per-ticket relation multiplicities independently, and verifies file hashes across the no-op rerun.

No open finding. Declined to judge real cutovers and live board overlay/history preservation; those remain coordinator-owned. Spec verdict: Ready.

## Risk

The safety fact is that every mapped edge survives conversion with its multiplicity, while only the two approved kind renames change meaning. Comparison still rejects changed fields, lost prose, missing tickets, unsupported relations, and incomplete comments. The new fixture combines tracks and related edges to the same target and proves that dropping one fails comparison. The replay independently compares all mapped edge triples from the exports against CLI output. This reaches proof level 4 for conversion and level 5 for the built CLI workflow.

Fresh review gate: `mix test test/foreman/beads_conversion_test.exs test/foreman/ticket_file_test.exs test/foreman/ticket_cli_test.exs` passed with 1 property, 34 tests, zero failures, seed 251279. The built escript also checked this worktree's unchanged legacy `tickets/` successfully with `valid: true` and no errors.

No open implementation finding. Release constraint: older CLI/readers reject chore or supersedes, so integrate and update the CLI and reader before the real cutovers. Declined to judge a live Dolt export, production deployment, power-loss recovery, and concurrent source writers. These were not exercised or changed. The cheapest merge gate is `mix precommit`; the saved-export replay checks the actual migration boundary. Risk verdict: Ready within the scratch, quiescent-export contract.

## Failing-first evidence

Logs remain under `/tmp/fm-format-*.log`.

- Codec tests failed on unknown `supersedes` keys, then passed with chore round trips and invalid-list checks. Initial test setup needed `mix deps.get` because this worktree had no dependencies.
- CLI tests failed on the unsupported `--supersedes` option, then passed for new/update, clearing, absent targets, readiness, and renumber.
- Conversion failed with `unsupported dependency type` for the combined tracks/supersedes fixture, then passed with multiplicity and type assertions.
- The file-to-sheet test first needed a git repo in its fixture. After correcting setup it failed on the missing supersedes DOM text, then passed after the reader projection change.
- The first replay stopped on an overly strict backup byte comparison. Adopt re-encodes JSON key order; the saved records were identical. The replay now compares decoded records. No production code changed for that verifier correction, and the first scratch directory remains intact.

## Verification

`mix test` over the codec, store, CLI, converter, files reader, and initiatives LiveView passed with 1 property, 95 tests, zero failures, seed 346245. The sheet assertion uses the existing Dependencies display; no template redesign was needed.

`mix escript.build` produced this worktree's executable. Then:

```sh
python3 tools/adopt-format-dry-run.py "$EXPORTS" /tmp/fm-format-replay-2
```

`EXPORTS` is the read-only export directory supplied in the dispatch brief. Each repo passed comparison, `foreman check`, and a rerun with `changes: []` and unchanged file hashes.

| Repo | Tickets | Comments | Mapped relations |
| --- | ---: | ---: | --- |
| dotfiles | 3 | 0 | none |
| ui-o-matic | 417 | 442 | parent-child 140, blocks 91, related 201, discovered-from 2, supersedes 1 |
| cooldown-o-matic | 47 | 13 | parent-child 40, blocks 31, related 3, supersedes 2 |

The 201 ui-o-matic related edges are its 189 related plus 12 tracks. Both convoys became epics. All four chore tickets retained their type across the three exports.

Evidence is under `/tmp/fm-format-replay-2/<repo>-config/`: `first.json` includes the complete diff and backup paths; `comparison.txt`, `summary.json`, and `rerun.json` record the checks. Tarballs and export sidecars remain in each config's `backups/`. The stdout log is `/tmp/fm-format-replay-2.log`.

Final full gate:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
seed 567503
5 properties, 564 tests, 0 failures
exit 0
```

The final log is `/tmp/fm-format-final-precommit.log`; the earlier full gate also passed at seed 765278. `git diff --check` passed. No ticket file changed. Initial dependency compilation emitted the existing Oban unused-clause warning; the full gate emitted no warnings.

Changed: ticket format, CLI, conversion/comparison, file-reader projection, tests, spec, and repeatable replay tool.

Verified: all requested behavior through unit/property tests, the LiveView DOM, all three saved-export migrations using the built escript, and the full precommit gate.

Not verified: live store export, real migrations, installed CLI/reader rollout, or browser pixel inspection. No real repo, global config, installed executable, or board service was changed.

Review summary: Standards 0 findings; Spec 0 findings; Risk 0 implementation findings, with the coordinated-rollout constraint above. No commits or ticket closure performed.
