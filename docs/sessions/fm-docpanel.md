# fm-vtx.2: shared document panel

## Changed

- Extracted the Needs you document markup and click hook into `ForemanWeb.DocumentPanel`. Initiatives, the epic page, and Needs you use that component.
- Added `Foreman.DocumentPanel`, a declared FSM with closed, open, and unavailable states. `Foreman.CardPanel` now controls only the existing Needs you ticket panel.
- Document links patch the current URL without dropping the ticket, selected tab, or filters. Closing the document reveals the retained ticket. Refresh reopens the document, and Back closes it.
- The epic spec link uses the same panel. Missing or refused documents show "Document unavailable". "Open in viewer" navigates to the full viewer.
- Reused the existing Fluxon sheet for focus, stacking, Escape, and its 200ms slide. Reduced motion disables the slide. Retained document content lets the exit animation finish without a blank panel.
- Regenerated `docs/machines/card_panel.md` and `docs/machines/document_panel.md` with `mix foreman.fsm.docs`.

## Interface for fm-vtx.3 and sibling links

The panel URL is `<current-page>?doc=<repo>:<path>&doc_source=<opaque-source>`, with normal query encoding. `doc_source` is optional. A viewer link is `/documents/<repo>?path=<path>&source=<opaque-source>`.

`Foreman.DocumentPanel.link_params/1` converts viewer links to panel parameters. `path/2` changes only `doc` and `doc_source`, preserving other query parameters. Close removes both document parameters.

Inside `ForemanWeb.DocumentPanel.surface/1`, the extracted `.CardDocLinks` hook intercepts `a[href^='/documents/']:not([data-viewer])`. Sibling document links need only their normal viewer href. Modified clicks still open the viewer through the browser. `data-viewer` explicitly bypasses the panel.

This ticket does not authorize source roots. Nonempty `doc_source` currently shows unavailable. fm-vtx.3 should extend the shared document resolver and viewer-link generation after validating board-recorded worktrees. The panel currently accepts only configured roots, not the viewer's broader git-worktree fallback.

## Verification

### Tests

Failing-first checks:

- `mix test test/foreman/document_panel_test.exs` failed because the initial stub returned closed instead of open.
- The first Initiatives LiveView test failed at `#panel-document h1` while `open-doc` was a no-op. The shared executor made it pass.

The final tests cover every document-state transition, document replacement, URL/source encoding, ticket and tab retention, refresh, Back parameters, close callbacks, missing files, traversal, symlinks, unknown repos, unsupported sources, and epic spec opening.

The focused risk suite passed with 48 tests and zero failures. It included the existing Needs you and document-reader suites. The old Needs you replacement assertion now also verifies that the ticket remains underneath, as the approved spec requires.

Final `mix precommit` output is in [precommit.txt](../acceptance/fm-docpanel/precommit.txt):

```text
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 430096, max_cases: 16
Finished in 94.6 seconds (6.9s async, 87.7s sync)
5 properties, 724 tests, 0 failures
```

There were zero warnings. `foreman check` and `git diff --check` also passed.

### Browser

The final preview is `http://127.0.0.1:4880`, owned by `fm-docpanel` on branch `fm-docpanel`. `devserve ls --json` confirmed this checkout and running state. Preview unit: `devserve-foreman-fm_docpanel-ebe5156d4855.service`. Preview database: `foreman_preview_fm_docpanel_ebe5156d4855`.

Startup initially failed before dependencies were fetched. An intermediate preview registration disappeared. A fresh `devserve up` recovered the preview; no alternate server was started. All final checks used the owned preview on 4880.

`tools/docpanel-seed.exs` seeds only the named docpanel preview database. Its ticket body, history, and notes reference real Markdown files. `tools/docpanel-acceptance.cjs` uses `PREVIEW_URL` and the installed Playwright module. It checks:

- Opening a document from the ticket on Initiatives without changing the page path.
- Refresh, close, Back, and Escape while retaining the ticket.
- The epic spec link opening the same panel.
- Full viewer navigation and unavailable-state dismissal.
- The dialog's accessible name and reduced-motion slide durations of `[0, 0]`.

All checks passed at widths 1440 and 390, in light and dark themes, with no page errors. Results are in [browser.json](../acceptance/fm-docpanel/browser.json) and [browser.txt](../acceptance/fm-docpanel/browser.txt). Screenshots were inspected after animations settled:

- [Initiatives, light](../acceptance/fm-docpanel/panel-1440-light.png)
- [Initiatives, dark](../acceptance/fm-docpanel/panel-1440-dark.png)
- [Mobile, light](../acceptance/fm-docpanel/panel-390-light.png)
- [Mobile, dark](../acceptance/fm-docpanel/panel-390-dark.png)
- [Epic, light](../acceptance/fm-docpanel/epic-1440-light.png)
- [Epic, dark](../acceptance/fm-docpanel/epic-1440-dark.png)
- [Unavailable](../acceptance/fm-docpanel/unavailable.png)

## Review against d9aa5f7

Reviewed the requested uncommitted diff against `d9aa5f73f8d3cd5ce51288fa76da757626160538`. HEAD remains at that base. Standards, Spec, and Risk ran sequentially in this session, without subagents.

### Standards

- Fixed Important: the actual document dialog lacked an accessible name. `lib/foreman_web/components/document_panel.ex` now names its `role=dialog` element "Document". The browser check verifies it.
- Fixed Minor: removed the obsolete document-parameter argument and query decoding from the Needs you ticket-only executor.
- The new stateful feature uses the declared FSM and pure `step/3`. Filesystem reads and URL patches stay in its executor. Ticket state is independent.
- Declined to judge sibling collection/autolinking and worktree resolution, which belong to other tickets.
- Final verdict: Ready. No open Critical or Important findings.

### Spec

- Fixed Important: the new wrapper initially interrupted the layout's direct-child spacing. `DocumentPanel.surface/1` now preserves `space-y-5`.
- Fixed Minor: autofocus scrolled the document header flush against the viewport top. `scroll-pt-6` preserves the sheet's 24px inset. Browser measurement changed from scrollTop 24 to 0.
- Every fm-vtx.2 acceptance item has test or browser evidence above. The existing panel and hook were extracted, not duplicated.
- Declined to judge collection, worktree reads, and deployment acceptance outside this ticket. Deployment was forbidden in this session.
- Final verdict: Ready. No open Critical or Important findings.

### Risk

- The safety fact is enforced before each panel read: a configured repo, no `..` segment, and `Documents.document?/2` beneath that exact root are required before `Documents.read/2`. Unknown sources cannot supply roots.
- Proof level 4: the focused 48-test suite rejects existing outside files, traversal back inside a root, symlinks, unknown repos, unsupported sources, malformed params, and external viewer URLs.
- Fixed during implementation: an asynchronous drawer-close callback could issue a second URL patch after Back or explicit close. The executor ignores close when already closed. A LiveView regression test verifies no extra patch.
- Proof level 5: the real browser confirms URL and ticket retention, Escape, viewer navigation, and unavailable-state dismissal.
- Declined to judge the existing reader's general filesystem TOCTOU hardening and future worktree-source authorization. Neither changes in this ticket.
- Final verdict: Ready. No open Critical or Important findings. The final full gate ran after the review fixes.

## Remaining

No fm-vtx.2 acceptance gaps remain. Worktree-source resolution belongs to fm-vtx.3. No new tickets were filed, and fm-vtx.2 remains in progress for coordinator close-out.

No commits, pushes, deployments, or release installs were made. Application seeding and verification used only preview and test databases. Preview cleanup remains with the coordinator. The pre-existing `docs/briefs/fm-docpanel.md` was left unchanged.
