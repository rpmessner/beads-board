---
id: fm-c2w.4
title: "App shell, config and beads read model"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.1"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Merged 8239605 across 4a/4b-1/4b-2/4b-3: config, runtime, bd sync per the probe rule, roles, Fluxon, Settings; acceptance 855 writes zero failures, 0.74 s freshness, counts match; 124 tests"
---

## What to build
The app boots, knows which repos to read from its config, and keeps a live, droppable projection of every configured beads repo, without ever disturbing an agent's bd write (spec Decisions 1-5). Settings shows what it sees. Covers acceptance checks 1, 2, 2a, 10 and the precommit half of 11.

## Interfaces
Produces: the beads projection (repos, beads, edges, comments) and its change broadcasts; the config API (columns, repos, backfill defaults). Consumed by tickets 5-8.


## Acceptance
- [ ] Phoenix + LiveView + Oban + Postgres (versions as gw2), bound to 127.0.0.1; Fluxon wired from env vars; mix precommit includes a guard that fails on license material or local operator paths
- [ ] board.toml (global plus untracked local override, defaults shipped) loaded, validated (unknown stage names are errors), hot-reloaded; a bad edit keeps the last good config
- [ ] bd export sync per repo with polling, CLI-ping hook point, 5-minute sweep, hash skip, and the probe read rule; unreachable repos shown, never blocking others; unknown bd values never crash
- [ ] Every configured repo synced; counts equal bd list --all; a bd note shows in the projection within the target
- [ ] Probe write loop against the running sync: zero failed agent writes
- [ ] Settings view (repos, sync state, config source and validation, reload, unconfigured repos found on disk) built only after the revised mockup is approved
- [ ] The implementing agent may split this into 4a/4b across sessions; record the split in a bead note

## Notes
4a merged b594094: config layer, reload machine, hygiene guard, Board.Stage promoted. 4b remains: runtime (Oban, Postgres projection, Fluxon), bd reader per the probe rule, Settings view.
4b-1 merged b3845feedd834f4c5651ca6d22155638a47d06fa: runtime, export decoding, journal lock check, projection. Remaining (4b-2): reader and scheduler machines, config watcher through Oban, sync status and broadcasts, Fluxon, Settings view, real-repo acceptance.
4b-2 merged 3f0de68e528ba3ae23ec935d36ddb89ae83cc70f: read/schedule machines, roles, Postgres events. Remaining (4b-3): effect executors (bd subprocess, scheduler, path resolver, admission), config watcher wiring, sync status, Fluxon, Settings, real-repo acceptance.
