---
id: fm-zgd.3
title: "Push requests executed by the worker"
type: feature
status: closed
priority: 2
parent: fm-zgd
blocked_by: ["fm-zgd.1"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged: push requests with live scratch evidence; 379 tests."
---

## What to build
The first external write from a request: the user approves a push and the board's worker pushes the named branch at the named sha to the repo's GitHub remote, fast-forward only. Spec Decisions 2, 3, 4, 5, 6 (push row and default-branch rule).

## Interfaces
Consumes: request record, machine and per-kind extension point (ticket 1). Produces: the push kind and its CLI form, used by the dispatch close-out (ticket 6).


## Acceptance
- [ ] board ask push names repo, worktree, local branch, expected sha, remote branch; refused at creation when ticket not committed, forge none, worktree not in the repo, or a default-branch push for a ticket inside an epic
- [ ] Job pushes over HTTPS with gh as the credential helper for that one command; no credential on disk or argv; never forced; pushing is the only local git command the board runs
- [ ] Guards re-checked in the job: local sha unchanged, fast-forward only, default-branch rule (a job forced past creation still refuses)
- [ ] Local branch moving before approval supersedes the request
- [ ] Killing the worker mid-push ends the request failed with outcome unknown after rescue; no second push (check 7)
- [ ] Temp-repo tests with a bare remote: fast-forward, diverged, moved sha, foreign worktree
- [ ] Live on rpmessner/beads-board-scratch: branch appears at exactly the named sha; one-off default-branch push succeeds; epic ticket default-branch push refused (checks 1, 2, 11); responses recorded, tokens scrubbed
- [ ] mix precommit green
