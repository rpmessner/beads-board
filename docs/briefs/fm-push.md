You are a build session in foreman (~/dev/utils/fm-push, a git worktree on branch `fm-push`). foreman was called beads-board until today. A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The first external write from an inbox request: the user approves a push on the Needs you page and foreman's worker pushes the named branch at the named sha to the repo's GitHub remote, fast-forward only, with every guard re-checked in the job and the attempt audited.

## Read first
- AGENTS.md; docs/specs/approvals-inbox.md (approved; this ticket is Decisions 2-6, push row and default-branch rule); ticket bb-zgd.3 (`git show main:.beads/issues.jsonl` if needed).
- docs/sessions/bb-inbox.md (request backbone and the per-kind validate/enqueue extension point you plug into), docs/sessions/bb-merge.md (one-shot claim, audit, recorded live fixtures), docs/sessions/bb-forge.md.

## Tickets
bb-zgd.3. The coordinator has already claimed it; do not run bd in this worktree.

## Skills
- `tdd` at these seams: creation-time refusals (ticket not committed, forge none, worktree not in the repo, default-branch push for a ticket inside an epic); the job's re-checks (local sha unchanged, fast-forward only, default-branch rule); supersede when the local branch moves; rescue of an interrupted job ends failed with outcome unknown and never pushes twice. Use temp git repos with a bare remote.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against cfe3d15e54a1042b5e58e81ef9961877b2f7f97d before printing the marker: Standards, Spec (bb-zgd.3 acceptance), Risk (the only local git write; credentials never on disk or in argv; never forced; idempotence under rescue). Run the axes one after another; spawn no subagents. Fix every Critical and Important finding.

## Decisions already made
- Push over HTTPS with gh as git's credential helper for that one command (e.g. `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push https://github.com/<owner>/<repo>.git <sha>:refs/heads/<branch>`); never --force; pushing is the only local git command foreman runs.
- Default branch: allowed only for a one-off ticket (no parent epic), fast-forward only; refused at creation and in the job for tickets inside an epic.
- The CLI form is `foreman ask push <ticket> ...`; it keeps the CLI's never-fail rule.

## Rules
- No commits, no pushes from your shell (the agent hook blocks them; that is intended), no bd commands. Stay inside this worktree. Spawn no subagents.
- **Live GitHub writes only to rpmessner/beads-board-scratch**, and only through foreman's own worker during the live acceptance run; clone it under /tmp/fm-push-scratch. Nothing else on GitHub.
- The installed foreman runs on port 4747 as systemd services: do not stop or touch them, their config or their database. Use another port and this checkout's own databases. Use /usr/bin/rm, not rm.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress bb-zgd.3 "<milestone; next step>"` at milestones; warnings never block work.

## Done when
- Every bb-zgd.3 acceptance item holds: temp-repo tests, the live scratch run (branch appears at exactly the named sha; one-off default-branch push succeeds; epic-ticket default-branch push refused), responses recorded with tokens scrubbed; the Needs you push card browser-checked light and dark at 390 and 1440 px with screenshots looked at; mix precommit green.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains.

## Report back
Write docs/sessions/fm-push.md: what changed, guards, the live run, evidence, review findings per axis, final gate output. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report bb-zgd.3 --path docs/sessions/fm-push.md`. Then print FM-PUSH DONE alone on the last line.
