You are a build session in foreman (~/dev/utils/fm-openpr, a git worktree on branch `fm-openpr`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Open-PR requests: the user approves on Needs you and foreman's worker opens the PR on GitHub with exactly the named base, title and body; the ticket reaches pr_open through the normal forge read, never from the request.

## Read first
- AGENTS.md (house rules, incl. the copy rule clarified today); docs/specs/approvals-inbox.md (Decisions 2, 3, 6 open_pr row); tickets/fm-zgd.4.md.
- docs/sessions/fm-push.md (the push kind: plug-in point, job, guards, live scratch run, fixtures), bb-inbox.md, bb-forge.md, bb-merge.md.

## Tickets
fm-zgd.4 (in progress, owned by the coordinator; do not edit tickets/).

## Skills
- `tdd` at these seams: forge create-change-request with a capability flag in the behaviour, GitHub adapter and fake, contract suite for both; creation refusals (ticket not committed, forge none); job guards (head on the remote at the expected sha, base exists, no open PR for that head); head moving before approval supersedes; rescue never opens twice.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against f1b4f91fdae5b78c37ae88be5a5ce7678ea6265c before printing the marker: Standards, Spec (fm-zgd.4 acceptance), Risk (an external write; idempotence; partial failure). One axis after another; no subagents. Fix every Critical and Important finding.

## Decisions already made
- Same patterns as push: ID-only job on external_writes, one attempt, audit, one-shot claim; CLI `foreman ask open_pr <ticket> --project <key> --head <branch> --sha <sha> --base <branch> --title ... --body-file <path>` (adjust flag names if the push kind's conventions differ; keep never-fail).
- Live writes only to rpmessner/beads-board-scratch, through foreman's own worker; clone under /tmp/fm-openpr-scratch; you may push a scratch branch there through foreman's push request flow only.

## Rules
- No commits, no pushes, no ticket edits (tickets/ is the coordinator's), no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman runs on port 4747 as systemd services: do not stop or touch them, their config or their database. Use another port and this checkout's own databases.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-zgd.4 "<milestone; next step>"` at milestones.

## Done when
- Every fm-zgd.4 acceptance item holds: unit and contract tests, the live scratch run (PR created with the named base, title and body; ticket reaches pr_open through the observed read), recorded responses with tokens scrubbed; the Needs you open-PR card browser-checked light and dark at 390 and 1440 px, screenshots looked at; mix precommit green.
Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/fm-openpr.md (changes, guards, live run, evidence, review findings per axis, final gate). Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-zgd.4 --path docs/sessions/fm-openpr.md`. Then print FM-OPENPR DONE alone on the last line.
