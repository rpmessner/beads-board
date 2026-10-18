# Session launcher

Status: idea, not yet specced (2026-10-18). Board draft epic `draft:session-launcher`. Spec after the approvals inbox and devserve.

## Idea

From an unplanned bead in any project, launch a Claude session in tmux to work it, creating the tmux session or window when missing; attach to it from a terminal at any time.

## Settled so far (user, 2026-10-18)

- One tmux server owned by the board (`tmux -L beads-board`), run as its own systemd user service, outside the board's web and worker services, so restarting, redeploying or crashing the board never kills it.
- One tmux session per project, named by the `board.toml` repo key (beads-board meta-work in `beads-board`, form-engine work in `form-engine`, and so on), created on first launch.
- One window per bead inside its project's session; launching a bead that already has a window focuses it instead of starting another.
- The board never kills a window on its own.

## Questions for the spec

- The opening prompt (the bead's content, plus which skill to start with: `/tight-spec` for an idea, straight to work for a small bug).
- Main checkout or a new worktree per launch, and who creates it.
- What counts as "unplanned" (the Unplanned group only, or any open bead).
- How the board learns the window's state (session records through `board` CLI, as today) and shows it on the ticket.
- Interaction with the MVP non-goal "launching, steering or killing pi/tmux sessions", which this overturns.
