You are a build session in foreman (~/dev/utils/fm-docpanel, a git worktree on branch `fm-docpanel`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Ticket fm-vtx.2: make the Needs you document panel a shared slide-out on every page that shows the ticket sheet (Initiatives, epic page, Needs you) and for the epic page's spec link. Document links open the panel over the current page; opened from the ticket sheet, the sheet stays underneath and closing returns to it; the URL carries doc=repo:path so refresh and Back keep the place; the panel links to the full viewer.

## Read first
AGENTS.md; docs/specs/doc-links.md (approved spec; authoritative); `foreman show fm-vtx.2` and `foreman show fm-vtx`; docs/machines/card_panel.md and lib/foreman/card_panel.ex (today's panel machine); needs_you_live.ex panel/2, panel_document/1, refresh_panel/1 and the JS hook that routes card document links to the panel; how Initiatives and the epic page open the ticket sheet; lib/foreman/fsm.ex (the DSL) and mix foreman.fsm.docs.

## Tickets
fm-vtx.2 (ticket files). Start with `foreman update fm-vtx.2 --status in_progress`. The coordinator files new tickets and closes this one; report new work instead of filing it. A sibling build works on the other fm-vtx ticket in parallel from the same base; keep your changes to what this ticket needs so the merge stays small.

## Skills
- `tdd` at these seams: the document-layer step table (pure tests per transition); LiveView on Initiatives (open from the sheet, close with the sheet retained, refresh reopens, Back closes, missing doc shows unavailable); Needs you existing panel tests stay green.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against d9aa5f7 before printing the marker: Standards (house rule: nontrivial state sits on a declared Foreman.Fsm table), Spec (fm-vtx.2 and the spec decisions it names), Risk (path resolution must never open files outside the allowed roots). Run the axes one after another in this session; spawn no subagents. Fix every Critical and Important finding, then re-run the gate.

## Decisions already made
- The document panel is its own layer, independent of the ticket layer (spec decision 7 table); Needs you's ticket panel keeps its behaviour.
- Reuse the existing panel and hook; do not build a second panel.
- Keep the URL form extensible with a document source for fm-vtx.3 (worktree documents); name the form in the report as the interface.
- Regenerate the machine docs with mix foreman.fsm.docs.

## Rules
No commits, pushes, deploys or release installs. Do not touch the live foreman on 4747, its database, the `-L foreman` tmux server, ~/.config/foreman or the skills repo. Use /usr/bin/rm, not rm.

## Browser checks
For a registered app, use the `devserve` skill. In this worktree run `FOREMAN_SESSION=fm-docpanel devserve up` and use the printed URL; seed a ticket whose history and notes mention real `.md` files. Confirm `devserve ls --json` shows this worktree with owner `fm-docpanel`. If startup or ownership verification fails, report the blocker rather than improvising a server. Leave preview cleanup to coordinator close-out. Screenshot light and dark; be picky about the UI.

## Build loop
Use the `foreman` skill's best-effort sender for `foreman progress fm-vtx.2 "<milestone; next step>"` at milestones; warnings never block work.
For a build-time question you cannot answer, run `foreman ask decision fm-vtx.2 --question "<question>" --option "<A>" --option "<B>" --recommendation "<A>"` directly, then `foreman wait <returned-request-id> --timeout 7200` in your shell, not through the sender and not as a question in this pane. Follow the `foreman` skill's approval outcomes: resume only with `state: answered`, using `outcome.answer` and `note`; exit 0 alone is not an answer. Keep the ID and re-wait after a timeout. Report an unavailable inbox as a blocker rather than guessing.

## Done when
Every fm-vtx.2 acceptance item holds with evidence (tests plus browser screenshots on the preview); `mix precommit` green with zero warnings.
Motion: a short slide in/out consistent with the existing drawer; respect reduced motion.
Work until every item above holds. Hand off early only near your context limit (above about 85%), at a clean, green point, with a precise list of what remains; a pure table without its executor is not a stopping point.

## Report back
Write docs/sessions/fm-docpanel.md: what changed, evidence, review findings per axis with what you fixed and what you left open, anything else open, final gate output. Use the `foreman` skill's best-effort sender for `foreman report fm-vtx.2 --path docs/sessions/fm-docpanel.md`; warnings never block the marker. Then print FM-DOCPANEL DONE alone on the last line.
