# bb-tabs: bb-c2w.16

## Changed

`TicketDetail` now uses Fluxon's tabs and mounted panels. Initiatives, Pull requests, and the existing Epic sheet caller share the component. Each URL patch keeps the ticket and page filters. Closing removes `ticket` and `tab`; opening another ticket starts at Overview. Hidden history, sessions, and notes keep their existing stream refresh path.

The tab is validated URL data (`overview`, `history`, `sessions`, `notes`), not a new machine. Missing, unknown, and malformed values select Overview. No tab changes which events are accepted or introduces guards, effects, or a lifecycle. `Board.TicketSheet` still owns visibility through `Board.Fsm`; Fluxon owns keyboard focus and panel visibility. There is no separate application-side tab state to synchronize.

Fluxon fits: server-driven selection, preserved panel DOM, ARIA relationships, arrow-key activation, and focus styling. No new JavaScript hook or dependency was needed. Tab labels stay on one line; the sheet reserves scrollbar space to prevent horizontal layout shifts between panels.

## Review scope

Reviewed the working-tree changes against `4229013b15f332694e3bd6895422066d2462d347`, which is HEAD; the committed diff and commit list are empty. Standards ran first, then Spec, in this session without subagents. The coordinator-owned brief was not changed. Read the ticket from `git show main:.beads/issues.jsonl`; this checkout's export predates it.

## Standards

Reviewed the root/app rules and house baseline against the implementation, LiveView tests, and acceptance runners. Tab selection is pure URL normalization, covered by the baseline's data exception, not an ad hoc lifecycle. Streams remain mounted and are not copied into retained assigns. Existing relative times and label-only controls are unchanged.

Minor finding fixed: replaced the implementation comment above `TicketSheet.tab/1` with a public normalization contract. No Critical or Important findings. No open findings. Declined to judge future preview behavior and unrelated existing sheet content. Verdict: Ready.

## Spec

Reviewed second against all six acceptance items in bb-c2w.16. Both pages show one panel, select tabs from the URL, restore selection on reload/back/forward, and fall back to Overview. Browser checks exercise arrow-key wrapping, visible focus, close/Escape, and new history/session/note rows received while all three panels are hidden.

Findings fixed:

- The narrow sheet's scrollbar caused tab labels to wrap. A browser assertion failed before the no-wrap/spacing and stable-gutter fix in `TicketDetail.sheet/1`. All four labels now fit at 390 px.
- The older `tools/sheet-acceptance.cjs` still tried to scroll to the now-hidden history section. It now selects Overview and Stage history explicitly before its captures. The new runner exercises those same selectors; the older runner's unrelated real-project fixture matrix was not rerun.

No open Critical or Important findings. No deferred product work. Declined to judge the future preview tab and other browser engines. Verdict: Ready.

## Verification

Failing-first evidence:

- `mix test test/board_web/live/initiatives_live_test.exs` failed on the absent selected Overview tab before implementation.
- The close assertion failed because `tab=history` survived closing; `TicketSheet.path/2` now removes both sheet parameters.
- The browser runner failed on wrapped tab labels before the narrow-width fix.

The URL-preservation and hidden-stream assertions passed against the first tab implementation and existing stream loader, respectively. Mutation checks then proved both assertions detect regressions: deleting `ticket` from the tab patch failed the exact URL assertion; loading notes only when selected failed the hidden-note assertion. Both mutations were removed. The focused two-file suite passed with 42 tests.

`tools/tabs-acceptance.exs` runs committed fixtures in `beads_board_tabs_acceptance_bb-tabs`, separately from `beads_board_test_bb-tabs`. It uses port 4766 and disables workers. The acceptance runner mutates only that fixture database. No installed-board service, database, or beads files were touched.

Browser synchronization must wait for LiveSocket's pending history patch and Fluxon's opened event, not merely the optimistic selected-tab DOM. The runner does both; early attempts raced dialog focus after browser history navigation.

### Screenshots

Captured all four tabs plus keyboard focus on both pages, in light/dark at 390 and 1440 px. Inspected all four-panel combinations as contact sheets, plus full-page and keyboard captures. No overlapping controls, wrapped tab labels, or document overflow remain. History and long notes scroll within the sheet.

All 40 captures are in [bb-tabs acceptance](../acceptance/bb-tabs/), named `{page}-{width}-{theme}-{tab-or-keyboard}.png`. Representative captures:

| Page | Wide light | Wide dark | Narrow light | Narrow dark |
| --- | --- | --- | --- | --- |
| Initiatives | [Overview](../acceptance/bb-tabs/initiatives-1440-light-overview.png) | [History](../acceptance/bb-tabs/initiatives-1440-dark-history.png) | [Sessions](../acceptance/bb-tabs/initiatives-390-light-sessions.png) | [Notes](../acceptance/bb-tabs/initiatives-390-dark-notes.png) |
| Pull requests | [Overview](../acceptance/bb-tabs/pull-requests-1440-light-overview.png) | [History](../acceptance/bb-tabs/pull-requests-1440-dark-history.png) | [Sessions](../acceptance/bb-tabs/pull-requests-390-light-sessions.png) | [Notes](../acceptance/bb-tabs/pull-requests-390-dark-notes.png) |

Keyboard focus: [Initiatives light](../acceptance/bb-tabs/initiatives-1440-light-keyboard.png), [Pull requests dark](../acceptance/bb-tabs/pull-requests-1440-dark-keyboard.png).

## Coordinator correction: repeated panel headings

Removed the Stage history, Sessions, and Agent notes headings beneath their matching tabs. Overview's per-block labels remain. I had preserved the old section markup without noticing that tab labels now provide the same context.

Prevention: a LiveView regression rejects direct panel headings in those three sections and verifies that Overview retains its headings. It failed on `#ticket-history-section > h3` before the removal. No lesson bead was created because this session prohibits bd commands.

Fresh verification after the correction:

- Focused Initiatives and Pull requests tests: 42 tests, 0 failures. [Transcript](../acceptance/bb-tabs/focused.txt).
- Assets rebuilt; the complete tabs browser runner passed again with no page errors.
- Refreshed all 40 screenshots. Inspected the affected panel tops for both pages, both themes, and both widths. Content now starts directly below the tabs, with no repeated headings or spacing defects.
- `mix precommit`: 4 properties, 279 tests, 0 failures.

The coordinator finding is resolved; no open findings remain.

### Final gates

```text
mix precommit
Repository hygiene: no license material or operator paths detected
4 properties, 279 tests, 0 failures

BOARD_ROLE=web mix assets.build
Tailwind and esbuild completed successfully

NODE_PATH=<Playwright node_modules> node tools/tabs-acceptance.cjs
PASS: both pages × light/dark × 390/1440; all tabs, reload/back/forward,
keyboard arrows and visible focus, close/Escape,
hidden live history/sessions/notes; no page errors

git diff --check
clean
```

Gate transcripts: [precommit](../acceptance/bb-tabs/precommit.txt), [browser](../acceptance/bb-tabs/browser.txt).

Initial dependency compilation emitted the existing Oban unused-clause warning; the final application gates emitted no warnings. The temporary port-4766 server was stopped after verification. No commits, pushes, bd commands, or subagents. The coordinator owns ticket closure.
