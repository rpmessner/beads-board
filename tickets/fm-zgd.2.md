---
id: fm-zgd.2
title: "Browser notifications for new requests"
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
close_reason: "Merged: browser notifications, exactly once across tabs, opt-in."
---

## What to build
OS notifications for new requests through the browser Notification API (native toast on Windows, Notification Center on macOS), opt-in from an explicit control, deduplicated across tabs. Spec Decision 10.

## Interfaces
Consumes: the request record and its live broadcasts (ticket 1).


## Acceptance
- [ ] A Turn on notifications control appears only while permission is default; no prompt without a click
- [ ] With permission, exactly one native notification per new pending request across any number of open tabs
- [ ] Denied permission: control hidden or shown as off, badge still works
- [ ] Pending count consistent across two open tabs (check 8)
- [ ] Browser tests with permission granted and denied; mix precommit green
