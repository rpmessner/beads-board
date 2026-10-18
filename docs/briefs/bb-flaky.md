You are a build session in beads-board (~/dev/utils/bb-flaky, a git worktree on branch `bb-flaky`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Remove the intermittent failure where the first bare visit to Initiatives in a LiveView test returns `{:error, {:redirect, %{to: "http://www.example.com/"}}}` from `live(conn, "/")` (seen at test/board_web/live/initiatives_live_test.exs:227 during a precommit run). Find the real cause and fix it in the code, so the suite is deterministic; a retry or a loosened assertion is not a fix. If the cause is a real user-facing bug (a bare visit redirecting away when it should not), the fix covers the app, not only the test.

## Read first
- AGENTS.md (app house rules at the top; Elixir rules in ~/dev/AGENTS.md: no Process.sleep in tests).
- bead bb-c2w.15; docs/sessions/bb-filters.md and docs/sessions/bb-views.md (the filter restore and view presets that own the first-bare-route redirect); docs/sessions/bb-merge.md (where the failure was recorded).
- The FilterRestore code and its hook, the Initiatives LiveView, and test/board_web/live/initiatives_live_test.exs.

## Tickets
bb-c2w.15. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `diagnosing-bugs`: reproduce first. Run the test file and the full suite in a loop with random seeds (`mix test --seed 0` style and `--repeat-until-failure`) until you catch it, and record the seed(s) that fail. State the cause with evidence before changing code.
- `tdd` at this seam: a test that fails deterministically for the identified cause (a fixed seed or a constructed state, not timing), then the fix.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against e0cf4c3 before printing the marker: Standards and Spec (bb-c2w.15 acceptance), plus Risk if the fix touches shared state, the session, or test isolation. Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Filters live in the URL with a localStorage restore on a bare route (existing behaviour); keep that contract.
- Stateful UI flows go through Board.Fsm machines (binding in review).

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. Spawn no subagents.
- A dev server runs on port 4747 from the main checkout; use another port if you need one. Use /usr/bin/rm, not rm.
- This checkout gets its own test database by directory name; do not touch other checkouts' databases.

## Done when
- The failure reproduced with a recorded seed (or the shared state that causes it shown), and the cause stated with evidence.
- A deterministic regression test for that cause, failing before the fix and passing after.
- The Initiatives test file passes 50 runs in a row and the full suite passes 10 runs in a row, each with random seeds (show the command and counts).
- mix precommit green; the bare-route restore still behaves in a browser (bare visit with a saved filter restores it; bare visit without one stays put), looked at.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/bb-flaky.md: the reproduction (seeds, counts), the cause with evidence, the fix, the loop results, review findings per axis with what you fixed and left open, final gate output. Then print BB-FLAKY DONE alone on the last line.
