---
id: fm-axu.8
title: "Ticket format: chore type, supersedes links; adopt maps convoy and tracks"
type: feature
status: closed
priority: 2
parent: fm-axu
blocked_by: ["fm-axu.1"]
related: []
discovered_from: null
labels: []
created: 2026-10-19
closed: 2026-10-19
close_reason: "Merged: chore, supersedes, convoy/tracks mapping; three dry runs pass."
---

User decision 2026-10-18 after dry runs refused dotfiles (1 chore), cooldown-o-matic (1 chore, 2 supersedes) and ui-o-matic (2 chore, 2 convoy, 12 tracks, 1 supersedes): add chore as a ticket type; add a supersedes list to the frontmatter (validated like related: ids, may refer to absent tickets); adopt converts beads convoy to epic and tracks dependencies to related, recording nothing lossy beyond that. The board shows supersedes on the ticket sheet. Then the dry runs for those three repos must pass.
