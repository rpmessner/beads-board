You are a build session in foreman (~/dev/utils/fm-preview, a git worktree on branch `fm-preview`). A coordinator session dispatched you and will read your output. Work autonomously; ask only when a decision is genuinely the user's.

## Goal
foreman becomes the first app devserve can preview, safely: its dev config honours PORT and DATABASE_URL, and with PREVIEW=1 it refuses every external write (forge writes, pushes, merges, tmux launches) while reads keep working, so a preview running on a copy of the user's real data can never act on approved requests.

## Read first
- AGENTS.md; skills ticket sk-9ro.2 (`cd ~/dev/utils/skills && bd show sk-9ro.2`) and the devserve spec ~/dev/utils/skills/docs/specs/devserve.md (Decisions 4, 6, 8a; acceptance checks 1 and 7); the devserve skill ~/dev/utils/skills/skills/devserve/ (SKILL.md, configuration.md).
- The external-write paths: push (docs/sessions/fm-push.md), merge (bb-merge.md), and any launch code (none yet; add the guard where a future launch would go only if there is a seam).

## Tickets
sk-9ro.2 (claimed by the coordinator in the skills repo). Do not run bd; do not edit tickets/.

## Skills
- `tdd` at these seams: config reads PORT and DATABASE_URL in dev; every external-write job refuses under PREVIEW=1 with a clear outcome (request failed as refused in preview, audit records it) and never calls the forge or git; reads unaffected.
- `verify-before-claiming` before writing the report.
- `code-review` on your own diff against f1b4f91fdae5b78c37ae88be5a5ce7678ea6265c before printing the marker: Standards, Spec (sk-9ro.2 acceptance items that are code), Risk (a write path that bypasses the guard). One axis after another; no subagents.

## Decisions already made
- The guard sits at the single place each external write executes (the jobs), not in the UI.
- The apps.toml entry for foreman (data = copy from the installed foreman database, migrate command, main_units foreman-web/foreman-worker) goes in the report as a proposal; the coordinator adds it to the user's dotfiles after approval.

## Rules
- No commits, no pushes, no ticket edits (tickets/ is the coordinator's), no bd. Stay inside this worktree. Spawn no subagents. Use /usr/bin/rm, not rm.
- The installed foreman runs on port 4747 as systemd services: do not stop or touch them, their config or their database. Use another port and this checkout's own databases.
- Do not create ~/.config/devserve or edit dotfiles. You may run devserve itself only against a scratch apps.toml (DEVSERVE_CONFIG_DIR) and a scratch copy database, never the installed foreman database.

## Done when
- Guard and config tests green; a live check with a scratch apps.toml: `devserve up` in this worktree serves foreman on a range port with a copied scratch database, a seeded approved push request fails as refused in preview and no git or GitHub call happens; `devserve down --drop-db` leaves nothing; mix precommit green.
Work until every item holds; hand off early only near your context limit (above about 85%).

## Report back
Write docs/sessions/fm-preview.md (changes, the guard points, the live check, the proposed apps.toml entry, review findings per axis, final gate). Then print FM-PREVIEW DONE alone on the last line.
