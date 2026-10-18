# Session launcher

Status: idea, not yet specced (2026-10-18). Board draft epic `draft:session-launcher`. Spec after the approvals inbox and devserve.

## Idea

From an unplanned bead in any project, launch a Claude session in tmux to work it, creating the tmux session or window when missing; attach to it from a terminal at any time.

## Settled so far (user, 2026-10-18)

- One tmux server owned by the board (`tmux -L beads-board`), run as its own systemd user service, outside the board's web and worker services, so restarting, redeploying or crashing the board never kills it.
- One tmux session per project, named by the `board.toml` repo key (beads-board meta-work in `beads-board`, form-engine work in `form-engine`, and so on), created on first launch.
- One window per bead inside its project's session; launching a bead that already has a window focuses it instead of starting another.
- The board never kills a window on its own.
- Launchable: unplanned beads (no parent epic) and epics still at idea or draft stage; tickets inside a ticketed epic keep going through the coordinator's dispatch (user, Q1).
- The launched session is a Claude Code coordinator for that one bead (plans, specs, dispatches builds to pi, reviews, posts inbox requests), on the default model: no `--model` flag (user, Q2).

## Questions for the spec

1. Where the coordinator runs: the main checkout (recommended; with ticket files, parallel coordinators edit separate files and only clash at commit time) or a worktree.
2. The opening prompt: the ticket file path plus the starting skill (`/tight-spec` for an idea epic, `flow` for an unplanned bead).
3. Waiting for the user: a launched session that hits a permission prompt or asks a question sits unseen in tmux. Whether a Claude Code hook posts an inbox request ("session waiting") so it reaches the user's notifications.
4. Permission mode for launched sessions (default prompts vs. a stricter or looser mode).
5. Tracking: the board records the session (a fixed `--session-id`, window, project); the ticket shows running/ended with an attach command; a launch whose window is gone offers resume (`claude --resume`).
6. Window lifecycle: what the window does when Claude exits (stays open with a shell, or closes), and how many launched sessions may run at once.
7. The tmux server service: unit name and socket (`tmux -L foreman` after the rename), started at login like the board's units.

Paused 2026-10-18 at Q3 (where the coordinator runs) while ticket files replace beads (bb-axu); resume after the rename.
