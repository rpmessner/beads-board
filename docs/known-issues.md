# Known issues

## LiveView reloads during OS clock rollback

On WSL, an OS clock step backward can make a newly signed LiveView session appear to come from the future. Plug.Crypto 2.2.0 rejects that token. LiveView then requests a reload of the current URL. The browser can incur an occasional extra reload; repeated clock steps can repeat the rejection. This affects any LiveView, not just Initiatives or saved filters.

Observed rollbacks were 5 ms and 39 ms. Production signing, verification, and the host clock are unchanged by decision. No dependency fork or vendored patch is used.

Tests install a process-scoped Mimic stub for `Phoenix.Token.sign/3` through `BoardWeb.ConnCase`. Only this endpoint's LiveView signing salt is affected: tokens are issued one second earlier. The real signer and all verification still run, including signature validation, expiry, and session checks. This covers small rollbacks up to one second, not arbitrary clock changes. Other salts and explicit `sign/4` calls are unchanged. The allowance slightly shortens test-token lifetime; it does not extend expiry or accept invalid signatures.

`@tag :production_token_clock` opts a ConnCase test out. `test/board_web/live_view_clock_test.exs` preserves the production contract: an authentic future-stamped session is rejected, and the client reloads the bare URL. Its fixed-clock regression documents the allowance separately from wall-clock timing. Browser acceptance does not load the stub.

Investigation and verification: [bb-flaky session report](sessions/bb-flaky.md).
