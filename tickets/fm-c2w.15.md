---
id: fm-c2w.15
title: "Flaky: Initiatives first visit sometimes redirects in LiveView tests"
type: bug
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.13"]
related: []
discovered_from: fm-c2w.9
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Cause: WSL clock rollback vs Plug.Crypto future-token check. Test-only signing allowance; 50 focused + 10 full randomized runs green; documented. Merged."
---

## What to build
Found during bb-c2w.9 review (2026-10-18): a recorded transient precommit failure. The first bare visit to Initiatives can redirect inside a LiveView test.


## Acceptance
- [ ] Reproduce: test/board_web/live/initiatives_live_test.exs:227 sometimes fails with {:error, {:redirect, %{to: "http://www.example.com/"}}} on live(conn, "/")
- [ ] Root cause found (FilterRestore first-bare-route redirect racing the session/localStorage seed is the suspect) and fixed in the code, not by retrying the test
- [ ] The test passes 50 runs in a row with random seeds
