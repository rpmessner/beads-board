# fm-vtx.3: worktree documents

## Changed

- `Foreman.DocumentSources` resolves document mentions against main first, then the ticket's recorded worktrees. Session details and history `workdir` and `worktree` values supply the recorded roots. A worktree must belong to the configured repo, have no symlinked ancestors, and match git's registration, top-level directory, and common directory.
- `Foreman.TicketDocuments.collect/3` now returns worktree source tokens as well as `:main`. Collection still deduplicates paths, orders mentions, and caps the list at 50 documents. Ticket text links use the same resolver.
- The Documents section, panel, and viewer label worktree-only documents with `in worktree <directory name>`.
- Panel and viewer reads both call `DocumentSources.open/3`. Each read queries current board records and checks the repo and git membership again. Neither a source token nor the ticket's derived display data grants access.
- Main takes precedence even for an old worktree URL. A removed or pruned worktree falls back to main; absent documents show unavailable. Existing exact recorded-artifact fallback reads only main, never the old root.
- The CLI's existing `--doc` validation and general `Documents.read/2` fallback are unchanged. No schema migration, stored document list, or document-content crawl was added.

## Interface and source encoding

Collector entries remain `{repo, relative_path, source}`. `source` is `:main` or an opaque string:

```text
wt- + base64url_without_padding(SHA256(expanded_absolute_worktree_root))
```

The token is stable while the root stays the same. It contains no decodable filesystem path and is not a credential. The reader matches it against current records for tickets of the requested repo before checking git membership. Unknown tokens fail even when the requested document exists in main.

Panel URLs retain `doc=<repo>:<relative_path>&doc_source=<token>`. Viewer URLs retain `/documents/<repo>?path=<relative_path>&source=<token>`. Normal query encoding applies. `TicketDocuments.viewer_path/3` builds these viewer links. Main links omit the source. After fallback to main, the panel's viewer link also omits it.

`TicketDocuments.render/3` accepts a ticket context for worktree resolution, while keeping the existing repo-key form for main-only callers. The sheet keeps only derived `document_roots` alongside its streamed history and sessions. Reads never authorize from that field.

## Evidence

### Failing-first checks

- The first resolver test failed with `nil` instead of the worktree report tuple.
- The collector test failed with `[]` instead of a single deduplicated worktree entry.
- The LiveView test failed because Documents did not emit the source-bearing link.
- The viewer security test failed because the old viewer opened an unrecorded git worktree through an absolute URL.
- The review regression test failed because collection generated a foreign-repo source that the reader correctly refused.

Initial test setup required `mix deps.get`. No dependencies or lockfile entries changed.

### Tests

The focused security suite covers configured roots, ticket worktrees, recorded-order fallback, history-only and session-only records, main-first resolution, removed and pruned roots, and unavailable documents. Rejections include outside paths, traversal, file and directory symlinks, unknown repos, forged tokens, unrecorded worktrees, recorded non-worktrees, and worktrees of an unconfigured repo. A read succeeds with a current record, then fails after the records are removed. A record on another repo does not authorize the source.

LiveView checks cover source-bearing links in Documents and history, the section and panel labels, URL parameters, viewer links, main-first label removal, fallback, and unavailable states. Existing request-card, document-reader, and panel tests remain included in the gate.

### Registered preview

Preview URL: `http://127.0.0.1:4880`. `devserve ls --json` confirms branch and owner `fm-docwt`, running state, and this checkout. Unit: `devserve-foreman-fm_docwt-ccf966775390.service`. Database: `foreman_preview_fm_docwt_ccf966775390`.

`tools/docwt-seed.exs` guards against any database other than the docwt preview. It configures a scratch repo under `/tmp` and dispatches a ticket whose workdir is that repo's scratch git worktree. The report exists only in that worktree. No live-board records or real-repo worktrees were changed.

`tools/docwt-acceptance.cjs` passed at widths 1440 and 390 in light and dark themes. It verifies Documents deduplication and labels, panel opening, source round-trips, refresh, retained ticket, viewer navigation, forged-source refusal, main-first resolution, removed-tree fallback, and unavailable states. No page errors or horizontal panel overflow occurred.

Evidence is in `docs/acceptance/fm-docwt/`: `browser.json`, `browser.txt`, and eight screenshots. The screenshots were inspected for wrapping, spacing, contrast, and clipping. The mobile filename now occupies its own header row rather than breaking in the middle of a word.

The browser script removes only its scratch worktree and merged fixture file while testing fallback. Re-run the guarded seed before repeating it. The registered preview remains running; cleanup belongs to coordinator close-out.

## Sequential review against 157f441

Reviewed the uncommitted diff and new files against `157f441`, in this session, without subagents. HEAD remains at that base.

### Standards

No Critical or Important findings. Source resolution computes locations and checks authorization; it adds no lifecycle or mutable status. Panel transitions still use `Foreman.DocumentPanel.step/3`, and viewer transitions still use `Foreman.Documents.Viewer.step/3`. Documents remain streamed. `document_roots` is derived display data, not authorization state.

Declined to judge changes to CLI policy because the CLI implementation is unchanged. Verdict: Ready.

### Spec

Fixed Important: collection could generate a foreign-repo worktree source from a ticket in another repo. The reader correctly requires a record on a ticket of the destination repo, so that link could not open. A failing resolver test reproduced this. Worktree collection now stays within the ticket's repo, while main-checkout lookup still spans configured repos.

Fixed Minor: the mobile panel header split the filename mid-word. The path now has its own row on small screens. New screenshots confirm the fix.

No Critical or Important findings remain. Every build-time acceptance item has test or preview evidence. Declined to judge the post-deploy live check because deployment is prohibited here and belongs to coordinator close-out. Verdict: Ready.

### Risk

The safety fact is that every panel and viewer read re-queries repo-scoped board records and checks the selected root before opening the file. Source tokens cannot provide arbitrary roots. Existing symlink checks and bounded Markdown reads still apply.

Proof level 4 comes from executable read tests that revoke records, remove git membership, replace a worktree with an ordinary directory, and try outside paths and symlinks. Proof level 5 comes from the preview's real worktree report and forged-source checks. The focused security command and final gate below exercise the shipped functions.

Cleared regression risks include request-card links, viewer-internal Markdown rendering, main documents, exact removed-artifact fallback, and panel URL state. The CLI retains its existing policy. No Critical or Important findings remain.

Declined to judge adversarial concurrent filesystem mutation between the existing reader's filesystem checks and open call. This ticket does not change that reader or claim OS-level atomic path confinement. The new authorization itself is checked on every read, without a persistent cache.

Cheapest pre-merge check: run `mix test test/foreman/document_sources_test.exs test/foreman/document_source_reads_test.exs test/foreman_web/live/document_panel_live_test.exs`, then the full gate. Verdict: Ready.

## Remaining

- Coordinator performs the post-deploy live-board check, files any new work, and closes fm-vtx.3. No new tickets are needed from this build.
- No commits, pushes, deploys, release installs, or ticket closure were performed. The pre-existing `docs/briefs/fm-docwt.md` is untouched.
- Preview cleanup remains with the coordinator.

## Final gate

`mix precommit` exited 0 after all review fixes, with zero warnings. Full output is in `docs/acceptance/fm-docwt/precommit.txt`:

```text
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 962342, max_cases: 16
Finished in 91.0 seconds (5.7s async, 85.2s sync)
5 properties, 745 tests, 0 failures
```

The focused security suite passed with 49 tests and zero failures. Its output is in `security-tests.txt` in the same directory. `foreman check` reported `tickets valid`, and `git diff --check` passed. Preview ownership evidence is in `devserve.json`, with the checkout path reduced to its basename.
