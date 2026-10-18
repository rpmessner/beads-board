# bb-flaky: bb-c2w.15

Implemented the approved **test-only** repair. Production code, dependencies used in production, and the host clock are unchanged. Production's occasional extra reload remains a documented known issue, not a claimed application fix.

No commits, pushes, bd commands, or subagents. The coordinator brief is untouched. The local beads export lacks bb-c2w.15, so review used the dispatched brief and the subsequent user decision.

## Cause and reproduction

Plug.Crypto 2.2.0 signs and verifies using `System.os_time(:millisecond)`. Its `validate_age/2` rejects every future timestamp, with no skew allowance. This host's clock sometimes moves backward between signing and verification.

Instrumentation of the actual Initiatives tests captured:

```text
seed: 631708
{signed_at, verification_os_time, difference_ms}:
{1792325588643, 1792325588638, 5}
Phoenix.LiveViewTest.ClientProxy.put_view/3: {:error, :invalid}
30 tests, 1 failure
```

An independent loop through `Phoenix.LiveView.Static.sign_token/2` and `verify_token/2` captured a 39 ms rollback:

```text
{1792325498740, 1792325498701, 39}
token roundtrip failure: {1742160, {:error, :invalid}}
```

A rejected session in `Phoenix.LiveView.Channel.mount/3` returns a stale join. `ClientProxy.mount_view/5` maps that to the reported absolute self-redirect. A rollback after the join can instead fail the proxy's second verification in `put_view/3`. That second failure occurred naturally at seeds 362340 and 631708.

A constructed authentic future-issued session reproduced the exact original result at seed 0:

```text
assert {:ok, _view, _html} = live(conn)
right: {:error, {:redirect, %{to: "http://www.example.com/"}}}
1 test, 1 failure
```

The original historical seed was 66350. A seed alone cannot reproduce an OS clock step. FilterRestore emits a relative query patch, not this absolute reload, and was not responsible.

Baseline runs, before the repair:

| Command | Result |
| --- | --- |
| focused file, `--repeat-until-failure 50` | 51 passes |
| full suite, `--repeat-until-failure 10` | 11 passes |
| focused file, `--repeat-until-failure 300`, join instrumentation | 65 passes, then seed 362340 failed |
| full suite, `--repeat-until-failure 40`, clock instrumentation | 41 passes |
| focused file, `--repeat-until-failure 300`, clock instrumentation | 21 passes, then seed 631708 failed |

Mix counts repetitions after the initial run. All runs used `beads_board_test_bb-flaky`. Diagnostic dependency edits were reverted and recompiled before implementation. Raw investigation logs remain in `/tmp/bb-flaky`; synthetic session tokens from diagnostic logs are not published.

## Approved repair and why this seam

The user declined a dependency fork, vendoring, a production change, and a host-clock change. The approved scope is test stability plus a permanent test and documentation of production behavior.

`test/support/live_view_clock.ex` installs a private Mimic stub on `Phoenix.Token.sign/3`. It matches only `BoardWeb.Endpoint` and its LiveView signing salt, then calls the real `sign/4` with a timestamp one second earlier. All other contexts and salts use the original implementation. Explicit `sign/4` calls are untouched.

`test/support/conn_case.ex` installs this per test. `@tag :production_token_clock` opts out. `test/test_helper.exs` prepares Phoenix.Token for Mimic, which is a test-only dependency. Mimic scopes stubs to the owning test and its caller lineage, including LiveView child processes; unrelated test processes retain the original behavior.

This is narrower than bypassing token verification: signatures, expiry, topic identity, static/session matching, route authorization, and the full LiveView join all remain real. LiveView exposes no signing-time config hook. The stub uses Phoenix.Token's existing `signed_at` option rather than copying crypto code or changing token contents after rendering. It adds no retry and does not weaken an existing assertion.

The allowance covers backwards steps up to one second. It shortens test-token lifetime by one second rather than extending validity. It does not promise tolerance of arbitrary clock corrections. Production and browser acceptance never load the helper.

## Regression evidence

`test/board_web/live_view_clock_test.exs` has five tests:

- Fixed signing and verifier instants reproduce the observed 39 ms rollback. The timestamp assertion fails without backdating, independently of elapsed test time.
- An authentic session one hour ahead is rejected by the unmodified production verification path, returning the exact bare-route reload. This is the permanent future-token probe, tagged to opt out.
- Tampered signatures and expired LiveView tokens remain rejected.
- Other salts and explicit signing options remain unchanged.
- A process without the owning test's caller lineage receives original signing behavior.

Failing-first run:

```text
mix test test/board_web/live_view_clock_test.exs --seed 0
assert signed_at == issued_at - 1000
left:  1792325498740
right: 1792325497740
2 tests, 1 failure
```

The helper initially passed its supplied timestamp through unchanged. Subtracting the allowance made the regression pass. [Red output](../acceptance/bb-flaky/clock-red.txt).

The fixed-clock test inspects the signed envelope because timestamp arithmetic is the repaired contract. It also checks the signature with real Phoenix.Token verification. Its `max_age: :infinity` is local to inspection of the historical fixture, not the LiveView join or the test environment. Expiry rejection has its own assertion.

An initial isolation-test draft used a supervised Task as if it were unrelated. It failed because Tasks correctly inherit `$callers`. The final test clears only that child's caller lineage to model an unrelated test, then asserts that the private stub is absent. No global stub mode is used.

## Final randomized loops

Both commands exited 0 on the final test implementation:

```text
mix test test/board_web/live/initiatives_live_test.exs --repeat-until-failure 49
50 consecutive randomized runs; 30 tests each; 0 failures

mix test --repeat-until-failure 9
10 consecutive randomized runs; 4 properties, 275 tests each; 0 failures
```

Every seed and summary is retained in [focused-50.txt](../acceptance/bb-flaky/focused-50.txt) and [full-10.txt](../acceptance/bb-flaky/full-10.txt). No fixed seed, retry wrapper, or excluded tests were used.

## Browser evidence

A web-only acceptance server ran on port 4771, using `beads_board_acceptance_bb-flaky`, one synthetic repo projection, and the shipped view defaults. No reader or worker was started. Port 4747 and other checkout databases were untouched.

```text
MIX_ENV=acceptance BOARD_ROLE=web mix do ecto.create --quiet + ecto.migrate --quiet + assets.build
NODE_PATH=<Playwright node_modules> BOARD_URL=http://127.0.0.1:4771 node tools/flaky-acceptance.cjs
PASS: bare route without memory, saved-filter restore, explicit URL authority; no page errors
```

Inspected [bare-light.png](../acceptance/bb-flaky/bare-light.png) and [restored-dark.png](../acceptance/bb-flaky/restored-dark.png). Search aligns with the preset buttons, selection is clear, the sidebar and epic row align, and no content overlaps. The fresh browser stays at `/`; remembered `view=all` and `q=Clock` restore into both controls and URL. Explicit clearing wins afterward.

The acceptance build confirmed that both Mimic and BoardWeb.LiveViewClock are absent. [Browser result](../acceptance/bb-flaky/browser-result.txt). No induced host-clock step was attempted in the browser.

## Review against e0cf4c3

The baseline resolves to `e0cf4c36209f91c68ca77dfdaa7fa41413536c49`, which is HEAD. The committed three-dot diff and commit list are empty. Review covered the requested working-tree changes and new deliverables, excluding the coordinator brief. Axes ran sequentially in this session.

### Standards

Ready. The helper is a stateless test adapter, not a new workflow requiring Board.Fsm. Existing machines and application code are untouched. No sleeps, unsupervised test processes, UI prose, new production dependency, or weakened assertion. The production probe reads the session attribute through LazyHTML. The AGENTS addition is one reference line pointing to the known-issues note.

No Critical or Important finding. Declined: unrelated existing test style and dependency internals, since neither is changed.

### Spec

Ready for the revised acceptance. The cause has natural clock evidence and an exact constructed redirect. The test-only allowance preserves real verification, and the permanent production test documents the rejected future session. The requested 50/10 randomized runs and browser checks pass. `docs/known-issues.md` and AGENTS document the residual browser reload.

No Critical or Important finding. Declined: repairing production's reload, publishing a fork, and changing the host clock, all explicitly prohibited by the follow-up decision.

### Risk

Ready. The safety fact is that only test-owned LiveView signing timestamps change; all verification remains real, and the stub is absent outside tests.

Important coverage gap fixed: added an explicit unrelated-process isolation regression after reviewing Mimic's `$callers` lookup. Proof level 4: all five clock tests pass, including bad signatures, expiry, production reload, unaffected salts/options, and process isolation. An acceptance-build probe prints `PASS: Mimic and test clock absent outside test build`. The browser checks give level 5 evidence for unchanged filter restore behavior without the stub.

Cleared: cross-test stub leakage, disabled verification, accidentally altered non-LiveView salts, production inclusion, and filter-restore regression. No schema, session wire format, app lifecycle, or browser JavaScript changed.

Residual limits: clock corrections larger than the allowance can still disturb tests. Dependency upgrades changing LiveView's signing call need the focused regression and browser checks. Production retains occasional extra reloads on WSL clock steps by explicit decision. Cheapest gate: `mix test test/board_web/live_view_clock_test.exs`, then precommit.

No open Critical or Important finding. Declined: non-Chromium engines, deliberate host-clock mutation, and broader authentication changes.

## Final gate

Final `mix precommit` exited 0:

```text
Repository hygiene: no license material or operator paths detected
Running ExUnit with seed: 301599, max_cases: 16
4 properties, 275 tests, 0 failures
```

[Gate output](../acceptance/bb-flaky/precommit.txt). `git diff --check` passed. An earlier gate stopped at formatting of the new supervised-Task test; formatting was corrected before this green run. Initial fresh dependency compilation emitted the existing Oban unused-clause warning; the final gate emitted no warnings.

The temporary browser server was stopped. Changed: test-only signing support, five regressions, browser verifier, known-issues documentation, and the AGENTS pointer. Verified: the red/green clock seam, 50 focused runs, 10 full runs, browser restoration and inspected screenshots, three review axes, and precommit. Not changed or claimed fixed: production behavior during actual OS clock rollback.
