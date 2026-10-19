You are a build session in foreman (~/dev/utils/fm-format, a git worktree on branch `fm-format`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
The ticket format and foreman adopt handle the beads data still blocking three repos: a chore ticket type, a supersedes list in the frontmatter, and adopt mapping beads convoy to epic and tracks dependencies to related.

## Read first
- AGENTS.md; tickets/fm-axu.8.md; docs/specs/ticket-files.md (Decisions 3, 6, 10); docs/sessions/bb-files.md and fm-adopt.md (format, store, check, converter, comparison).
- Real exports that must convert: /tmp/claude-1000/-home-rpmessner-dev-music/b034bdad-1084-4b73-8da7-bdfb1f4e577b/scratchpad/adopt/{dotfiles,ui-o-matic,cooldown-o-matic}-export.jsonl (read-only), and the dry-run script beside them (dry.py) to re-run.

## Tickets
fm-axu.8 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd`: format parse/print round trip with chore and supersedes; check rules for supersedes (id syntax; may refer to absent tickets, like related); converter mapping convoy->epic, tracks->related, supersedes->supersedes, chore->chore; the comparison counts each mapped relation correctly; the ticket sheet shows supersedes.
- `verify-before-claiming`; `code-review` against 5e35ddf60f2700c43697609394566dd5e36c56ab (Standards, Spec, Risk: no silent loss in conversion). No subagents.

## Rules
- No commits, no pushes, no ticket edits, no bd writes. Stay inside this worktree. Do not touch the real repos, ~/.config/foreman or the installed board. Use /usr/bin/rm, not rm.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-axu.8 "<milestone; next step>"` at milestones.

## Done when
- Tests green; dry runs (scratch clones, scratch config) for dotfiles, ui-o-matic and cooldown-o-matic pass with comparison equal, check valid and a no-op rerun, using this worktree's built escript; mix precommit green.

## Report back
Write docs/sessions/fm-format.md. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-axu.8 --path docs/sessions/fm-format.md`. Then print FM-FORMAT DONE alone on the last line.
