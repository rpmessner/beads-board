# fm-drawer: fm-3c3.3

Coordinator corrections complete. Final gate: **5 properties, 493 tests, zero failures**. The browser matrix passed and the refreshed screenshots were inspected.

## Changes

- The Needs you badge opens a shared Fluxon sheet on every routed app page. The separate Needs you link still opens the full page.
- The drawer and page call `NeedsYouLive.request_card/1` and `NeedsYouLive.resolve/1`. Decision, push, open-PR and merge cards share the same rendering and resolution path. Drawer IDs have a prefix, so both copies can coexist on Needs you.
- The shared count hook reconciles `Requests.pending/0` on notifications and its existing three-second tick. Unchanged cards stay mounted, preserving choices and notes. Failed actions show an error inside the sheet, above the cards.
- `Foreman.RequestDrawer` declares closed/open and open/close transitions. Visibility is not URL data. Fluxon owns animation, focus trapping, Escape and focus restoration. [Machine diagram and matrix](../machines/request_drawer.md).

Decision answers, declines, push approvals and open-PR approvals stay on the current page. **Merge Approve preserves main's existing handoff to the Pull requests confirmation screen.** It does not enqueue or resolve the merge before confirmation. Cancel leaves it pending. This is the same action as Needs you, not a second merge implementation; an inline merge confirmation on every page was not added.

## Coordinator corrections

### Rebase and request kinds

Created the authorized WIP commit and rebased onto main. Main gained merge requests during verification, so a second WIP checkpoint and rebase included those too. Final base: `99e945d`; WIP commits: `e31d159` and `032fb21`. No pushes or ticket edits. Final verification additions and this report remain uncommitted.

Resolved `needs_you_live.ex` conflicts by retaining main's shared action card for push, open-PR and merge, with drawer-prefixed form IDs and its submission event. `RequestCard` retains main's facts and summaries unchanged. The shared resolver returns the same confirmation destination to either entry point for merge approval.

The new open-PR regressions cover approval, decline, notes and enqueue counts. The existing merge-confirmation test now runs from both the inbox and a Settings drawer: approval opens confirmation without a job, cancellation leaves the ask pending, and confirmation creates exactly one job.

### Badge and spacing

Restored main's small filled pill classes, padding, dimensions and placement. The link retains its original 36 px navigation row. The badge is an independently clickable sibling positioned within that row, rather than a 40 px circle that expands the row.

The browser compares the badge's dimensions, fill, border, font and padding against a reference rendered from main's original markup. It also compares the subsequent navigation rows' vertical offsets. The first run failed with **40 × 40 px instead of 26.359375 × 22 px**: [red badge result](../acceptance/fm-drawer/red-badge.txt).

### Initial focus

The drawer heading has `tabindex=-1`, `autofocus` and no outline. Fluxon focuses it after opening. No interactive control shows a focus ring until keyboard navigation begins. The browser waits for Fluxon's opened event, asserts heading focus, and captures the initial state **before** exercising Tab.

The initial focus assertion failed before the change: [red focus result](../acceptance/fm-drawer/red-focus.txt). Each matrix case then exercises 24 forward and 24 backward Tab presses, Escape, and focus return to the badge.

Prevention: I treated a larger click target as harmless and inspected screenshots taken after keyboard traversal. That missed both the navigation shift and the initial-focus presentation. Rung 2 adds executable geometry, spacing and initial-focus checks. No lesson ticket was written because this build prohibits ticket edits and bd.

## Review

The initial review used `9bac717f039da142c93752cd2176b3ed265fa420`. The correction review compares the rebased drawer against `99e945d`, including the remaining working-tree changes. Axes ran sequentially without subagents.

### Standards

Visibility still goes through the declared machine. UUID sets and error text are rendering data, not additional modes. Streams, shared cards, human timestamps and `to_form` remain. Badge styles now match main. Initial focus uses Fluxon's supported autofocus mechanism, without a new JavaScript hook or lifecycle.

No open Critical or Important finding. Declined to judge unrelated page styling and existing worker internals. Verdict: ready.

### Spec

All requested corrections hold. The badge, focus and request-kind checks pass alongside the original matrix on Initiatives, Pull requests, Settings and Documents, in both themes at 390 and 1440 px. LiveView tests also cover Needs you and the Epic route.

Inspected all 16 refreshed matrix captures through both contact sheets, plus full-size samples and the open-PR and merge captures. The small badge and navigation alignment are restored; initial captures contain no control focus ring. Fields and actions remain visible, with no horizontal overflow.

Merge approval retains main's confirmation navigation as described above. Declined to judge redesigning that shared confirmation flow, session-waiting kinds not in this base, other browser engines and deployment. No open finding against this correction request. Verdict: ready.

### Risk

The safety fact is unchanged: `Requests.resolve/3` locks the repository, rereads the request, and commits its transition and job enqueue in one transaction. The drawer uses that boundary. Proof level 4: stale page approval after drawer approval produces one push job and preserves the first note; stale decline cannot replace a drawer answer. Independent-connection races pass. Open-PR approval and decline preserve notes and the expected job counts. Merge approval from either entry point cannot bypass confirmation.

The initial review found that global flash errors were hidden behind the sheet. The failing-first inline-error regression remains green. The browser also checks blank-answer refusal, input preservation during incoming requests, resolution and empty reopening.

No open Critical or Important finding. Declined to judge live external writes and installed deployment; this build runs no external action workers. Cheapest repeat check: the focused command below. Verdict: ready.

## Final verification

```text
mix test test/foreman_web/live/request_drawer_test.exs \
  test/foreman_web/live/needs_you_live_test.exs \
  test/foreman_web/live/pull_requests_live_test.exs \
  test/foreman/request_drawer_test.exs test/foreman/request_commit_test.exs
31 tests, 0 failures

MIX_ENV=acceptance mix assets.build
Tailwind and esbuild succeeded

NODE_PATH=<Playwright modules> node tools/drawer-acceptance.cjs
PASS four pages × two widths × two themes; unchanged URL, focus trap, Escape, focus return
PASS shared cards; simultaneous page/drawer IDs; incoming request preserves draft; answer, decline and empty reopening
PASS main badge geometry/nav spacing; heading focus without control ring; open-PR approve/decline; merge card/decline
PASS zero browser errors

mix precommit
Repository hygiene: no license material or operator paths detected
5 properties, 493 tests, 0 failures
exit 0; seed 806038

git diff --check
clean
```

Logs: [focused](../acceptance/fm-drawer/focused.txt), [browser](../acceptance/fm-drawer/browser.txt), [precommit](../acceptance/fm-drawer/precommit.txt). Final gates emitted no warnings. An intermediate hygiene run rejected absolute checkout paths in two new failure transcripts; those stack-frame paths were made relative before the successful rerun.

Inspected captures: [390 px matrix](../acceptance/fm-drawer/contact-390.png), [1440 px matrix](../acceptance/fm-drawer/contact-1440.png), [open PR](../acceptance/fm-drawer/open-pr-390-dark.png), [merge](../acceptance/fm-drawer/merge-390-dark.png). Individual matrix files use `{page}-{width}-{theme}.png` in the same directory.

Test-first history: the original badge/list test and inline-error regression failed before their implementations. Original action, live-update and keyboard tests were added after the initial implementation, not a complete failing-first trail. Removing resolution and reconciliation each caused two failures; both mutations were restored. The correction's badge and heading-focus assertions failed before their fixes. Evidence: [inline-error red](../acceptance/fm-drawer/red-error.txt), [action mutation](../acceptance/fm-drawer/mutation-actions.txt), [refresh mutation](../acceptance/fm-drawer/mutation-refresh.txt).

Tests use `foreman_test_fm-drawer`. Browser fixtures use `foreman_acceptance_fm-drawer` on port 4783, with workers disabled. The preview server is stopped. The installed service, config and database were not modified. An initial fixture subprocess attempted to bind the occupied default port because an empty `PHX_SERVER` is truthy; it failed before startup. The runner removes that variable and specifies a separate port.

Changed: the shared drawer, restored badge geometry, explicit heading focus and integration with all request kinds in the rebased main.
Verified: the commands, inspected captures and review checks above.
Not verified: installed deployment, other browser engines or live external writes. Merge approval intentionally retains the existing confirmation navigation rather than an inline confirmation.
