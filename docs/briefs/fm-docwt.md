You are a build session in foreman (~/dev/utils/fm-docwt, a git worktree on branch `fm-docwt`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Ticket fm-vtx.3: documents that exist only in a build's worktree open on the board. Resolution tries the main checkout first, then the worktrees the board recorded for that ticket's sessions; a worktree-only document is labelled with the worktree name in the Documents section and the panel; a removed worktree falls back to main; found nowhere shows unavailable. Read only, and nothing outside configured repos or board-recorded worktrees may ever open, including through a hand-crafted URL.

## Read first
AGENTS.md; docs/specs/doc-links.md (approved spec; decisions 6 and 8 here); `foreman show fm-vtx.3`; the two merged sibling reports docs/sessions/fm-doclinks.md and docs/sessions/fm-docpanel.md, each with an "Interface" section you extend: `Foreman.TicketDocuments.collect/3` entries `{repo, path, source}` (source is `:main` today) and the panel URL `doc=<repo>:<path>&doc_source=<opaque>` / viewer `/documents/<repo>?path=..&source=..` (a nonempty source currently shows unavailable). Also Foreman.CardText.resolve/3, Foreman.Documents (document?/read, including its existing git-worktree fallback for --doc), and how Previews reads session workdir/worktree values.

## Tickets
fm-vtx.3 (ticket files). Start with `foreman update fm-vtx.3 --status in_progress`. The coordinator files new tickets and closes this one; report new work instead of filing it.

## Skills
- `tdd` at these seams: the resolver's allowed roots (configured repo roots; recorded session workdirs that are git worktrees of a configured repo) and rejections (outside paths, `..`, symlinks, unrecorded directories, a recorded directory that is not a worktree of a configured repo); the collector adding worktree sources and the fallback order; the panel and viewer refusing a source that is not recorded for any ticket of that repo; LiveView for the label in the Documents section and panel.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 157f441 before printing the marker: Standards (house rule: nontrivial state sits on a declared Foreman.Fsm table), Spec (fm-vtx.3), Risk (this is the one place the board reads paths outside the main checkout: authorization must be re-checked server-side on every read). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding, then re-run the gate.

## Decisions already made
- "Board-recorded" = the workdir on the ticket's session records and `workdir`/`worktree` values in its history payloads (spec decision 8).
- The worktree label is the worktree directory's name, e.g. "in worktree fm-epic-coord".
- No schema migration, no stored document list.
- Reuse the existing source parameter shapes from the sibling interfaces; choose the opaque source encoding yourself and document it.

## Rules
No commits, pushes, deploys or release installs. Do not touch the live foreman on 4747, its database, the `-L foreman` tmux server, ~/.config/foreman or the skills repo. Do not create or remove git worktrees of real repos except scratch repos under /tmp for tests. Use /usr/bin/rm, not rm.

## Browser checks
For a registered app, use the `devserve` skill. In this worktree run `FOREMAN_SESSION=fm-docwt devserve up` and use the printed URL; seed a ticket whose session workdir is a scratch git worktree of a configured repo holding a report that is not in the main checkout. Confirm `devserve ls --json` shows this worktree with owner `fm-docwt`. If startup or ownership verification fails, report the blocker rather than improvising a server. Leave preview cleanup to coordinator close-out. Screenshot light and dark; be picky about the UI.

## Build loop
Use the `foreman` skill's best-effort sender for `foreman progress fm-vtx.3 "<milestone; next step>"` at milestones; warnings never block work.
For a build-time question you cannot answer, run `foreman ask decision fm-vtx.3 --question "<question>" --option "<A>" --option "<B>" --recommendation "<A>"` directly, then `foreman wait <returned-request-id> --timeout 7200` in your shell, not through the sender and not as a question in this pane. Follow the `foreman` skill's approval outcomes: resume only with `state: answered`, using `outcome.answer` and `note`; exit 0 alone is not an answer. Keep the ID and re-wait after a timeout. Report an unavailable inbox as a blocker rather than guessing.

## Done when
Every fm-vtx.3 acceptance item holds with evidence except the post-deploy live check (the coordinator does that after merge); `mix precommit` green with zero warnings.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains; a pure table without its executor is not a stopping point.

## Report back
Write docs/sessions/fm-docwt.md: what changed, the source encoding, evidence, review findings per axis with what you fixed and what you left open, anything else open, final gate output. Use the `foreman` skill's best-effort sender for `foreman report fm-vtx.3 --path docs/sessions/fm-docwt.md`; warnings never block the marker. Then print FM-DOCWT DONE alone on the last line.
