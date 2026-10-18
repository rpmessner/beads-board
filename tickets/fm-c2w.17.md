---
id: fm-c2w.17
title: "Rename beads-board to foreman"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-axu.1","fm-zgd.1"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Code renamed (e973676, merged 511b90c); host cut over: DB/role foreman, ~/.config/foreman, foreman-web/-worker, ~/.local/lib/foreman, foreman CLI, skill foreman; counts equal before/after; 7 repos syncing."
---

## What to build
The user renamed the GitHub repo to rpmessner/foreman on 2026-10-18. Rename the app everywhere in one mechanical slice, after bb-axu.1 and bb-zgd.1 merge and before the ticket reader rewrite (bb-axu.2), and move the installed services over without losing board state.


## Acceptance
- [ ] One mechanical slice: OTP app :foreman, modules Foreman.* / ForemanWeb.*, release foreman; no behaviour change; mix precommit green with the same test count
- [ ] Checkout directory ~/dev/utils/foreman; worktree and doc paths updated
- [ ] Installed board moved over: services foreman-web / foreman-worker, release under ~/.local/lib/foreman, config ~/.config/foreman, database renamed in place (no data loss: stages, sessions, history counts equal before and after); old units removed
- [ ] CLI command and skill renamed per the user's choice; env vars renamed (FOREMAN_*) with the zshenv.local lines updated
- [ ] Ticket ids keep the bb- prefix
- [ ] Page title, header and favicon alt read foreman

## Notes
2026-10-18 user: CLI command foreman, skill renamed foreman, env vars FOREMAN_*.
