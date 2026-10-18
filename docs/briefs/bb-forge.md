You are a build session in beads-board (~/dev/utils/bb-forge, a git worktree on branch `bb-forge`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Each project's open change requests in stack order, linked to their beads, behind a forge boundary, so the Pull requests page and the CRs column on Initiatives show real PRs (form-engine's stack today) and opening, closing and merging a PR moves linked tickets. Read-only: the merge action is ticket .9.

## Read first
- AGENTS.md; docs/spec.md Decisions 9 and 10 and acceptance check 9; docs/design.md section 9; docs/mockup/PRs.dc.html (layout; merge controls are .9's); bead bb-c2w.8.
- lib/board/overlay*.ex (cr_* events, overlay_cr_links), lib/board/stage.ex, lib/board/config/schema.ex (forge and github fields), lib/board/runtime.ex and sync jobs (how scheduled reads are wired), docs/sessions/bb-exec.md.

## Tickets
bb-c2w.8. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: the Board.Forge behaviour and its contract suite run against the fake forge and the GitHub adapter (recorded responses); stack ordering and detached bases; linking by bead id in title, then branch, then body; observed cr_opened / cr_closed / cr_merged moving linked tickets per the stage machine; the PR page LiveView.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against c41cd42b25dd7e193b4366eef7bcb4216f235acc before printing the marker: Standards (house baseline: the sync job and per-repo forge read lifecycle on Board.Fsm), Spec (bb-c2w.8 acceptance), Risk (an external API, tokens, rate limits). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Board.Forge behaviour: list change requests (number, title, source and target branch, head sha, draft, checks, mergeable, url), merge with expected head and retarget (declared but used by .9), capabilities. MVP adapters: GitHub and an in-memory fake; config names the forge per repo (forge = "github", github = "owner/name"); repos without a remote show no panel.
- GitHub via Req; token from the logged-in gh (`gh auth token`) at boot, held in memory only, never logged or stored. One GraphQL query per repo per sync for PRs with head/base, draft, mergeable state and check rollup; reads run in the worker role through Oban with a 2-minute cadence plus a manual refresh.
- Stack: a PR whose base is another open PR's head is its child; chains ordered from the default branch up; a PR whose base is neither is "detached base".
- Pull requests page per the mockup (read-only: no merge buttons yet); the CRs column on Initiatives counts open CRs linked to each epic's tickets; the ticket sheet's linked CRs fill in.
- Recorded GitHub fixtures come from read-only calls against rpmessner/form-engine (its open PRs) and must contain no token.

## Rules
- No commits, no pushes, no bd commands. Read-only against GitHub: no merges, comments or edits. Stay inside this worktree. A dev server runs on port 4747 from the main checkout; use another port. Use /usr/bin/rm, not rm. Spawn no subagents.

## Done when
- mix precommit green; contract suite green for both adapters; acceptance 9: form-engine's real open PRs in stack order with bead links, read-only, nothing mergeable whose base is not the default branch; screenshots light and dark of the Pull requests page and an Initiatives row with CRs, looked at.
- Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/bb-forge.md: what changed, the forge behaviour and capabilities, linking rules, screenshots, review findings per axis, final gate output. Then print BB-FORGE DONE alone on the last line.
