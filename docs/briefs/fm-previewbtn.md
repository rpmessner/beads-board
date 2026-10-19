You are a build session in foreman (~/dev/utils/fm-previewbtn, a git worktree on branch `fm-previewbtn`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
Preview servers from the ticket sheet: for a ticket whose session has a worktree, the sheet offers Preview (start, open URL, follow logs, stop) through devserve, never started automatically, and the preview is stopped and its database dropped when the ticket moves past review (merged, done, abandoned). Orphan previews are listed and can be stopped.

## Read first
- AGENTS.md (house rules, clarified copy rule); tickets/fm-c2w.14.md; the devserve skill and its configuration (~/dev/utils/skills/skills/devserve/SKILL.md, configuration.md: CLI, `ls --json` shape, ownership rules); docs/sessions/fm-preview.md (foreman is preview-safe under PREVIEW=1); docs/sessions/bb-sheet.md, bb-tabs.md.

## Tickets
fm-c2w.14 (in progress, coordinator-owned; do not edit tickets/).

## Skills
- `tdd` at these seams: the preview lifecycle on Foreman.Fsm (none, starting, running, failed, stopping, stopped) driven by devserve's JSON; stage-tied cleanup (merged/done/abandoned stops and drops); orphan listing (preview with no ticket, or a vanished worktree); a devserve adapter boundary with a fake for tests.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against 2ffd2a03ea4d6c78b654bcc4e092a070d1c9dc1b before printing the marker: Standards, Spec (fm-c2w.14 acceptance), Risk (dropping a database devserve did not create; cleanup racing a user start; argv safety). One axis after another; no subagents.

## Decisions already made
- Previews go through the devserve CLI (`devserve up/ls --json/logs/down --drop-db`), never systemd or Postgres directly. The worker calls it; the web never does.
- Logs: a link or panel that tails `devserve logs <unit>` output, bounded.

## Rules
- No commits, no pushes, no ticket edits, no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman on 4747 and its database: do not touch. The user's ~/.config/devserve/apps.toml registers foreman; for tests use DEVSERVE_CONFIG_DIR with a scratch config. A live check may start one real preview of this worktree through the user's config (it copies the installed database into a preview database owned by devserve) and must stop it with --drop-db afterwards.

## Build loop
Use `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send progress fm-c2w.14 "<milestone; next step>"` at milestones.

## Done when
- Every fm-c2w.14 acceptance item holds with tests; the live check (start a preview from the sheet in a browser on your own port, open it, see logs, stop it; move a scratch ticket to done and see cleanup); screenshots light and dark at 390 and 1440 px looked at; afterwards `devserve ls --json` shows no preview of this worktree and no preview database remains; mix precommit green.
Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/fm-previewbtn.md (changes, machine, evidence, review, final gate). Run `bash ~/dev/utils/skills/skills/foreman/scripts/foreman-send report fm-c2w.14 --path docs/sessions/fm-previewbtn.md`. Then print FM-PREVIEWBTN DONE alone on the last line.
