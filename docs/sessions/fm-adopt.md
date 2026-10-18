# fm-adopt — fm-axu.3

Implemented for coordinator review. No commits, bd writes, installed-service changes, or real cutover.

## Standards review

Baseline: `fb24954220996328ae5e8f5f94450984c1a53757` equals HEAD. The three-dot diff and commit list are empty. This requested self-review covers the working-tree changes and new files, excluding the coordinator's brief.

Read both AGENTS files and the house baseline. The approved ticket-files spec supersedes the older Postgres-only ticket rule. `AdoptMachine` declares the ordered migration phases; conversion and configuration stay outside the web/worker. Input keys remain strings. Tests use isolated temporary repositories and config directories.

Important: unconditional hook chmod and `git config` rewrote metadata on an otherwise unchanged rerun. Fixed by checking current mode and value before writing. The escript rerun test checks an empty change list; the final dry run also compares file contents.

Minor: some filesystem/escript safety tests were added after implementation, rather than observed failing first. Converter, comparison, config append, initial adopt steps, old-hook cleanup and symlink refusal have observed assertion failures followed by passing checks. This process gap does not disappear when the suite passes.

Declined: existing UI, reader lifecycle and stage machine, which this change does not alter. No open Critical or Important standards finding.

## Spec review

Reviewed fm-axu.3 and Decisions 8 and 10 after Standards.

Important, fixed: deriving the repo key only from the directory name could refuse an already registered repo whose stable board key differed. Adoption now retains the matching registered key and, for an empty repo, its prefix. A failing-first regression proves the existing config bytes stay unchanged.

Important, fixed: copying cleaned hooks into the new hook directory left old beads commands in `.git/hooks`. The failing regression now proves the original marked beads block is removed while custom commands survive.

Registration appends one files-mode entry, including GitHub origin when recognized. Exact existing registrations are no-ops; conflicting keys, paths, prefixes or source modes are refused, never rewritten. An already registered beads repo therefore needs an explicit operator edit to `tickets = "files"` before adoption. This follows the append-only and duplicate-refusal requirements; it is not an automatic rewrite disguised as onboarding.

Unsupported dependency types, multiple parents/discovery sources, unsupported ticket statuses/types, missing comments and invalid graphs stop adoption with beads intact. The approved schema has four relationship representations; unsupported data is not silently flattened.

Declined: the approved real cutover, installed reader/source switch and live stages/history comparison. Those are the coordinator's user-approved step; existing reader tests cover stable identity. Scratch evidence and final gates are recorded below. No open Critical or Important implementation finding.

## Risk review

Reviewed third, focusing on data loss, config writes and hook compatibility.

Critical, fixed: a symlinked export or a redirected beads store could make the converter read data outside its backup. Adoption now rejects symlinks throughout beads, redirect files and non-embedded stores before exporting. The failing-first symlink and redirect tests now preserve `.beads` and refuse adoption. Embedded exports run on a temporary copy with inherited beads, Dolt and Git routing removed, and hooks, backup and auto-push disabled.

Important, fixed: a late non-issue write could evade an issue-only comparison. SHA-256 snapshots cover every regular beads file before and after backup and before removal. An injected filesystem writer adds non-issue data after publication; adoption refuses removal and retains the new data. The source must still be quiescent: this is not a cross-process transaction with arbitrary beads writers.

Important, fixed: inserting shell code into a Python pre-commit hook broke that hook. The actual escript regression reproduced the Python syntax error. Non-shell hooks now retain their interpreter in `pre-commit.user`, called by a shell wrapper after `foreman check`. A second failing regression caught wrapper repair dropping the custom hook. Re-running adopt now restores that wrapper and still runs the custom hook.

Important, fixed: copying hooks with mode 0755 activated previously disabled hooks. Failing-first tests now prove unrelated hook modes survive and an inactive pre-commit is retained as `pre-commit.disabled`, not executed by the new check.

Important, fixed: the first implementation retained the database backup but not the exact fresh export used for comparison. Adoption now writes that export beside the tarball and returns its path, so the coordinator can repeat the comparison without reopening the store. A failing-first regression verifies that export's contents.

The safety fact is that removal follows an external tar backup, successful ticket validation, equality against a second source export, and an unchanged source snapshot. Tests exercise refusal on invalid existing tickets and concurrent source changes. The actual escript also demonstrates a clean pre-commit passing and an invalid ticket being blocked. Proof level 4 for failure safety, level 5 for the CLI and hook workflow.

The local database export branch requires an installed compatible `bd`; it was not exercised against a live Dolt store in this session. The required dry run uses the tracked 40-issue export, as instructed. A database export failure leaves the source intact. Power-loss atomicity, network filesystems and arbitrary concurrent editors are not promised. Interrupting a process can leave an adoption or config lock; inspect it and the retained backup before retrying. No automatic stale-lock deletion occurs.

Declined: live database cutover, installed board state and deletion of backups. Cheapest merge check is `mix precommit`, followed by the scratch replay. No open Critical or Important implementation finding within this local, quiescent-checkout contract.

## Coordinator correction: remove embedded provenance

The coordinator found one Important scope error: each ticket carried its original JSON record, duplicating its prose and retaining fields the spec excludes. I treated archival completeness as ticket content even though the tarball and exact-export sidecar already preserve the source.

Removed the provenance section. Conversion now emits only mapped facts and sections, normalized through the file codec so an empty body round-trips correctly. Comparison checks only those mapped facts and prose. It still rejects changes to every frontmatter field, missing tickets, lost Description, Acceptance, Design or Notes content, and changed comment dates, authors or text. Changes to excluded metadata no longer fail comparison.

Failing-first evidence: the converter suite initially had three failures for unwanted provenance, excluded metadata affecting comparison, and a nonempty body when no mapped prose existed. The corrected focused suite passes 17 tests. The dry-run script now rejects a provenance section in any of the 40 converted files. `fm-zgd.3.md` is 1,827 bytes after conversion.

Follow-up review ran Standards, Spec, then Risk. Standards: the change stays within the converter seam. Spec: unused fields no longer enter tickets, while all mapped facts and sections remain covered. Risk: backup, exact-export sidecar and the removal gates are unchanged; empty-body comparison is covered through the real file codec. No open Critical or Important finding in this correction.

Lesson prevention: the regression asserts the exact mapped body, and the scratch acceptance script rejects provenance in every generated file. The schema-exclusion rule already existed but did not stop my over-preservation; the executable checks now enforce it. No lesson bead was written because this build session forbids bd writes. The coordinator can record the lesson from this report.

## What changed

- `Foreman.CLI` routes `adopt [path] [--json]` to the offline `AdoptCLI`. The CLI remains an escript and never starts the web application or database.
- `Adopt` owns preflight, backup, publication, comparison, hook and AGENTS updates, removal and registration. `AdoptMachine` declares those phases; its generated matrix is in `docs/machines/adopt_machine.md`.
- `AdoptConfig` loads the same global and local config layers as the worker. Only adopt writes config, by appending to `FOREMAN_CONFIG_DIR/foreman.toml`, defaulting to `~/.config/foreman/foreman.toml`. It never rewrites another entry.
- `BeadsConversion` decodes exports, converts all records including closed issues and compares the result. It checks every schema field and the complete body, plus an independent reverse projection of dependency types and scalar fields.
- The marked AGENTS block points at the globally linked foreman skill. Recognized beads blocks are removed; unrelated prose stays untouched. Existing unmarked beads instructions need the coordinator's editorial review.
- The tracked `.foreman/hooks` directory contains `foreman check` and preserved custom hooks. Adoption sets the checkout-local `core.hooksPath`. It refuses linked worktrees, external hook directories, symlinked data and unrecognized beads hook code rather than editing another checkout.
- Successful CLI output includes the registration, backup and exact export paths, comparison, change list, and the full tracked plus untracked diff. Nothing is staged or committed.

## Converter mapping

| Beads source | Ticket file |
| --- | --- |
| `id`, `title`, `status`, `priority`, `close_reason` | Same fact, unchanged |
| `issue_type` | `type` |
| `created_at`, `closed_at` | `created`, `closed`, as ISO dates; absent closed date is null |
| `parent-child` | `parent` |
| `blocks` | `blocked_by` |
| `related` | `related` |
| `discovered-from` | `discovered_from` |
| `labels` | Sorted labels, unchanged values |
| `description` | Markdown body, unchanged prose |
| `acceptance_criteria`, `design` | Acceptance and Design sections |
| `notes` | Existing Notes prose |
| `comments` | Dated author lines under Notes; multiline text stays indented |
| Assignee, claim, owner, updated timestamps, comment ids, dependency metadata beyond type and other unmapped fields | Excluded from ticket files; retained only in the external backup and exact-export sidecar |

Ticket files contain no generated provenance section. The external tarball and exact-export sidecar preserve every original field for recovery. Nothing deletes them automatically. Comparison intentionally ignores excluded metadata and checks the mapped ticket data, not archival equality.

Fixture coverage includes all four dependency types, nonempty labels, closed records, multiline comments and excluded metadata. Comparison tests mutate every frontmatter field, remove each mapped prose field, change comment dates/authors/text, remove tickets and replace bodies. Unsupported mapped data fails before removal.

## Dry-run evidence

`tools/adopt-dry-run.py` clones this worktree under `/tmp/fm-adopt-dry`, installs `git show main:.beads/issues.jsonl` there, preserves the GitHub origin and uses an isolated config directory. It runs the built escript, extracts the backup's export to check its bytes, runs the standalone comparison, validates tickets, and compares file hashes across a second adoption. It refuses existing destination paths and never deletes earlier backups.

The final evidence directory is recorded in the final gate below. Each run retains `first.json` with the full diff, `source.jsonl`, `comparison.txt`, `rerun.json`, the tarball and adopt's exact-export sidecar.

```text
comparison equal: true
count: 40
statuses: closed=20, open=20
parents: 36
dependencies: blocks=41, parent-child=36, discovered-from=1, related=0
labels: 0
comments: 2
foreman check: valid, errors=[]
adopt rerun: changes=[]; AGENTS, hooks, ticket files and config hashes unchanged
provenance sections: 0 across all 40 files
fm-zgd.3.md: 1827 bytes
```

Resulting tree:

```text
tickets/
  fm-3c3.md
  fm-3c3.1.md
  fm-3c3.2.md
  fm-3c3.3.md
  fm-3c3.4.md
  fm-axu.md
  fm-axu.1.md
  fm-axu.2.md
  fm-axu.3.md
  fm-axu.4.md
  fm-axu.5.md
  fm-axu.6.md
  fm-axu.7.md
  fm-c2w.md
  fm-c2w.1.md
  fm-c2w.2.md
  fm-c2w.3.md
  fm-c2w.4.md
  fm-c2w.5.md
  fm-c2w.6.md
  fm-c2w.7.md
  fm-c2w.8.md
  fm-c2w.9.md
  fm-c2w.10.md
  fm-c2w.11.md
  fm-c2w.12.md
  fm-c2w.13.md
  fm-c2w.14.md
  fm-c2w.15.md
  fm-c2w.16.md
  fm-c2w.17.md
  fm-c2w.18.md
  fm-c2w.19.md
  fm-zgd.md
  fm-zgd.1.md
  fm-zgd.2.md
  fm-zgd.3.md
  fm-zgd.4.md
  fm-zgd.5.md
  fm-zgd.6.md
```

The dry run uses the permitted tracked export, not a claim to have exported the live database. No installed board, config or database was changed. The real source switch and check 2 remain coordinator-owned.

## Final gate

```text
$ mix test test/foreman/adopt_test.exs test/foreman/adopt_escript_test.exs test/foreman/adopt_config_test.exs test/foreman/beads_conversion_test.exs
seed 706756
17 tests, 0 failures
exit 0

$ mix precommit
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 969980, max_cases: 16
Generated escript foreman with MIX_ENV=test
Finished in 53.2 seconds (3.2s async, 49.9s sync)
5 properties, 412 tests, 0 failures
exit 0

$ python3 tools/adopt-dry-run.py /tmp/fm-adopt-dry /tmp/fm-adopt-no-provenance-config
comparison equal: 40 tickets, 2 comments
check valid; rerun no-op (change list and file hashes)
backup: /tmp/fm-adopt-no-provenance-config/backups/fm-adopt-dry-1792359118818233.tar.gz
No converted ticket contains a provenance section.
fm-zgd.3.md bytes: 1827
Full change: /tmp/fm-adopt-no-provenance-config/first.json
exit 0

$ git diff --check
exit 0
```

Exact-export sidecar: the backup path above plus `.export.jsonl`. Full stdout is `/tmp/fm-adopt-no-provenance.log`. The comparison and rerun JSON are in `/tmp/fm-adopt-no-provenance-config`. The previous scratch checkout is retained at `/tmp/fm-adopt-dry-with-provenance`; earlier backups were not deleted.

Initial dependency compilation emitted the existing upstream Oban unused-clause warning. Final application compilation and the full gate emitted no warnings. No dependency version changed.

Changed: offline adoption, conversion/comparison, append-only registration and hooks. Verified: fixture, temporary-repo and actual-escript tests, full precommit, and the 40-ticket scratch replay. Not verified: live Dolt export, installed source switch, installed stage/history comparison, power-loss recovery or network filesystems. The first three belong to the approved real cutover below; the filesystem limits remain explicit.

## Real-cutover commands

Run only after these code changes are integrated into the main checkout and the user approves foreman's cutover. Keep beads writers idle. Before adoption, explicitly reconcile the existing global repo entry: preserve its key, set the main-checkout path, `prefix = "fm"`, `github = "rpmessner/foreman"` and `tickets = "files"`. Adoption refuses to rewrite it. Preserve unrelated settings and review local overrides. The files reader retains its cache while the tickets directory is absent.

Set `REPO_KEY` below to that existing key. Use the newly built escript for the cutover and install it before relying on the persistent hook. If the old hooksPath is an absolute alias of this checkout's `.beads/hooks`, explicitly change it to `.beads/hooks`; adoption otherwise refuses an external path. Review the obsolete unmarked Postgres-only/beads sentence in AGENTS.md as part of the approved cutover; adopt only removes marked blocks.

The first block prepares the change and records board stages/history. Do not commit until the board has loaded the files source, the before/after comparison is equal and the user has approved the displayed diff. The board's read-only files reader already has identity/history preservation regression tests; this comparison verifies the actual installation.

```sh
cd ~/dev/utils/foreman
set -euo pipefail
test -z "$(git status --porcelain)"
export FOREMAN_CONFIG_DIR="${FOREMAN_CONFIG_DIR:-$HOME/.config/foreman}"
# Explicit operator edit of the existing entry, not an append-only adopt rewrite:
"${EDITOR:?Set EDITOR}" "$FOREMAN_CONFIG_DIR/foreman.toml"
: "${REPO_KEY:?Set REPO_KEY to the existing configured key}"
mix escript.build
export PATH="$PWD:$PATH"
evidence=$(mktemp -d /tmp/foreman-cutover.XXXXXX)
jq -r '.id' .beads/issues.jsonl | sort > "$evidence/ids"
while IFS= read -r id; do
  ./foreman show "$id" --overlay --project "$REPO_KEY" --json
 done < "$evidence/ids" | jq -sS 'map({repo,id,stage,history}) | sort_by(.id)' > "$evidence/before.json"
./foreman adopt "$PWD" --json > "$evidence/adopt.json"
jq -r '.diff' "$evidence/adopt.json"
./foreman check --json
source_export=$(jq -r '.export' "$evidence/adopt.json")
test -f "$source_export"
test -f "$(jq -r '.backup' "$evidence/adopt.json")"
mix run --no-start tools/adopt-compare.exs "$source_export" "$PWD" > "$evidence/comparison.json"
# Tickets contain only mapped data; retain the external artifacts for all other fields.
python3 - <<'PY'
from pathlib import Path
for ticket in Path('tickets').glob('*.md'):
    assert '## Beads provenance' not in ticket.read_text(), ticket
PY
./foreman adopt "$PWD" --json > "$evidence/rerun.json"
jq -e '.changes == []' "$evidence/rerun.json"
# After Settings confirms this repo has read the files source:
while IFS= read -r id; do
  ./foreman show "$id" --overlay --project "$REPO_KEY" --json
 done < "$evidence/ids" | jq -sS 'map({repo,id,stage,history}) | sort_by(.id)' > "$evidence/after.json"
diff -u "$evidence/before.json" "$evidence/after.json"
```

After that comparison and user approval, the coordinator runs:

```sh
cd ~/dev/utils/foreman
install -m 755 foreman "$HOME/.local/bin/foreman"
export PATH="$PWD:$PATH"
mix precommit
git add -A -- AGENTS.md .beads .foreman tickets
git diff --cached --check
git diff --cached --stat
git commit -m "Migrate foreman from beads to ticket files"
```
