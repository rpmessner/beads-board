---
id: fm-zgd.4
title: "Open-PR requests"
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
close_reason: "Merged b8b91ee: open-PR requests, live scratch PR #4."
---

## What to build
The user approves a PR and the worker opens it on GitHub with exactly the named base, title and body. Spec Decisions 2, 3, 6 (open_pr row).

## Interfaces
Consumes: ticket 1's request backbone; the existing forge boundary. Produces: the open_pr kind and its CLI form (ticket 6), and create-change-request on the forge behaviour.


## Acceptance
- [ ] Forge behaviour gains create change request with a capability flag; GitHub adapter and fake implement it; the forge contract suite covers it for both
- [ ] board ask open_pr names repo, head branch, expected head sha, base, title, body; refused at creation when ticket not committed or forge none
- [ ] Job guards: head on the remote at the expected sha, base exists, no open PR for that head; head moving before approval supersedes
- [ ] The ticket reaches pr_open through the observed forge read, never from the request (check 3)
- [ ] Live on the scratch repo: PR created with the named base, title and body; responses recorded
- [ ] mix precommit green
