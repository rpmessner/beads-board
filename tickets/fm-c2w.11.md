---
id: fm-c2w.11
title: "A day of real use through the board"
type: task
status: open
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.10","fm-c2w.6","fm-c2w.9"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: null
close_reason: null
---

## What to build
The proof the MVP does its job: a normal day of work keeps the board right without anyone updating it by hand (spec Why). Not a build ticket; a verification pass with fixes filed as fallout.


## Acceptance
- [ ] Also waits for sk-5o2 and sk-osj in the skills repo (closed) before starting
- [ ] One real day: a spec, its tickets, a dispatch, report, review, commit, PR and merge, all visible on the board with no manual board calls (checks 3, 6)
- [ ] git status before and after in every configured repo: nothing changed by the board (check 11)
- [ ] Nothing stored outside Postgres apart from the config file and the token
- [ ] Screenshots of every view, light and dark, match the approved mockup (check 12)
- [ ] Findings filed as fallout under bb-c2w
