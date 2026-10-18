# Planning session server

Install only with the user's approval. Requires tmux 3.4 (tested), Claude Code on the web service's PATH, and the normal Claude login. Keep this unit separate from the web and worker units: no PartOf, BindsTo or restart dependency.

```sh
install -d "$HOME/.config/systemd/user"
install -m 644 deploy/systemd/foreman-tmux.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now foreman-tmux.service
systemctl --user status foreman-tmux.service
tmux -L foreman list-sessions
```

Install before the first Launch. If a server already owns the `foreman` socket, inspect and preserve its sessions; do not kill it to install the unit. Schedule a manual migration when those conversations are finished. `tmux -D` keeps the server foreground and disables exit-empty, so an empty server stays available.

Launch uses `tmux -N`: the board cannot accidentally start a server inside the web service's cgroup. Restarting the web or worker leaves this independent unit and attached clients alone. Stopping **this** unit, logging out without lingering, or rebooting ends its processes. Enable user lingering separately if sessions must survive logout; do not restart this unit as part of an app deployment.

The server uses no personal tmux configuration. Each project gets a session on first Launch; ticket IDs name its windows. The attach command targets the project and ticket window. Claude inherits the launching web process's environment and uses its default model and permission mode. No global Claude configuration is written.

Prompt overrides are read from the foreman skill's `templates/session-launch/{epic,bug,feature,task}.md` under the globally linked skill directory. Placeholders: `{{ticket}}`, `{{project}}`, `{{source}}`. Install those files before Launch. Missing templates refuse launch in normal environments; only test and acceptance configuration enables the built-in fallback.

## Adapter gotcha

Tmux 3.4 can print a socket-creation error with exit status zero (for an invalid socket path). The adapter also validates that new-window output is a tmux window ID; exit status alone is not launch evidence.
