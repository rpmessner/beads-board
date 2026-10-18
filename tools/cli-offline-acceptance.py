"""After cli-acceptance.cjs, stop only its isolated server and prove durable replay."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.request
import uuid

root = Path.cwd()
env = dict(os.environ, FOREMAN_URL="http://127.0.0.1:4759",
           FOREMAN_TOKEN_FILE=str(root / "tmp/cli-token"),
           PGDATABASE=f"foreman_acceptance_{root.name}", PGHOST="127.0.0.1", PGPORT="5432",
           PGUSER="postgres", PGPASSWORD="postgres", FOREMAN_DATABASE_URL="", DATABASE_URL="")


def cli(*args, overrides=None):
    result = subprocess.run([str(root / "foreman"), *args, "--json"],
                            env=env | (overrides or {}), text=True,
                            capture_output=True, timeout=12)
    assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
    assert result.stderr == "", result.stderr
    return {"exit": result.returncode, "body": json.loads(result.stdout)}


def sql(query):
    return subprocess.check_output(["psql", "-X", "-tAq", "-c", query],
                                   env=env, text=True).strip()


def stop():
    pid = int((root / "tmp/cli-server.pid").read_text())
    cmdline = Path(f"/proc/{pid}/cmdline").read_bytes()
    assert b"cli-acceptance-server.exs" in cmdline
    os.kill(pid, signal.SIGTERM)
    for _ in range(100):
        try:
            urllib.request.urlopen(env["FOREMAN_URL"], timeout=0.2)
        except OSError:
            return
        time.sleep(0.1)
    raise AssertionError("isolated server did not stop")


def start():
    log = open(root / "tmp/cli-server.log", "a")
    server = subprocess.Popen(["mix", "run", "--no-halt", "tools/cli-acceptance-server.exs"],
                              env=env | {"MIX_ENV": "acceptance",
                                         "FOREMAN_ROLE": "web", "PORT": "4759", "PHX_SERVER": "true"},
                              stdout=log, stderr=subprocess.STDOUT)
    (root / "tmp/cli-server.pid").write_text(str(server.pid))
    for _ in range(100):
        assert server.poll() is None, "server failed; inspect tmp/cli-server.log"
        try:
            urllib.request.urlopen(env["FOREMAN_URL"], timeout=0.2)
            return server
        except OSError:
            time.sleep(0.1)
    raise AssertionError("isolated server did not start")


stop()
marker = "offline-" + str(uuid.uuid4())
offline = cli("progress", "scratch-1", marker)
assert "spooled" in offline["body"]["warning"]
request_id = offline["body"]["request_id"]
assert sql(f"SELECT state FROM spooled_events WHERE request_id='{request_id}'") == "pending"
database_down = cli("progress", "scratch-1", "not saved", overrides={"PGPORT": "1"})
assert "event not saved" in database_down["body"]["warning"]
server = start()
for _ in range(100):
    state = sql(f"SELECT state FROM spooled_events WHERE request_id='{request_id}'")
    if state == "applied":
        break
    time.sleep(0.1)
assert state == "applied", state
stop()
server.wait(timeout=10)
server = start()
# A second boot must not apply the same event twice.
for _ in range(100):
    history = cli("show", "scratch-1")["body"].get("history", [])
    matching = [row for row in history if row["payload"].get("body") == marker]
    if matching:
        break
    time.sleep(0.1)
assert len(matching) == 1
stop()
server.wait(timeout=10)
Path("docs/acceptance/bb-cli/offline.json").write_text(json.dumps({
    "app_down": offline, "pending_before_start": True,
    "database_down": database_down, "after_start": state,
    "history_matches_after_second_boot": len(matching)
}, indent=2) + "\n")
print("PASS: app stopped -> spooled/exit 0; Postgres unreachable -> warning/exit 0; boot replay applies once across two restarts")
