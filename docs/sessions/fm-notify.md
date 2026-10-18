# fm-notify — fm-zgd.2

Build on `fm-notify`; no commits, pushes, ticket edits, or subagents. The installed port-4747 services and database were not touched. Acceptance uses port 4771 and `foreman_acceptance_fm-notify`; unit tests use `foreman_test_fm-notify`. The temporary acceptance server is stopped (port 4771 no longer responds).

## Changes and delivery design

- `Foreman.NotificationPermission` declares unavailable/default/requesting/granted/denied and the click-only prompt effect. The browser interprets its compiled transition table; there is no separately maintained JS permission machine. [Diagram and matrix](../machines/notification_permission.md).
- The shared sidebar offers **Turn on notifications** only at default permission, near navigation rather than below a potentially long page. Granted, denied, unsupported and outstanding-prompt states hide it. Permission changes are observed without prompting.
- The existing shared count hook sends minimal pending-request snapshots on invalidation and three-second reconciliation. Hook mount/reconnect requests a fresh snapshot too. Count and title still derive from the authoritative pending requests.
- A same-origin Web Lock serializes the read/claim/notify operation across tabs. The localStorage UUID ledger survives reloads and LiveView navigation. No lease, heartbeat, leader expiry, service worker or push service is needed. A first visit baselines the existing inbox without toasting old asks; subsequent unseen pending requests are delivered, including ones recovered after reconnect. Requests seen without permission are not replayed on opt-in.
- The ledger is written before calling the native Notification constructor. Storage failure fails closed; a throwing constructor releases its claim for reconciliation to retry. Notification text is kind plus ticket, with a stable request tag. Clicking focuses the owning window and follows the existing Needs you link.

## Review scope

Fixed point: `f1b4f91fdae5b78c37ae88be5a5ce7678ea6265c`, also HEAD. Three-dot diff and commit list are empty because commits were prohibited. The requested self-review instead covers the complete working-tree diff and new implementation/test files, excluding the coordinator-owned brief. Axes ran sequentially, without subagents.

### Standards

Reviewed root/app AGENTS, the house baseline, and existing machine and LiveView conventions.

The real UI lifecycle is declared on `Foreman.Fsm`, and the browser table is derived from `step/3`. Persistent request IDs are a deduplication set, not another ad hoc lifecycle. JS owns only a uniquely identified ignored hook subtree. No new dependency, raw script template, user-derived atom, or ticket write was added. Tests cover every permission state/event pair's prompt eligibility and the generated table, with a golden machine document.

The initial browser run exposed a permission race: reconciliation made the control visible while a prompt was outstanding. A failing browser assertion preceded the `requesting + default -> stay` / explicit dismissal transition fix.

Declined to judge: unrelated pre-existing page styling and workflow machines. Verdict: Ready; no open Critical or Important Standards finding.

### Spec

Reviewed fm-zgd.2's five acceptance items and Decision 10. The browser checks cover the default-only explicit control; no permission call on load; real granted and denied browser permissions; two same-context tabs receiving one actual Notification constructor call per new UUID; matching badges and titles; click navigation; and reconnect recovery. Labels use request kind and ticket, not question/facts. No push-service or service-worker scope was added.

All four control screenshots were opened and inspected. The control is visible beside navigation at both widths, light/dark contrast is readable, and no overflow or overlap appears. An early capture caught CSS theme transitions mid-frame; the runner now disables animations during screenshots rather than changing working theme styles.

Builder ruling: first use baselines existing pending requests, avoiding an opt-in backlog storm; later reconnects recover unseen pending requests. Permission denied leaves the inbox operational. This implements “new pending request,” not “notify every existing request on enabling.”

Declined to judge: forge push/PR/merge execution and skill wiring, which belong to other tickets; Windows/macOS OS chrome cannot be inspected in this Linux browser harness. Verdict: Ready subject to the final gate below; no open Critical or Important Spec finding.

### Risk

Safety fact: every tab uses the same Web Lock, and a request's durable claim must succeed before any native notification side effect. Proof level 5: the running app, real CLI asks, two pages in one browser context, native constructors, repeated snapshots, reload/navigation, both sockets disconnected then reconnected, and one peer closed. Each new request produced exactly one notification. Badge/title reconciliation remained intact.

Important finding fixed: writing the ledger after constructing a notification repeated delivery when storage was full. The failing browser test observed **6 notifications instead of 3**. Claim-before-notify now passes that test, and the same pending request delivers once after storage is restored. Constructor exceptions release the claim for retry; they cannot break LiveView's count.

Cleared: normal cross-tab duplicates; replay on reload/navigation; missing a still-pending request after reconnect; dependence on a particular tab staying open; permission prompts from broadcasts; denied permission breaking counts; exception leakage into the browser page. Browser error collection is empty.

Limits: deduplication is per browser profile and origin (localhost and 127.0.0.1 are different origins). No browser API can atomically commit localStorage and OS notification delivery: a process crash between the durable claim and native construction can lose that one toast. The authoritative inbox remains intact. OS notification suppression/Do Not Disturb is outside the API's guarantees. The UUID ledger is retained to avoid stale-snapshot replay; a full or corrupt store fails closed. Browsers without Web Locks or Notification support hide the control and retain the inbox. A request resolved while all tabs are disconnected is not replayed as pending on reconnect.

Declined to judge: other browser engines, native Windows/macOS visual appearance, multi-profile delivery and long-term storage endurance. Verdict: Ready within Notification API guarantees; no open Critical or Important Risk finding. Cheapest repeat check: the committed browser runner against the isolated acceptance server.

## Evidence and final gate

Test-first trail:

- The initial explicit-control browser check failed because `#enable-notifications` did not exist, then passed with the machine-driven control. The full Chromium default-permission run uses a held/dismissed permission boundary to prove the only request call follows the click.
- The two-tab delivery check failed waiting for a native notification before delivery was implemented, then passed.
- The storage-failure and outstanding-prompt regressions failed on their assertions before fixes, as described above.
- Machine table/golden and server snapshot tests were added afterward as regression checks, not claimed as failing-first evidence.

Fresh commands and results:

```text
mix test test/foreman/notification_permission_test.exs test/foreman_web/live/needs_you_live_test.exs
9 tests, 0 failures

MIX_ENV=acceptance mix assets.build
Tailwind and esbuild succeeded

NODE_PATH=<Playwright modules> node tools/notifications-acceptance.cjs
8 PASS lines; no browser errors

mix precommit
Repository hygiene: no license material or operator paths detected
5 properties, 429 tests, 0 failures
exit 0

git diff --check
clean
```

The first precommit attempt found an already-unformatted line in `test/test_helper.exs`; its only change is formatter output, required to pass the gate. Initial dependency compilation emitted the existing Oban unused-clause warning; the final gate had no warnings.

Full logs: [browser](../acceptance/fm-notify/browser.txt), [precommit](../acceptance/fm-notify/precommit.txt).

Inspected captures: [390 light](../acceptance/fm-notify/control-390-light.png), [390 dark](../acceptance/fm-notify/control-390-dark.png), [1440 light](../acceptance/fm-notify/control-1440-light.png), [1440 dark](../acceptance/fm-notify/control-1440-dark.png).

Harness gotcha captured in the runner: Playwright's headless-shell reports `Notification.permission === "denied"` even when its Permissions API reports granted. `channel: "chromium"` uses full Chromium and correctly exercises real granted/denied permissions. Granted tests subclass and call the actual native constructor, recording its title/tag; click handling is invoked programmatically, not through a real OS toast. No claim is made that Linux screenshots show a Windows or macOS toast.

Changed: browser permission control, declared permission machine, cross-tab durable delivery and snapshot reconciliation.
Verified: the live browser behavior, four inspected captures, focused tests and full precommit above.
Not verified: deployment to the installed service, OS-specific chrome and other browser engines.

## Coordinator correction: opt-in affordance

The initial control was readable but looked like small explanatory text, not the only opt-in action. It now sits immediately after Settings inside the navigation, with a bell icon and the shared `bb-nav` typography, full-row hit target, height, spacing, hover background and keyboard focus ring. The ignored hook container and permission machine remain unchanged; granted, denied, unsupported and prompting states still hide the item.

The browser regression first failed on the missing bell. It now checks icon presence; equal font size/weight/color, padding and radius; equal row height/width/alignment and inter-row spacing; shared hover color and visible keyboard focus. The full delivery suite still passes, with an additional unsupported-browser visibility check.

All four linked screenshots were replaced and opened: light/dark at 390/1440 px. The bell and text align with Settings, the label fits on one line, and the item now reads as a sidebar action. No overflow or overlap appeared.

Follow-up review ran Standards, then Spec, then Risk: shared styling and the standard icon component; the requested position and hidden states; then unchanged delivery/permission behavior verified by the full browser runner. No open finding remains. The shared focus rule also gives navigation links the same explicit keyboard ring.

Prevention (rung 2, executable regression): I had checked legibility rather than clickable affordance. Browser assertions now compare the control's geometry and interaction styling with its adjacent nav item, so the original tiny text treatment fails. No lesson ticket was created because the coordinator owns tickets and this build prohibits bd.

Fresh final gate: `mix precommit`, seed 417188 — **5 properties, 429 tests, 0 failures**, exit 0. Updated browser log has eight PASS lines and zero browser errors. The temporary port-4771 server was stopped after verification; the installed services were untouched.
