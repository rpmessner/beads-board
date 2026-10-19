---
id: fm-3c3.5
title: "pi extension: tell foreman when a pi session waits on input"
type: feature
status: in_progress
priority: 2
parent: fm-3c3
blocked_by: ["fm-3c3.2"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

User request 2026-10-18: ease the friction between sessions. A pi extension (like house-guard) that posts session_waiting to foreman (reason input or permission or usage_limit) when a pi session stops for a question, a prompt or a provider limit, and clears it when the session works again; the coordinator-side pi-wait BLOCKED/IDLE/LIMITED exits are the fallback. Uses the session_waiting kind from fm-3c3.2.
