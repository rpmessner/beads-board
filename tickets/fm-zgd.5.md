---
id: fm-zgd.5
title: "Merge requests through the existing confirm flow"
type: feature
status: open
priority: 2
parent: fm-zgd
blocked_by: ["fm-zgd.1"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
Merges become requests too, reusing the merge action as is: approving a merge request opens the existing confirmation, and its outcome resolves the request. Spec Decision 6 (merge row).

## Interfaces
Consumes: ticket 1's request backbone; the existing merge action and audit.


## Acceptance
- [ ] board ask merge names a PR and expected head; approving opens the existing merge confirm flow with every merge rule unchanged
- [ ] PR closed or head moved before approval supersedes the request
- [ ] The merge outcome resolves the request (done or failed) and reaches board wait
- [ ] MVP acceptance check 8 still passes (check 4); mix precommit green
