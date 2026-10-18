---
id: fm-c2w.19
title: "Flaky: LiveViewClockTest isolation test misses its 100 ms assert_receive under full-suite load"
type: bug
status: closed
priority: 2
parent: fm-c2w
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Fixed: wait on task DOWN; seed 909275 + 10 full runs green."
---

## What to build
Found by the bb-files session (2026-10-18): "a test's clock allowance does not leak to an independent process" in the LiveView clock test (added for bb-c2w.15) intermittently times out at its default 100 ms assert_receive in full-suite runs; seed 909275 reproduces it on main's code alone.


## Acceptance
- [ ] Reproduce at seed 909275 (full suite, without the bb-files changes)
- [ ] Fix the cause: the test waits on a supervised Task with the default 100 ms assert_receive; wait on the task deterministically instead (monitor or Task result), not a longer sleep
- [ ] Full suite 10 randomized runs green
