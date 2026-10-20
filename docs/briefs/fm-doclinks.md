You are a build session in foreman (~/dev/utils/fm-doclinks, a git worktree on branch `fm-doclinks`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Ticket fm-vtx.1: on the shared ticket sheet, existing .md paths in all session-written text (body, notes, every history payload value, session facts) become document links, and a new Documents section lists each distinct linked document from the ticket's history, its requests and its text, newest mention first, capped at 50. Links still go to the full viewer; the slide-out panel is the sibling ticket. Request cards must behave exactly as before.

## Read first
AGENTS.md; docs/specs/doc-links.md (approved spec; authoritative); `foreman show fm-vtx.1` and `foreman show fm-vtx`; lib/foreman/card_text.ex (today's path resolver for request cards) and lib/foreman/markdown.ex (path_candidates, link_paths, viewer_path); the ticket sheet component (ticket_detail.ex: body/notes via Markdown.render, history value_text and document_link); how requests are stored and keyed to a ticket.

## Tickets
fm-vtx.1 (ticket files). Start with `foreman update fm-vtx.1 --status in_progress`. The coordinator files new tickets and closes this one; report new work instead of filing it. A sibling build works on the other fm-vtx ticket in parallel from the same base; keep your changes to what this ticket needs so the merge stays small.

## Skills
- `tdd` at these seams: the document collector (dedupe, newest-first order, sources: history payloads, the ticket's requests, body, notes; cap 50); the resolver shared with request cards (rejects .., non-.md, missing, outside configured repos); the ticket sheet component (bare history path renders as a link; Documents section shown/hidden).
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against d9aa5f7 before printing the marker: Standards (house rule: nontrivial state sits on a declared Foreman.Fsm table), Spec (fm-vtx.1 and the spec decisions it names), Risk (path resolution must never open files outside the allowed roots). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding, then re-run the gate.

## Decisions already made
- Computed on render, nothing stored, no migration.
- Collector entries carry a source (`main` for now) so fm-vtx.3 can add worktree sources; name this in the report as the interface.
- Do not crawl document contents.

## Rules
No commits, pushes, deploys or release installs. Do not touch the live foreman on 4747, its database, the `-L foreman` tmux server, ~/.config/foreman or the skills repo. Use /usr/bin/rm, not rm.

## Browser checks
For a registered app, use the `devserve` skill. In this worktree run `FOREMAN_SESSION=fm-doclinks devserve up` and use the printed URL; seed a ticket whose history and notes mention real `.md` files. Confirm `devserve ls --json` shows this worktree with owner `fm-doclinks`. If startup or ownership verification fails, report the blocker rather than improvising a server. Leave preview cleanup to coordinator close-out. Screenshot light and dark; be picky about the UI.

## Build loop
Use the `foreman` skill's best-effort sender for `foreman progress fm-vtx.1 "<milestone; next step>"` at milestones; warnings never block work.
For a build-time question you cannot answer, run `foreman ask decision fm-vtx.1 --question "<question>" --option "<A>" --option "<B>" --recommendation "<A>"` directly, then `foreman wait <returned-request-id> --timeout 7200` in your shell, not through the sender and not as a question in this pane. Follow the `foreman` skill's approval outcomes: resume only with `state: answered`, using `outcome.answer` and `note`; exit 0 alone is not an answer. Keep the ID and re-wait after a timeout. Report an unavailable inbox as a blocker rather than guessing.

## Done when
Every fm-vtx.1 acceptance item holds with evidence (tests plus browser screenshots on the preview); `mix precommit` green with zero warnings.
Acceptance 1 is checked against a seeded copy of wa-x0z.5's history on the preview, not the live board.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains; a pure table without its executor is not a stopping point.

## Report back
Write docs/sessions/fm-doclinks.md: what changed, evidence, review findings per axis with what you fixed and what you left open, anything else open, final gate output. Use the `foreman` skill's best-effort sender for `foreman report fm-vtx.1 --path docs/sessions/fm-doclinks.md`; warnings never block the marker. Then print FM-DOCLINKS DONE alone on the last line.
