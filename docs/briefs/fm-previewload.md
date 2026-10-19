You are a build session in foreman (~/dev/utils/fm-previewload, a git worktree on branch `fm-previewload`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
A foreman preview (PREVIEW=1) must not re-sync every configured repo beside the real board: by default a preview serves its copied cache only (no beads/files readers, no forge sync, no session monitor), with an explicit opt-in to run readers when the change under preview is in the reader itself.

## Read first
- AGENTS.md; tickets/fm-c2w.20.md; docs/sessions/fm-preview.md (Foreman.Preview, PREVIEW=1 guard) and fm-previewbtn.md (the live log showing a preview syncing every repo and failing on bd); lib/foreman/role.ex and runtime (what the worker starts).

## Tickets
fm-c2w.20 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd`: under PREVIEW=1 the runtime starts no readers, forge sync or session monitor unless FOREMAN_PREVIEW_READERS=1 (or a better-named opt-in you justify); the app still serves the copied data; the PREVIEW write guard is unchanged.
- `verify-before-claiming`; `code-review` against cd4f443c0c294dc41c9ed39f03f1cff36d3adb10 (Standards, Spec, Risk). No subagents.

## Rules
- No commits, no pushes, no ticket edits, no bd. Stay inside this worktree. Use /usr/bin/rm, not rm. Do not touch the installed foreman, its config or database; a live check may start one preview of this worktree through the user's devserve config and must stop it with --drop-db afterwards.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-c2w.20 "<milestone; next step>"` at milestones.

## Done when
- Tests green; live: a preview of this worktree serves the copied tickets with no sync lines in its log (devserve logs), then stopped with --drop-db; mix precommit green.

## Report back
Write docs/sessions/fm-previewload.md. Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-c2w.20 --path docs/sessions/fm-previewload.md`. Then print FM-PREVIEWLOAD DONE alone on the last line.
