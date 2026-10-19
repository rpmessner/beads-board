---
id: fm-3c3.2
title: "Session waiting reaches the user (input, permission, usage limit)"
type: feature
status: in_progress
priority: 2
parent: fm-3c3
blocked_by: ["fm-3c3.1","fm-zgd.1"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
A launched session that needs the user tells the board, and the board tells the user through the inbox. Spec Decisions 6 and 9 (waiting rows).

## Interfaces
Consumes: the session record (ticket 1), the request backbone (bb-zgd.1). Produces: the session_waiting request kind and the activity signal ticket 4 reads.


## Acceptance
- [ ] Each launch passes per-launch settings (--settings) with hooks for permission/input needed and end of turn; global settings untouched
- [ ] foreman ask session_waiting <ticket> --session <id> --reason input|permission|usage_limit creates a no-action request linked to the attach command; it clears when the session works again
- [ ] Session machine rows waiting and resumed
- [ ] A launched session stopped at a permission prompt yields one session waiting request within 10 s; answering in tmux clears it; browser notification fires once bb-zgd.2 is in (check 4)
- [ ] Usage limit: a launched Claude session hitting a provider limit (API-error hook, or pane reading as fallback) and a pi window reported by the coordinator after pi-wait LIMITED both produce a usage_limit request showing provider and reset time when given
- [ ] Continue on a usage_limit request sends exactly continue + Enter to that window and nothing else, only on click; no other request kind has it
- [ ] Hook, CLI and tmux tests on a temporary socket; live run on a scratch ticket; mix precommit green

## Notes
2026-10-18 user: add usage-limit stoppages. (1) session_waiting gains a reason: input | permission | usage_limit; usage_limit shows provider and reset time when the message gives one, e.g. 'Usage limit · Codex · resets 14:00'; clears when the session produces output again. (2) Launched Claude sessions report limits through a per-launch hook for API errors if Claude Code has one, else the board reads the pane. (3) pi build sessions: when pi-wait exits LIMITED (skills ticket), the coordinator posts session_waiting --reason usage_limit with the window; dispatch skill documents it. (4) A Continue button on usage_limit requests only sends the single word 'continue' plus Enter to that window (the board's tmux server for launched sessions, the user's default tmux socket for pi windows), only on the user's click; the board never types anything else into a session.
