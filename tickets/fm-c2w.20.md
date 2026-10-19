---
id: fm-c2w.20
title: "Previews run a full worker that re-syncs every repo beside the real board"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-19
closed: 2026-10-19
close_reason: "Merged: previews serve copied cache only; opt-in readers."
---

Seen 2026-10-18 in the fm-c2w.14 live check: a foreman preview runs FOREMAN_ROLE=all with the user's foreman.toml, so it syncs every configured repo every 3 s (doubling load) and fails on beads repos because bd is not on the preview PATH. Decide what a preview should read: e.g. its own copied cache only (no readers, no forge sync) unless the change under preview is in the reader; set it through the devserve apps.toml env or a PREVIEW-aware runtime default.
