# Coordinator session

Run `foreman coordinator` in the coordinator pane on the board's tmux server. The web service must be available and authenticated CLI configuration must already work.

- No recorded conversation: launch Claude with a new `--session-id`.
- Recorded conversation: launch with `--resume`.
- `foreman coordinator --fresh`: replace the recorded conversation.
- `foreman coordinator --adopt <uuid>`: record an existing conversation without launching it. This command does not need tmux.

Stop the running coordinator before replacing or adopting its conversation. The board's Focus control selects its window; Relaunch resumes it; Start fresh requires confirmation.

The service replaces only the requesting pane, after checking its socket and its `coordinator` tmux session. Claude runs in `~/dev/music`, with `/orient` as the only prompt and the existing per-launch hooks. The service PATH must contain `claude`. No global Claude settings change.

The singleton uses the reserved system key `__foreman__/coordinator` in the existing session table. It has no ticket overlay or configured project. Only session-waiting requests use that system subject; ordinary approvals still need tickets. Idle time never parks this session. A missing window becomes `ended`, preserving its conversation ID.

## Verification notes

`test/foreman/coordinator_integration_test.exs` runs the built escript against an isolated HTTP endpoint and scratch tmux server, with a stub Claude executable. It verifies argv, working directory, identity persistence, Focus/Relaunch, Needs you and Continue. No real Claude account is used.

Tmux distinguishes socket names (`-L`) from socket paths (`-S`). The CLI's `TMUX` variable contains the latter. A new-window target needs the trailing colon (`=coordinator:`) when session and window names coincide; otherwise tmux can interpret it as occupied window zero.
