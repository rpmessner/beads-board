"""Restart only the isolated acceptance server; prove its tmux clients and panes survive."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.request

assert Path.cwd().name == "fm-launch"
socket = os.environ["LAUNCH_SCRATCH_SOCKET"]
assert socket.startswith("fm-launch-")
assert os.environ["PORT"] == "4784" and os.environ["MIX_ENV"] == "acceptance"
out = Path("docs/acceptance/fm-launch")
pidfile = Path("/tmp/fm-launch-server.pid")

def tmux(*args):
    return subprocess.check_output(["tmux", "-L", socket, *args], text=True).strip()

def ready():
    try:
        return urllib.request.urlopen("http://127.0.0.1:4784", timeout=1).status == 200
    except Exception:
        return False

def until(predicate):
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.1)
    raise AssertionError("acceptance server readiness timeout")

control = subprocess.Popen(["tmux", "-L", socket, "-C", "attach", "-t", "scratch:draft:greeting"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
try:
    until(lambda: tmux("list-clients", "-F", "#{client_pid}") != "")
    before = tmux("list-panes", "-a", "-F", "#{session_name}:#{window_name}:#{pane_id}:#{pane_pid}")
    clients = tmux("list-clients", "-F", "#{client_pid}")
    pid = int(pidfile.read_text())
    assert "beam" in Path(f"/proc/{pid}/comm").read_text()
    os.kill(pid, signal.SIGTERM)
    until(lambda: not ready())
    assert control.poll() is None
    assert tmux("list-panes", "-a", "-F", "#{session_name}:#{window_name}:#{pane_id}:#{pane_pid}") == before
    with open("/tmp/fm-launch-server.txt", "w") as log:
        process = subprocess.Popen(["mix", "run", "--no-start", "tools/launch-acceptance.exs"], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    pidfile.write_text(str(process.pid))
    until(ready)
    assert tmux("list-panes", "-a", "-F", "#{session_name}:#{window_name}:#{pane_id}:#{pane_pid}") == before
    assert tmux("list-clients", "-F", "#{client_pid}") == clients
    for target, name in [("scratch:scratch-1", "task"), ("scratch:draft:greeting", "epic"), ("scratch:scratch-bug", "bug")]:
        (out / f"claude-{name}.txt").write_text(tmux("capture-pane", "-p", "-S", "-100", "-t", target) + "\n")
    (out / "restart.json").write_text(json.dumps({"panes_before_and_after": before, "attached_client_preserved": clients, "server_restarted": True, "monitor_restarted": True}, indent=2) + "\n")
    print("PASS: web and liveness monitor restart preserves every pane and attached control client")
finally:
    control.terminate()
    control.wait(timeout=5)
