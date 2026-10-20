---
id: fm-vtx
title: "Tickets link the documents their sessions create or reference"
type: epic
status: open
priority: 2
parent: null
blocked_by: []
related: []
supersedes: []
discovered_from: null
labels: []
created: 2026-10-20
closed: null
close_reason: null
---

# Tickets link the documents their sessions create or reference

## Goal

Every `.md` document a ticket's sessions mention shows up as a link on that ticket, and opening any document link on the board slides a panel over the current page instead of navigating away.

## Why

Research and build sessions write reports, briefs and specs, but the ticket only says so in plain text (or not at all). Today the coordinator adds a `Documents:` note by hand. The user wants to open a ticket and see its documents, and read one without losing the place they were in (the ticket sheet, the Needs you list, an epic). Documents still in an unmerged worktree matter most during review, which is exactly when the viewer can't open them today.

## Non-goals

- No crawling: the board does not read documents to find further links.
- No stored document list: nothing is written into ticket files or new tables for this; the list is computed.
- Non-Markdown files (logs, screenshots, source) stay plain text.
- The Pull requests and Previews pages, and links inside the document viewer itself, keep their current behaviour.
- No editing of documents from the panel.
- Anti-goal: a path that resolves outside a configured repo or a board-recorded worktree must never open, whatever the text says.

## Decisions

1. **Auto-linking (user).** In every text field of the ticket sheet (body, notes, history values, session facts) a bare or Markdown-linked path to an existing `.md` file becomes a document link. Same rules as today's request cards: relative paths resolve against the ticket's repo first, then other configured repos; absolute and `~/` paths link only beneath an allowed root; `..` never links. Request cards keep working as they do.
2. **Documents section (user).** The ticket sheet gets a Documents section listing each distinct linked document found in that ticket's text: board history (brief, report, spec, progress and other payload values), request questions and answers for that ticket, the ticket body and notes. One entry per document, most recent mention first, each showing where it lives (main checkout, or the worktree label). Empty section is hidden.
3. **"Linked" means mentioned (user).** Created vs. referenced is not distinguished; any existing `.md` path in the ticket's text counts.
4. **Surfaces (user).** The ticket sheet is the one shared component used by Initiatives, the epic page and Needs you, so changing it covers all three. The epic page's spec link also opens in the panel.
5. **Slide-out panel (user).** Every document link on those surfaces opens a panel over the current page. Opened from the ticket sheet, the sheet stays underneath and closing the panel returns to it. The panel has an "Open in viewer" link to the full document page. The URL carries the open document (today's `doc=repo:path` form, plus the worktree source when there is one), so refresh and Back keep the user in place. It is the existing Needs you document panel made shared, not a second panel.
6. **Worktree documents (user).** Resolution tries the main checkout first, then the worktrees the board recorded for that ticket's sessions (their workdir). A document found only in a worktree is labelled with that worktree's name (e.g. "in worktree fm-epic-coord"). Read only. Allowed roots are configured repo roots and board-recorded session workdirs that are git worktrees of a configured repo; nothing else.
7. **Panel state (agent call).** The document panel becomes its own layer, independent of the ticket layer, so a document can sit over an open ticket:

   | layer | state | event | result |
   | --- | --- | --- | --- |
   | document | closed | open(doc) | open |
   | document | open | open(doc) | open (new doc) |
   | document | any | missing | unavailable |
   | document | open / unavailable | close | closed |
   | ticket | (unchanged by document events) | | |

   Needs you's existing ticket panel keeps its behaviour; only document opening moves to the new layer. Pure table + step, per the house state-machine rule.
8. **Where worktrees come from (agent call).** "Board-recorded" means the workdir on the ticket's session records and the `workdir`/`worktree` values in its history payloads, the same sources Previews uses. If a recorded worktree has since been removed, resolution falls back to the main checkout; found in neither, the panel shows unavailable.
9. **Limits (agent call).** Keep the existing per-text caps on paths checked; the Documents section shows at most the first 50 distinct documents.

## Acceptance checks

1. Open wa-x0z.5 on the board: its Documents section lists `docs/research/addon-ideas.md` and its brief, without the hand-written `Documents:` note being needed (baseline: today only the note's Markdown links work; bare paths in history do not link).
2. A history entry whose value contains a bare `docs/…md` path renders as a link (baseline: plain text today).
3. Clicking a document link on the ticket sheet in Initiatives opens the panel; the ticket sheet is still there after closing the panel; the page URL never changed path.
4. Refreshing with the panel open reopens the same document; Back closes it.
5. A report that exists only in a build's worktree (unmerged) opens in the panel, labelled with the worktree; after merge it opens from the main checkout without the label.
6. A path like `/etc/passwd.md`, `../x.md`, or an absolute path in an unrecorded directory does not link and cannot be opened by crafting the URL.
7. Request cards on Needs you link paths exactly as before (regression).
8. From outside the code: a real dispatched session's report link opens on the live board after deploy.

## Verification plan

- Unit tests on the resolver (allowed roots incl. recorded worktrees, rejection cases) and on the document collector (dedupe, order, sources).
- Pure tests of the panel step table.
- LiveView tests at the ticket sheet component and one page (Initiatives): link render, panel open/close with sheet retained, URL param round-trip, worktree label.
- Existing request card and document viewer tests stay green.
- After deploy: screenshot of wa-x0z.5 with Documents section and panel open over the sheet.

## Ask-first boundaries

- Any schema migration or new stored field.
- Widening allowed roots beyond configured repos and board-recorded worktrees.
- Changing Pull requests, Previews or viewer-internal link behaviour.
- Removing the hand-written `Documents:` step from the dispatch close-out (do that as a follow-up once this ships).

## Left to the builder

- Exact URL encoding of the worktree source.
- Panel width, animation and where the Documents section sits on the sheet.
- How the collector is shared between the sheet and request cards.
