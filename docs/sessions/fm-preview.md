# fm-preview: sk-9ro.2

Implemented in the `fm-preview` worktree without commits, pushes, ticket edits, bd commands, or subagents. Installed services, their configuration, and their database were not accessed. The coordinator-owned brief is unchanged.

## Changes and guard points

- `config/runtime.exs` now applies `DATABASE_URL` in dev. `PORT` already worked at runtime; the new test covers both together. Without a database URL, the existing dev defaults remain.
- `Foreman.Preview.allow_external_write/0` returns `{:error, "refused in preview"}` when `PREVIEW=1`.
- `Requests.PushJob`, `Merge.MergeJob`, and `Merge.RetargetJob` check that policy after their durable claim and before credentials, forge reads, or writes. Push uses the existing failed transition and request event. Merge and retarget persist the reason in their existing audit record. A refused retarget preserves the prior merge SHA.
- No tmux/session launch implementation or execution seam exists. No speculative launcher was added. Future write jobs must call the same policy before external IO.
- Reads and preview-local database writes remain available. No UI gate, new lifecycle, migration, or dependency was added.

The `test/test_helper.exs` change is a formatter-required line wrap. Acceptance tools are `tools/preview-seed.exs`, `tools/preview-acceptance.exs`, and `tools/preview-acceptance.cjs`.

## Test-first evidence

The config regression first returned no dev database URL. The push, merge, and retarget regressions first completed their writes under `PREVIEW=1`. Each passed after its guard was added. Saved failing outputs are under [the acceptance directory](../acceptance/fm-preview/).

Review found a credential-order defect: the initial implementation looked up credentials before checking preview mode. Calling the actual `perform/1` entry points without the credential service exited instead of recording refusal. Failing regressions reproduced this for all three jobs. Credential resolution now happens behind the guard. These are reproduction failures with a stack trace, not claimed assertion-level red runs.

The focused suite covers refusal, push audit payload, unchanged forge state, reads under preview, preserved merge evidence, actual `perform/1` entry points, dev config, and existing non-preview write behavior:

```sh
mix test test/foreman/push_test.exs test/foreman/merge_job_test.exs \
  test/foreman/runtime_config_test.exs
```

Final focused result: 51 tests, 0 failures. Removing each guard restores the corresponding observed failing behavior; the initial red runs provide that evidence.

## Live scratch-copy check

The check ran twice, including after the credential-order fix. A temporary `DEVSERVE_CONFIG_DIR` inside this worktree held the scratch apps.toml and a private database environment file. Both were removed afterwards. No user devserve config or dotfiles were created or changed.

1. A `fmseed` app used `data = "fresh"`, `mix ecto.migrate`, and `mix run tools/preview-seed.exs`. Its web-only server left the seeded push approved and its Oban job available. The seed read this checkout's 41 ticket files into Postgres without changing them.
2. `devserve down` stopped that source and kept its devserve-owned database.
3. A `fmcheck` app used `data = "copy"` from that scratch source, then migrated. Devserve served the copy at `http://127.0.0.1:4881`, inside the configured 4880–4889 range.
4. The actual application endpoint and Oban worker started in dev. Discovery was disabled only in the acceptance start script, to keep the copied fixture stable and avoid reading operator configuration. No forge implementation or git command was replaced. Erlang call tracing watched `System.cmd/3` for git, gh, and tmux, and the GitHub adapter's list, merge, and retarget entry points without recording arguments.
5. Copied request `5d962264-dd51-4591-a1d9-60c0e7cd7220` became failed with `refused in preview`. Its events were `start`, then `failed` with that reason. The Oban job completed. The source request remained approved. The trace contained zero external boundary calls.
6. Playwright connected to LiveView, displayed the copied checkout tickets, and observed an automatic reload after a temporary root-template edit. The edit was restored in `finally`. No browser errors or page overflow occurred. The [screenshot](../acceptance/fm-preview/preview.png) was inspected for layout and clipping.
7. `devserve down --drop-db` removed both units and both devserve-owned databases. `devserve ls --json` returned empty previews. Postgres returned no matching scratch databases, and neither 4880 nor 4881 had a listener.

[Live result](../acceptance/fm-preview/live-result.json) records the final request, audit, job, ticket count, trace result, and cleanup. This verifies copied scratch data, not a copy of the installed database, which this session was forbidden to access.

The first browser probe changed the title's default, but the page supplies an explicit title, so its assertion timed out. The corrected probe changes a body attribute and observes the resulting reload. No production fix was needed.

## Proposed apps.toml registration

Proposal only. The coordinator must obtain approval before adding it to dotfiles. The paths, source database name, PATH, and available port range below are placeholders requiring operator confirmation. The source must be the installed foreman database, not `foreman_dev` by assumption.

```toml
[[apps]]
name = "foreman"
path = "/absolute/foreman-main-checkout"
ports = [4880, 4899]
start = ["/absolute/toolchain/bin/mix", "phx.server"]
data = "copy"
source_database = "installed_foreman_database"
migrate = ["/absolute/toolchain/bin/mix", "ecto.migrate"]
main_units = ["foreman-web.service", "foreman-worker.service"]

[apps.env]
FOREMAN_ROLE = "all"
PATH = "/absolute/toolchain/bin:/usr/local/bin:/usr/bin:/bin"
```

Database authentication belongs in an operator-selected untracked `env_file`, not in this proposal or command arguments. Devserve supplies `PORT`, `DATABASE_URL`, and `PREVIEW=1`. The installed database's name and configuration were deliberately not inspected.

## Review scope

Fixed point: `f1b4f91fdae5b78c37ae88be5a5ce7678ea6265c`, which is HEAD. The committed three-dot diff and commit list are empty. Review therefore covered the explicitly requested uncommitted diff and new deliverables, excluding the coordinator-owned brief. Axes ran sequentially without subagents.

### Standards

Ready. Reviewed the app instructions, house baseline, config, three jobs, policy, tests, and acceptance tools. Existing declared request and merge machines own refusal transitions. The environment check is a stateless policy, not a new lifecycle. Test environment changes are in synchronous tests and restored on exit. There are no new dependencies, user-input atoms, or UI changes.

The credential-order follow-up retains those properties. No open Critical or Important finding. Declined to judge unrelated existing workflows and a future launcher implementation.

### Spec

Ready for this session's scope. The code covers dev PORT/DATABASE_URL and every current app external-write job. Existing adapters remain readable. Refusal is durable and clear, including for copied retarget work. No launch seam exists to guard.

One Important finding was fixed: credential resolution preceded the guard at the production job entry points. Three failing regressions and their passing reruns cover the correction. The live check was repeated after it.

Declined to judge installed-data acceptance and actual dotfiles registration because the brief reserves both for approved coordinator work. Those ticket-wide items are not claimed complete. No open implementation finding remains.

### Risk

Ready. The safety fact is that each claimed write reaches the preview check before credentials or external IO. Failure goes through the existing terminal transition rather than raising or retrying. Proof level 4 comes from the focused job tests; level 5 comes from the actual Oban worker consuming a copied approved request while the traced external boundaries remain unused.

The search found only the guarded push, merge, and retarget jobs for app external writes. Git subprocesses in document/ticket reads remain reads. Standalone CLI adoption can change local repository configuration, but the preview server never invokes it. No tmux launcher exists. Existing non-preview push, merge, retarget, replay, and failure tests remain green.

Declined to judge arbitrary code calling an adapter directly, hostile changes to the process environment, or future jobs that omit the policy. This is the app's preview contract, not an OS sandbox. The cheapest pre-merge check is the focused command above. No open Critical or Important Risk finding.

## Final gate

Final `mix precommit` passed with 5 properties, 431 tests, and 0 failures, seed 97137. Repository hygiene passed and the final application gate emitted no warnings. Output is saved in [precommit.txt](../acceptance/fm-preview/precommit.txt). The focused output is [focused-tests.txt](../acceptance/fm-preview/focused-tests.txt). `git diff --check` and the browser script syntax check also pass.

Initial dependency compilation emitted an existing Oban unused-clause warning. The first hygiene runs rejected scratch config paths and a dependency-cache path in a saved red log. Scratch files were removed, and the saved log now contains only the relevant ExUnit excerpt. No hygiene rule was weakened.

Changed: dev database URL support and audited preview refusal at all current write jobs.
Verified: focused tests, full precommit, copied scratch request, live reload, inspected screenshot, and complete preview cleanup.
Not verified: installed database copying and user dotfiles registration, intentionally reserved for approval. No commit or deployment was performed.
