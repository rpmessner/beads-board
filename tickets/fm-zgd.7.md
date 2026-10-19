---
id: fm-zgd.7
title: "foreman requests: list pending approval requests from the CLI"
type: feature
status: open
priority: 2
parent: fm-zgd
blocked_by: []
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-19
closed: null
close_reason: null
---

The `orient` skill reads Needs you by fetching the rendered /needs-you page, because neither the API nor the CLI lists requests. Add a read:

- `GET /api/requests?state=pending` (bearer token, like the other API routes) and `foreman requests [--state <s>] [--json]`, oldest first: id, kind, ticket/repo, session, question or action, age.
- Then switch the `orient` skill (skills repo) from the HTML read to `foreman requests --json`.

Acceptance: with two pending requests on a scratch board, `foreman requests --json` lists both oldest first and matches /needs-you; with the app down it exits non-zero with a clear message (a read, not spooled); `mix precommit` green.
