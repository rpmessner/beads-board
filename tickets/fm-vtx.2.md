---
id: fm-vtx.2
title: "Shared document slide-out panel"
type: task
status: in_progress
priority: 2
parent: fm-vtx
blocked_by: []
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-20
closed: null
close_reason: null
---

## What to build

Make the Needs you document panel a shared slide-out used on every page that shows the ticket sheet (Initiatives, epic page, Needs you) and for the epic page's spec link. Any document link on those surfaces opens the panel over the current page instead of navigating. Opened from the ticket sheet, the sheet stays open underneath; closing the panel returns to it. The panel has an "Open in viewer" link to the full document page. The URL carries the open document (`doc=repo:path`), so refresh reopens it and Back closes it.

The document panel becomes its own layer, independent of the ticket layer, as a pure table + step per the house state-machine rule. Needs you's existing ticket panel keeps its behaviour.

Spec: docs/specs/doc-links.md, decisions 4, 5 and 7.

Prototype from the spec (document layer):

| state | event | result |
| --- | --- | --- |
| closed | open(doc) | open |
| open | open(doc) | open (new doc) |
| any | missing | unavailable |
| open / unavailable | close | closed |

Ticket layer is unchanged by document events.

## Interfaces

- Produces: the panel's URL form for a document (`doc=repo:path`), extensible with a source for worktree documents; a hook/attribute that marks a link as panel-opening.
- Consumes: existing Markdown viewer links; the sibling's Documents section links use the same mark.

## Acceptance

- [ ] In Initiatives, clicking a document link on the ticket sheet opens the panel; after closing, the sheet is still open; the page path never changed.
- [ ] Refresh with the panel open reopens the same document; Back closes it.
- [ ] Epic page spec link opens in the panel.
- [ ] A missing document shows the unavailable state, not an error page.
- [ ] Needs you ticket panel behaviour unchanged (existing tests green).
- [ ] Pure tests of the document-layer step table; LiveView test of open/close with the sheet retained and URL round-trip.
