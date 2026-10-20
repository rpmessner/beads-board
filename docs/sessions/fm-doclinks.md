# fm-doclinks build report

Ticket fm-vtx.1 is ready for coordinator review. No commits, pushes, deploys, release installs, or ticket closure.

## Changed

- `Foreman.TicketDocuments` collects document mentions from every history payload value, the ticket's requests, body, notes, and session details. It recurses through payload values, never through document contents.
- Entries deduplicate by canonical document identity, sort by newest timestamp, and stop at 50 distinct documents. Untimed raw ticket fields follow timestamped mentions. Session details use their dispatch time, not the session's later heartbeat.
- The shared ticket sheet renders existing Markdown paths in body fields, notes, history values, and session facts. History now includes arbitrary payload keys rather than only the old allowlist.
- A streamed Documents section shows each path and its main-checkout location. Empty sections are absent. Links open the full viewer.
- `CardText.references/3` shares candidate limits and resolution between request cards and the sheet. Existing request-card rendering options remain unchanged.
- The resolver rejects `..` before expanding `~/`. Previously expansion could erase traversal segments before validation.
- Strict resolution is opt-in to `Markdown.render/2`. Unavailable local Markdown links become plain content on the sheet. Viewer-internal links and request-card Markdown retain their existing handling.

## Interface for fm-vtx.3

`Foreman.TicketDocuments.collect(ticket, requests, repos \\ nil)` returns ordered `{repo, path, source}` tuples. The current source is the atom `:main`. The sheet converts these into stream entries carrying `repo`, `path`, and `source`. Worktree resolution and source labels can extend this interface without adding storage.

`CardText.resolve/3` remains the shared resolver. `CardText.references/3` returns `{original_path, {repo, relative_path}}` pairs and checks at most 50 distinct candidates per text.

## Evidence

### Tests

Observed failing assertions before their fixes:

- The collector returned `[]` instead of the six documents from history, requests, notes, session facts, and body.
- The sheet lacked `#ticket-documents` for a bare history path.
- A home-relative path containing traversal resolved instead of returning `nil`.
- Dotted and ordinary relative mentions produced duplicate entries.
- Missing Markdown targets still produced empty anchors rather than plain content.
- A later session heartbeat incorrectly moved an older session document ahead of newer history mentions.

The focused check passed with 78 tests and zero failures:

```sh
mix test test/foreman/ticket_documents_test.exs test/foreman/card_text_test.exs test/foreman/documents_test.exs test/foreman/markdown_test.exs test/foreman_web/live/initiatives_live_test.exs test/foreman_web/live/card_docs_live_test.exs
```

Coverage includes nested payloads, all collector sources, timestamp ordering, deduplication, the 50-document cap, plain invalid targets, configured-repo priority, outside paths, file and directory symlinks, traversal, and request-card regressions. LiveView assertions cover history links, request-sourced documents, and section visibility.

### Registered preview

Preview URL: `http://127.0.0.1:4881`. `devserve ls --json` confirms branch and owner `fm-doclinks`, worktree basename `fm-doclinks`, and state `running`. Leave cleanup to the coordinator.

The first startup failed because this worktree lacked dependencies. After `mix deps.get`, the registered startup succeeded. The initial port was 4880. The current registered preview uses 4881.

Acceptance uses wa-x0z.5's history copied into the preview by devserve. Only the preview copy's handwritten `notes` field was removed. The existing copied agent notes include a bare report path. No live-board database queries or edits were used for acceptance.

Browser assertions confirm:

- Documents contains exactly `docs/research/addon-ideas.md`, then `docs/briefs/wa-ideas.md`, with no handwritten Documents note.
- Bare history values and the report agent note link to documents.
- Clicking Documents opens the full viewer and renders `#document-content`.
- Light and dark runs have no browser page errors.
- At 390px, Documents stays within the sheet without horizontal overflow.

Evidence is in `docs/acceptance/fm-doclinks/`: `browser.json`, light and dark screenshots for Documents, history, and notes, plus `documents-mobile.png`. Screenshots were inspected for wrapping, spacing, contrast, and clipping.

The repeatable browser check is `check.cjs` in that directory. It requires Playwright on Node's module search path and `PREVIEW_URL` set to the registered preview URL.

## Sequential self-review against d9aa5f7

Reviewed the uncommitted changes against `d9aa5f73f8d3cd5ce51288fa76da757626160538`, including the new files. No subagents ran.

### Standards

Fixed an Important collection-handling issue by streaming Documents instead of keeping a rendered list assign. Removed duplicate candidate-resolution pipelines through `CardText.references/3`. Replaced a Markdown-bearing heading element with a valid heading-role container.

No Critical or Important findings remain. This ticket adds pure computation and rendering, not a lifecycle. The existing declared `Foreman.TicketSheet` machine still owns ticket-sheet state. The derived `documents?` value is display data, not independent UI state.

Declined to judge the sibling panel and worktree machines because this ticket does not implement them. Verdict: ready.

### Spec

Fixed Important document-identity and ordering issues. `./body.md`, `body.md`, and its absolute path now deduplicate. Session heartbeats no longer count as new document mentions. Missing local Markdown links render as plain content.

Every fm-vtx.1 acceptance item has test or preview evidence above. No migration, stored document list, or document-content crawl was added. No Critical or Important findings remain.

Declined to judge panel layering, URL round-trips, and worktree fallback because those belong to sibling tickets. Verdict: ready.

### Risk

The safety fact is that every newly generated document link passes the shared resolver and `Documents.document?/2`, which checks configured-root containment and refuses symlinks. Proof level 4 comes from executable resolver tests with existing outside files and symlink escapes. Preview clicks also reached the intended full viewer.

Fixed the traversal-validation gap before home expansion. Request-card tests and viewer tests pass. The strict Markdown option is enabled only for ticket-sheet rendering, so viewer-internal behavior does not change.

No Critical or Important findings remain. The cheapest pre-merge check is the focused command above, followed by `mix precommit` after sibling integration. Existing viewer worktree policy is outside this diff. Verdict: ready for this ticket's scope.

## Open and not verified

- Panel behavior and worktree-only documents remain sibling work, not gaps in fm-vtx.1.
- Live deployment acceptance was not run. Deployment is prohibited in this build session.
- Earlier test runs hit the documented LiveView token-clock failure in `SessionLaunchTest` and `CardDocsLiveTest`. Each failed test passed on retry. The final full gate below passed without retries or warnings. No clock or signing-policy changes were made.
- The pre-existing untracked `docs/briefs/fm-doclinks.md` was left untouched.

## Final gate

`mix precommit` exited 0 after the review fixes:

```text
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 190479, max_cases: 16
Generated escript foreman with MIX_ENV=test
Finished in 96.4 seconds (6.2s async, 90.2s sync)
5 properties, 713 tests, 0 failures
```

Zero compiler warnings. `git diff --check` passed and `foreman check` reported `tickets valid`.
