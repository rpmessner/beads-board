# fm-waiting: fm-3c3.2

Complete. Final `mix precommit`: **5 properties, 544 tests, zero failures**. The safety suite and live scratch browser checks pass. No commits, pushes, ticket edits, subagents, or installed-service changes.

## Changes

- `Foreman.SessionHooks` supplies inline per-launch `--settings` JSON. Global Claude settings remain untouched.
- `Foreman.SessionWaiting` registers the request kind, validates the session/window, deduplicates pending waits, and clears them on activity or window loss. Waiting requests cannot approve or enqueue a job.
- `Foreman.SessionMachine` declares waiting/resumed rows, the matching-activity guard, and clearing effects. `Foreman.Request` declares a pending-to-pending Continue event guarded by `session_waiting` plus `usage_limit`, with the single `send: :continue` effect.
- The shared Needs you and drawer card shows the reason, optional provider/reset time, and selectable attach command. Only usage-limit cards have Continue. Existing browser notification delivery includes the new kind.
- `SessionTmux` sends literal `continue` followed by Enter only through the explicit form submission. Planning windows use the board socket and revalidate their session UUID. Coordinator windows use the explicit default socket and stable window/pane/PID identities. Tests override both sockets with temporary servers.

Coordinator CLI contract:

```sh
foreman ask session_waiting <ticket> --project <project> \
  --session <planning-uuid-or-build-session> --reason input

foreman ask session_waiting <ticket> --project <project> \
  --session <build-session> --reason usage_limit --window <pi-window> \
  --provider Codex --reset-at '14:00'
```

Reasons are `input`, `permission`, and `usage_limit`. Provider and reset time are optional. The coordinator posts the second form after `pi-wait` returns LIMITED. This build does not edit the dispatch skill.

## Installed hook contract

Claude Code 2.1.303's installed registry and implementation were inspected, alongside `claude --help`. It supports PermissionRequest, Stop, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, StopFailure, and Notification. StopFailure supplies `error`, `error_details`, and `last_assistant_message`. Launched Claude limits therefore use StopFailure, not a pane fallback.

PermissionRequest reports a permission wait. AskUserQuestion is an input wait, including its PermissionRequest event. Stop reports end-of-turn input. UserPromptSubmit clears a wait. Matching tool completion clears a tool-specific wait. Tool-start activity and `quota_auto_resume_fired` clear a provider stop without clearing an unrelated permission wait.

Two installed-API facts matter:

- PermissionRequest does not supply tool_use_id in this version. Correlation hashes tool name and input; command text is not stored in the request.
- AskUserQuestion adds `answers` and `annotations` to tool_input on PostToolUse. A live scratch proxy confirmed the payload shape. Its correlation uses only the original questions.

Hooks call the CLI through bounded, silent shell commands that return zero even when the executable is missing. The runtime token-file location is forwarded without embedding its contents. Hook delivery is transient, so an outage cannot queue stale waiting/resume signals for later replay. Deploy the updated CLI with the app; already-running sessions retain their original launch settings.

## Live verification

The isolated app used port 4786 and `foreman_acceptance_fm-waiting`. Unit tests used `foreman_test_fm-waiting`. Real Claude ran only in `/tmp/fm-waiting-live` on `fm-waiting-live`; the coordinator-window receiver used `fm-waiting-external`. The installed port-4747 app, its database, and its tmux server were untouched.

The final browser runner passed:

1. A real Claude Bash permission prompt produced exactly one pending request **465 ms after the prompt was observed**, plus one native browser Notification constructor call. The request remained pending while the prompt was open, including after a parallel Read completed. Answering in tmux cleared it.
2. The runner read the actual launched `--settings` and invoked its StopFailure command with a simulated rate-limit payload. The request showed Anthropic and reset time. Clicking Continue in the browser sent it to the planning window; the displayed `continue` turn and resume hook confirmed delivery and clearing.
3. The actual CLI posted a coordinator usage-limit request naming Codex and 14:00. Before the click, the receiver had no input. Clicking Continue delivered exactly `continue` plus Enter to the other temporary socket. New pane output cleared the request.
4. Needs you and the drawer rendered in light and dark at 390 and 1440 px, with no document overflow or browser errors.
5. The global Claude settings SHA-256 remained identical before and after all launches.

All eight final screenshots were opened and inspected. The attach command wraps on mobile, the Continue control remains visible, and text/border contrast is readable in both themes. No clipped controls or overlapping content appeared.

Evidence: [browser result](../acceptance/fm-waiting/browser.json), [browser log](../acceptance/fm-waiting/browser.txt), [permission timing](../acceptance/fm-waiting/permission-timing.json), [permission pane](../acceptance/fm-waiting/permission-pane.txt), [planning Continue](../acceptance/fm-waiting/continued-planning-pane.txt), and [settings hashes](../acceptance/fm-waiting/global-settings.json). Screenshots are `{waiting,drawer}-{390,1440}-{light,dark}.png` in the same directory.

The guarded server and browser runners are `tools/waiting-acceptance.exs` and `tools/waiting-acceptance.cjs`. They require the scratch fixtures and temporary sockets described above. Browser execution uses Playwright with full Chromium, which honors real notification permission.

## Review scope

Fixed point `151d8dbb50e094145f78d3ad6f7f229e12ea9cb5` is HEAD. The committed diff and commit list are empty because commits are prohibited. Review covers the requested working-tree diff and new deliverables, excluding the coordinator-owned brief. Standards, Spec, and Risk ran sequentially without subagents.

## Standards

The initial review found the matching-tool resume guard and clearing effects outside the session machine. A failing machine regression preceded moving those into `SessionMachine`. Continue eligibility/effect is now declared in `Request`, with `SessionWaiting.continue/1` interpreting that effect rather than duplicating the state guard. Both generated machine documents are refreshed.

Other lifecycle changes use the existing request machine. Templates reuse shared cards, streams, and human timestamps. No dependency or migration was added. The final formatter, compilation, hygiene, and full test gates pass.

Declined to judge unrelated app styling and later parking/relaunch behavior. Verdict: ready; no open Standards finding.

## Spec

Every fm-3c3.2 acceptance item is covered by the focused tests or live checks above. Planning and coordinator limit paths both work. Continue appears only for usage limits, sends only on explicit submission, and does not approve or enqueue a job. Permission/input waits clear on the matching activity, including answered question tools.

The live probe found a real parallel-tool race: a Read completion initially cleared a blocked Bash request. The failing regression preceded the correlated-completion fix. A later probe exposed the AskUserQuestion payload enrichment described above; its failing regression preceded normalization. Automatic quota resume also has a guarded activity regression.

An intermediate browser run simulated a provider stop before Claude left its question menu. The runner now requires an ordinary input prompt and waits for the submitted turn to render. The final full run passed after all production changes.

Declined to judge real account exhaustion, parking/relaunch, and installed deployment. Provider failure is simulated through the actual launched hook rather than exhausting an account. Verdict: ready; no open Spec finding.

## Risk

The safety fact is that only an explicit usage-limit form submission reaches the constant `continue` plus Enter commands. `Request` rejects Continue for other kinds, reasons, and states. The repository lock serializes request revalidation with resumed signals. The request stays pending until observed activity clears it; there is no automatic retry or background send.

Proof level 5: the running browser sends to a real Claude planning window and to an independent receiver on a different temporary socket. The receiver observes no input before the click and exactly `continue` afterward. Proof level 4: the 46-test safety suite checks the machine guard/effect, wrong reasons, stale requests, wrong session UUID, exact argv, window lookup, and resumed clearing. Missing hook executables return zero with empty output.

Review findings fixed:

- `lib/foreman/session_waiting.ex:71` formerly checked Continue eligibility imperatively. It now consumes the declared guard/effect at `lib/foreman/request.ex:42`. The machine test failed before that change.
- `lib/foreman/session_tmux.ex:74` now selects `-L default` explicitly for coordinator windows. An inherited TMUX environment cannot silently select another socket. The attach command uses the same socket selection.
- `lib/foreman/session_hooks.ex:99` excludes Claude-added answer metadata from question correlation. The live payload probe and failing regression establish the required normalization.

Cleared: silent sends, arbitrary board-supplied text, non-usage Continue, stale resolved clicks, wrong planning UUID, ambiguous window names, cross-socket delivery, global-settings writes, and a failed hook interrupting Claude.

Residual limits: hooks are best-effort while the board is unavailable. External pi activity uses visible pane-content changes, so a terminal redraw can count as activity; no raw pane text is persisted. A same-user actor can replace a terminal between validation and send. Repeated explicit clicks while a request remains pending are separate user actions, not an exactly-once transport guarantee. These do not enable automatic typing or arbitrary text.

Declined to judge hostile same-user process manipulation, actual provider exhaustion, other browser engines, and installed deployment. The cheapest repeat gate is the focused safety suite below. Verdict: ready; no open Critical or Important Risk finding.

## Final gates and cleanup

```text
mix test test/foreman/request_machine_test.exs test/foreman/session_machine_test.exs \
  test/foreman/session_waiting_test.exs test/foreman/session_hooks_test.exs \
  test/foreman/session_tmux_test.exs test/foreman/sessions_test.exs \
  test/foreman_web/live/needs_you_live_test.exs test/foreman_web/live/request_drawer_test.exs
46 tests, 0 failures

node tools/waiting-acceptance.cjs  # with Playwright and scratch credentials configured
3 PASS lines; zero browser errors

mix precommit
5 properties, 544 tests, 0 failures; seed 627800

git diff --check
clean
```

Logs: [safety](../acceptance/fm-waiting/safety.txt), [precommit](../acceptance/fm-waiting/precommit.txt). Failing-first artifacts cover [Continue](../acceptance/fm-waiting/red-continue.txt), [parallel completion](../acceptance/fm-waiting/red-parallel-tool.txt), [question answers](../acceptance/fm-waiting/red-question-answer.txt), and [activity](../acceptance/fm-waiting/red-activity.txt). Initial request-kind, per-launch settings, CLI facts, card, and tmux Continue tests also failed before implementation. Additional refusal and integration assertions are regression coverage, not claimed as an entirely failing-first suite.

The final gate emitted no warnings. Initial dependency compilation emitted the existing Oban unused-clause warning. No product warning remains.

Both scratch tmux servers, the scratch Claude process, and the port-4786 app are stopped. [Cleanup evidence](../acceptance/fm-waiting/cleanup.json) confirms this. Scratch files and the isolated database remain for reproduction; the worktree remains uncommitted for the coordinator.

Changed: session waiting hooks, requests, machine rows, cards, notifications, and guarded Continue.
Verified: focused tests, real permission prompt, both simulated limit paths, exact input delivery, eight inspected screenshots, unchanged settings, and precommit.
Not verified: installed deployment or actual account exhaustion. No fm-3c3.2 acceptance item remains open.
