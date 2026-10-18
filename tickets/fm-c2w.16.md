---
id: fm-c2w.16
title: "Ticket sheet sections as tabs instead of jump links"
type: feature
status: closed
priority: 2
parent: fm-c2w
blocked_by: []
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Tabs on all three sheet callers, URL-driven, browser-checked both themes and widths; merged."
---

User feedback 2026-10-18: the sheet's jump links (Overview, Stage history, Sessions, Agent notes) will get long as sections grow (devserve preview is next). Replace them with tab headers and show one section at a time. Active tab lives in the URL (tab param beside the open ticket) so refresh, back and shared links keep it; default Overview. Tab headers may carry counts (status, not prose). Streams keep updating while a tab is hidden. Same component on Initiatives and Pull requests.

## Acceptance
- [ ] Tabs replace the jump-link nav on the ticket sheet on both pages
- [ ] Active tab in the URL; refresh and back restore it; unknown tab falls back to Overview
- [ ] Hidden tabs still receive live updates (switching shows current history/sessions/notes)
- [ ] Keyboard: arrow keys move between tabs, focus visible
- [ ] Browser-checked light and dark, narrow and wide; screenshots looked at
- [ ] mix precommit green
