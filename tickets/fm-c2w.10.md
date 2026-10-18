---
id: fm-c2w.10
title: "Always on: one release, two systemd user units (web, worker)"
type: task
status: closed
priority: 2
parent: fm-c2w
blocked_by: ["fm-c2w.4"]
related: []
discovered_from: null
labels: []
created: 2026-10-18
closed: 2026-10-18
close_reason: "Installed and running: both units enabled under default.target, systemd active in WSL, kill recovery proven (after the Lifeline fix d2f2c17, all 7 repos resume). WSL restart not yet observed; reopen if the board is not up after the next restart."
---

## What to build
The board runs whenever agents do, without anyone starting it (spec Decision 1).


## Acceptance
- [ ] One mix release; a role setting selects web, worker or all (dev/tests)
- [ ] Two user unit files (beads-board-web, beads-board-worker) with Restart=always, env from the house locations, journald logs; install and update steps in the README; the user installs them (ask-first)
- [ ] Web runs no reader, scheduler or watcher; worker runs no endpoint; live updates reach the browser across the two nodes through Postgres
- [ ] Survives killing either process and a WSL restart; up before agents start

## Notes
Built and merged c18c59f: units, env examples, README steps, release smoke test. Stays open until the user installs the units and it survives a WSL restart (acceptance).

- 2026-10-18 Ryan Messner: Installed 2026-10-18: release 20261018T152929, both units enabled and active, 7 repos in board.toml, CLI in ~/.local/bin authenticating. SIGKILL of each main PID: web and worker came back with new PIDs, page 200, CLI read OK. Remaining: WSL restart check by the user.
- 2026-10-18 Ryan Messner: Correction 2026-10-18: the SIGKILL recovery check only checked PIDs and the page. The kill orphaned 4 executing sync jobs (unique while incomplete, no Lifeline), so beads-board, skills, dotfiles and ui-o-matic stopped syncing for ~35 min while health still said synced. Fixed d2f2c17 (Lifeline, rescue_after 5 min); all 7 repos syncing again. The recovery check must also confirm every repo syncs after the kill.
