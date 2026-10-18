You are a build session in beads-board (~/dev/utils/bb-merge, a git worktree on branch `bb-merge`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The one write the board makes: merging the bottom PR of a stack from the Pull requests page, safely and with confirmation, then retargeting its child onto the default branch, so a stacked series can be landed in order without leaving the board.

## Read first
- AGENTS.md (the app house rules at the top); docs/spec.md Decisions 9 and 10 and acceptance check 8; docs/design.md section 9; docs/mockup/PRs.dc.html (the merge flow and confirm dialog); bead bb-c2w.9.
- lib/board/forge*.ex and lib/board/forge/ (behaviour, GitHub adapter, fake, contract suite, read lifecycle), the Pull requests LiveView; docs/sessions/bb-forge.md.

## Tickets
bb-c2w.9. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: the merge-action machine (idle, confirming, merging, retargeting, merged, failed) on Board.Fsm, guards reading forge capabilities; MergeJob rules enforced in the job (bottom of stack only, not draft, checks passing or absent, mergeable, merge commit, expected head sha); retarget; the audit table; the contract suite extended to merge and retarget for both adapters.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against ebdba9b0af14079cff3256c32eae82e87fdfa919 before printing the marker: Standards, Spec (bb-c2w.9 acceptance), Risk (the only external write, idempotence, a head that moves between confirm and merge, partial failure between merge and retarget). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Writes go through Board.Forge only; capabilities gate them (no head guard: re-read the head immediately before merging and mark the guard as weaker; no retarget: stop after merge and show the manual step). write: true only for adapters that implement it.
- Confirm dialog names the PR, target, head sha, linked beads and the follow-up retarget; Fluxon modal; no explanatory prose beyond those facts.
- After merge, retarget the child onto the default branch; never delete branches; every merge recorded in an audit table.
- The linked ticket moves to merged through the observed cr_merged event on the next read (do not post it directly); the ticket sheet shows the bd close suggestion from the merged state's entry effect.

## Rules
- No commits, no pushes, no bd commands. Stay inside this worktree. **No GitHub writes of any kind until the coordinator says the scratch repo exists**: build and prove everything with the fake forge and recorded responses; when you reach the live-run acceptance item, stop, write the report with everything else done, list exactly what the live run will do, and print the marker. The coordinator will send you on once the user has approved the scratch repo.
- A dev server runs on port 4747 from the main checkout; use another port. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; machine, job, rules and contract tests; the merge flow driven in a browser against the fake forge (refused top-of-stack, confirm, merging, retargeting, merged; a moved head refused; a failure path), screenshots light and dark looked at.
- Live-run acceptance (check 8) waits for the coordinator as described in Rules.
- Work until every other item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-merge.md: what changed, the machine table, the job rules, screenshots, the planned live run, review findings per axis, final gate output. Then print BB-MERGE DONE alone on the last line.
