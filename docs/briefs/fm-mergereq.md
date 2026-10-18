You are a build session in foreman (~/dev/utils/fm-mergereq, a git worktree on branch `fm-mergereq`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Merge requests: a session or the coordinator asks `foreman ask merge` for a PR at an expected head; approving it on Needs you opens the existing merge confirm flow with every merge rule unchanged, and the merge outcome resolves the request.

## Read first
- AGENTS.md (house rules, clarified copy rule); docs/specs/approvals-inbox.md (Decision 6 merge row); tickets/fm-zgd.5.md; docs/sessions/bb-merge.md (merge action, rules, audit, live fixtures), fm-push.md (request kind pattern), bb-inbox.md, fm-preview.md (Foreman.Preview guard: the merge job already calls it).

## Tickets
fm-zgd.5 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd` at these seams: creation (PR exists, expected head, forge capability); approve opens the confirm flow (not a direct merge); PR closed or head moved before approval supersedes; merge outcome (merged, refused, failed, partial) resolves the request and reaches `foreman wait`.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against ca7854ca178464e05702c442011250376126cc16 before printing the marker: Standards, Spec (fm-zgd.5 acceptance), Risk (two paths to merge must not bypass any merge rule; double approval; a request resolved twice). One axis after another; no subagents.

## Decisions already made
- Reuse the merge action as is; the request only routes into it. Every merge rule (bottom of stack, not draft, checks, mergeable, merge commit, expected head) stays enforced in the job.
- Live GitHub writes only to rpmessner/beads-board-scratch through foreman's own worker, if a live run is needed (the merge flow already has live fixtures; prefer recorded responses).

## Rules
- No commits, no pushes, no ticket edits, no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman on port 4747: do not touch it, its config or database. Use another port and this checkout's own databases.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-zgd.5 "<milestone; next step>"` at milestones.

## Done when
- Every fm-zgd.5 acceptance item holds with tests; MVP merge acceptance (check 8 of docs/spec.md) still passes against the fake forge; the merge request card and the confirm flow from it browser-checked light and dark at 390 and 1440 px, screenshots looked at; mix precommit green.
Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/fm-mergereq.md (changes, flow, evidence, review findings per axis, final gate). Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-zgd.5 --path docs/sessions/fm-mergereq.md`. Then print FM-MERGEREQ DONE alone on the last line.
