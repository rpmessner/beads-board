# bb-sheet: bb-c2w.6

Implemented and verified, including the coordinator's five screenshot corrections. `mix precommit` passes with 4 properties, 184 tests, and no failures. No commits, pushes, bd commands, or subagents. The coordinator owns ticket closure.

## Changed

- `Board.Drilldown` reads epic columns, planned and fallout membership, blocking edges, and the epic's own history. It reuses `Board.Initiatives.Tree` through the snapshot query. Linked draft slugs continue to resolve after ticketing.
- `Board.BlockingGraph` lays out blockers before dependents, includes external endpoints and isolated members, and marks fallout. Cycles remain visible in a final layer. Layering avoids repeated traversal of every path through a dense graph.
- `Board.Overlay.allowed_events/1` exposes the existing machine-derived claimed events. The new-session probe always differs from the current window, even when the window is literally `<new session>`.
- `BoardWeb.EpicLive` renders the epic header, history, configured columns, separate planned and fallout bands, and the blocking graph.
- `BoardWeb.TicketDetail` renders the shared Fluxon sheet. It includes beads content and other fields, dependencies and dependents, board-side epic attachments, stage, history including refused claims, sessions, agent notes, linked CR numbers, and allowed events.
- `Board.TicketSheet` declares URL-driven visibility through `Board.Fsm`. Its generated diagram and matrix have a golden test.
- Initiatives titles navigate to epic routes. Ticket rows and epic cards patch the sheet into the URL. Expansion remains a separate control.

The header's empty `#ticket-actions` container is the insertion point for .14. The shared component and loader work in both LiveViews. No placeholder controls or copy were added.

Both views subscribe to `Board.Events` and reconcile every three seconds. Open sheets refresh alongside their underlying page. Streamed history, sessions, notes, columns, and graph entries are not duplicated in retained assigns. No schema or worker changes.

## Routes and URL contract

- `/epics/:repo/:id` opens an epic, including a draft slug or nested epic.
- `/?ticket=repo:id` opens a ticket over Initiatives.
- `/epics/:repo/:id?ticket=repo:ticket-id` opens it over an epic.
- Other query parameters survive opening and closing. The epic breadcrumb returns to Initiatives with those parameters.
- Close patches away only `ticket`. Escape and backdrop dismissal use Fluxon's close callback to make the same patch. A late callback for another ticket is ignored.
- Reload and browser back/forward restore the URL-selected sheet. Invalid ticket parameters do not crash. Unknown epic routes show an unavailable state with navigation intact.

Epic columns show the epic's full membership. Carried Initiatives filters are return context, not a second filter on the epic's totals.

## Screenshots

Captured against the populated development database on a web-only server at port 4758. Port 4747 was untouched. Browser checks made no database or beads writes.

- bb-c2w: [light](../acceptance/bb-sheet/bb-c2w-light.png), [dark](../acceptance/bb-sheet/bb-c2w-dark.png).
- fe-lwp: [light](../acceptance/bb-sheet/fe-lwp-light.png), [dark](../acceptance/bb-sheet/fe-lwp-dark.png).
- bb-c2w.5 sheet: [light](../acceptance/bb-sheet/ticket-light.png), [dark](../acceptance/bb-sheet/ticket-dark.png).
- Its recorded history: [light](../acceptance/bb-sheet/ticket-history-light.png), [dark](../acceptance/bb-sheet/ticket-history-dark.png).
- [Mobile sheet](../acceptance/bb-sheet/mobile.png).

All captures were opened and compared with Epic, Ticket, and Main. The shell, stage columns, separate fallout band, directed graph, and right-edge sheet follow the approved layout. Sections replace tabs, as permitted by the brief. Real backfill history replaces the mockup's invented draft milestones. All ticket cards remain visible rather than using its illustrative "more" summaries. Wide graphs scroll horizontally.

The current projection shows bb-c2w with 14 planned tickets and 7 closed. fe-lwp has 17 planned, 2 fallout, and 12 closed. The browser asserts that fe-lwp.15 and fe-lwp.16 occupy fallout. Long titles initially widened Done beyond the viewport. A failing browser width assertion caught that defect; explicit inner grid sizing and word wrapping fixed it. All five columns now fit the desktop capture.

Beads text renders escaped and preserves whitespace. It is not interpreted as HTML or Markdown.

## Failing-first evidence

- `mix test test/board/drilldown_test.exs` first failed against nil read-model stubs. Subsequent slices failed for linked draft lookup, duplicate column identities, missing incoming dependencies and attachments, and the session-name collision. The final six tests pass.
- New LiveView assertions first failed on absent ticket links and sheet elements. The epic assertion failed against a routed placeholder before implementation. Both routes now have direct-load, patch, close, refresh, and return-context coverage.
- `mix test test/board/blocking_graph_test.exs` exposed exponential repeated traversal with a 30-node dense DAG. The test timed out before the layer-based implementation. Both graph tests now pass.
- `tools/sheet-acceptance.cjs` failed on desktop overflow and the missing accessible dialog name. Both assertions now pass.
- Later review checks cover configuration reload, projection edits, epic history while a sheet is open, malformed parameters, title navigation, and a late close callback. These are additional regression checks, not claimed as failing-first slices.

## Review scope

Baseline `376973a55d3af07b76932bc43c79dd72a46b933d` resolves to HEAD. The three-dot diff and commit list are empty. The requested self-review covered the working-tree diff and new files, excluding the coordinator-owned brief. Axes ran sequentially in this session.

## Standards

Reviewed local and root AGENTS plus the house baseline first.

Important finding fixed in `TicketDetail.load/3` and `EpicLive.refresh/1`: the initial adapter streamed collections but retained them in assigns too. The adapter now retains rendering metadata and streams the collections. This changes memory ownership, not public behavior; the existing render and refresh tests remained green.

Sheet visibility uses `Board.Fsm`. Section navigation adds no application mode. Fluxon owns focus, scroll lock, and dismissal animation. Allowed events use the existing machine interpreter, with no duplicate event list. No explanatory UI copy or dependencies were added.

Declined to judge pre-existing Settings copy and future preview controls. Verdict: Ready. No open Critical or Important finding.

## Spec

Reviewed second against the supplied bb-c2w.6 brief, Decisions 7, 8, and 13, and the approved mockups.

Important finding fixed in `ticket_detail.ex`, at the ticket heading: Fluxon's dialog had no accessible name. The browser found zero dialogs named for the ticket. The heading now binds `aria-labelledby` on mount, and the assertion passes.

The data and LiveView tests cover configured columns, fallout precedence, epic history, sheet fields, refused claims, sessions, notes, CR numbers, and allowed events. Browser tests cover opening from both pages, URL reload, back/forward, close, Escape, retained filters, and mobile rendering. Config changes, projection edits, and stage notifications refresh an already-open view.

Declined to judge preview controls, forge metadata and merge actions, and fabricated mockup history. Verdict: Ready. No open Critical or Important finding.

## Risk

Reviewed third, including the pinned Fluxon dialog's open synchronization, close callback, and focus handling.

The safety fact is that URL parameters select the sheet; it does not navigate away from its owning LiveView. `TicketDetail.close/2` checks the selected key before removing the query parameter. The late-callback test proves that a callback for one ticket cannot dismiss another. Browser reload, close, Escape, and back/forward checks reach proof level 5. LiveView tests reach level 4 for live updates while the sheet stays open.

Cleared risks:

- Existing sidebar filters, Settings return, storage restoration, and history navigation still pass the original filters browser runner.
- Config reload replaces column streams, including configurations with repeated titles. Column identity does not depend on the title.
- Linked draft routes retain combined history rather than losing their old identity.
- Dense and cyclic blocking graphs terminate. The dense-DAG test failed before the layer-based implementation.
- The allowed-event probe no longer collides with an actual session name. Existing overlay and machine tests pass.
- No rendering path writes beads or overlay facts. No schema, event transport, worker, or stage-transition rules changed.

Declined to judge other browser engines, long-running endurance, and future forge or preview workflows. PostgreSQL notification transport is covered by the existing full-suite tests; this browser run did not manufacture workflow events in the shared development database. The cheapest pre-merge check is `mix precommit`, followed by the sheet browser runner for Fluxon and browser history behavior.

Verdict: Ready. No open Critical or Important finding.

## Coordinator screenshot corrections

The earlier visual review accepted raw audit output and equal-height grid backgrounds. It also failed to distinguish a cropped graph capture from proof that the rightmost nodes were reachable.

All five requested fixes are applied:

1. Epic and ticket history use `BoardWeb.RelativeTime.format/1`, the same formatter as Settings. Full UTC timestamps remain in the `time` element's hover title and `datetime`. Sessions, notes, and overlay timestamps use that same component.
2. History shows the event, transition, actor, and an explicit allowlist of human payload fields. Branch, brief, report path, body, session, and epic/spec references remain. Internal effect lists and normal outcome badges are gone. Only refused claims receive a visible danger badge. Audit storage is unchanged.
3. Planned cells align at the top and size to their content, with an 80px minimum. Empty columns no longer acquire the tallest column's background height.
4. Empty fallout cells are not rendered. An epic with no fallout has no fallout band. A LiveView regression removes the final discovery edge and verifies that live refresh removes the band.
5. The graph has a width-constrained, keyboard-focusable horizontal scroll region. Browser checks assert no document overflow on desktop or mobile and scroll to the far edge to prove that the rightmost nodes fit inside the region.

Fresh screenshots replace the original captures. Additional graph-right captures show the nodes that were cropped from the initial viewport:

- bb-c2w graph: [light](../acceptance/bb-sheet/bb-c2w-graph-right-light.png), [dark](../acceptance/bb-sheet/bb-c2w-graph-right-dark.png).
- fe-lwp graph, including fe-813.9: [light](../acceptance/bb-sheet/fe-lwp-graph-right-light.png), [dark](../acceptance/bb-sheet/fe-lwp-graph-right-dark.png).

The LiveView history and fallout assertions failed before the fixes. The browser's empty-cell height assertion also failed first. All now pass. Screenshot inspection confirms relative times, readable payload labels, compact empty stages, and no empty fallout boxes.

Playwright launches Chromium with `--hide-scrollbars` by default. The runner now removes that flag, checks that the graph reserves scrollbar space, and captures both horizontal extremes. It no longer treats a left-edge screenshot as evidence for the whole graph.

Sequential follow-up review:

- Standards: no new application state or explanatory copy. The history projection excludes machine internals by construction. No open Critical or Important findings.
- Spec: all five coordinator corrections have assertions or screenshot evidence. Refused claims remain visible and audit rows remain intact. No open Critical or Important findings.
- Risk: routing, filter memory, live refresh, and sheet dismissal still pass both browser runners. The changes affect presentation only. No open Critical or Important findings.

Lesson prevention is implemented in the payload allowlist and regression assertions for text, cell height, fallout presence, document width, and graph reachability. No lesson bead was created because this session prohibits bd commands.

## Final gates

All final commands exited 0 without application warnings:

```text
mix precommit
Repository hygiene: no license material or operator paths detected
4 properties, 184 tests, 0 failures

BOARD_ROLE=web mix assets.build
Tailwind and esbuild completed successfully

NODE_PATH=<Playwright node_modules> node tools/sheet-acceptance.cjs
PASS: real epic/fallout/history screenshots, URL reload/back/forward,
close/Escape, Initiatives rows, retained filters, mobile; no page errors

BOARD_URL=http://127.0.0.1:4758 BOARD_SCREENSHOT_DIR=<temporary output> \
  NODE_PATH=<Playwright node_modules> node tools/filters-acceptance.cjs
PASS: sidebar set/clear/counts, Settings round-trip, reload, URL authority,
back/forward, bare-route restore, corrupt storage, malformed params,
browser isolation, light/dark screenshots; no page errors

git diff --check
clean
```

Initial dependency compilation emitted the existing Oban unused-clause warning. Final application gates did not. The temporary port-4758 server was stopped at handoff. No requirement in the supplied brief remains unverified. Cross-browser and endurance checks were not run.
