#!/usr/bin/env python3
"""Compare scratch bd with the running board's Postgres projection; verify note freshness.
Requires the default local development database and completed writer acceptance.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time
import sys

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("probe", Path(__file__).with_name("probe-bd-concurrency.py"))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
root = Path("/tmp/bb-exec")
probe.ROOT = root


def sql(query):
    env = dict(os.environ, PGPASSWORD="postgres")
    return subprocess.check_output(["psql", "-X", "-h", "localhost", "-U", "postgres", "-d", "beads_board_dev", "-Atc", query], env=env, text=True).strip()


def bd(repo, args):
    result = subprocess.run(["bd", *args], cwd=probe.scratch(repo), env=probe.probe_env(repo), capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stderr
    return result.stdout


summary = json.loads((root / "writer-summary.json").read_text())
assert summary["elapsed"] >= 600 and summary["failed"] == 0, summary
counts = {}
for repo in sorted((root / "repos").iterdir()):
    if repo.name == "we_go_next_dev":
        assert sql("SELECT state FROM repo_sync WHERE key='we_go_next_dev'") == "unreachable"
        counts[repo.name] = "unreachable (server-mode metadata; no server opened)"
        continue
    actual = len(json.loads(bd(repo, ["list", "--json", "--all", "--limit", "0"])))
    projected = int(sql(f"SELECT count(*) FROM beads WHERE repo_key='{repo.name}'"))
    assert actual == projected, (repo.name, actual, projected)
    counts[repo.name] = dict(bd=actual, projection=projected)

repo = root / "repos/form-engine"
issue = bd(repo, ["create", "Board idle freshness acceptance", "--silent"]).strip()
marker = "Board freshness marker " + str(time.time_ns())
bd(repo, ["note", issue, marker])
started = time.monotonic()
while True:
    note = sql(f"SELECT raw->>'notes' FROM beads WHERE repo_key='form-engine' AND bead_id='{issue}'")
    if marker in note:
        break
    assert time.monotonic() - started < 5, "idle note freshness exceeded 5 seconds"
    time.sleep(.05)
freshness = time.monotonic() - started

rows = json.loads(sql("SELECT json_agg(raw) FROM beads WHERE repo_key='form-engine'"))
by_id = {row['id']: row for row in rows}
records = json.loads((root / "writer-commands.json").read_text())
audited = 0
for record in records:
    args = record["args"]
    assert record['rc'] == 0
    if args[0] == 'create':
        issue_id = record['stdout'].strip()
        assert by_id[issue_id]['title'] == args[1]
        assert by_id[issue_id]['status'] == 'closed'
        audited += 1
    elif args[0] == 'note':
        assert args[2] in by_id[args[1]].get('notes', '')
    elif args[0] == 'dep':
        assert any(d['depends_on_id'] == args[3] and d['type'] == 'related'
                   for d in by_id[args[2]].get('dependencies', []))
# Create and delete only a fresh, unlinked scratch issue; retain its overlay fact.
removal_id = bd(repo, ["create", "Board scratch removal acceptance", "--silent"]).strip()
assert all(c.isalnum() or c in '-_.' for c in removal_id)
started = time.monotonic()
while sql(f"SELECT count(*) FROM beads WHERE repo_key='form-engine' AND bead_id='{removal_id}'") != '1':
    assert time.monotonic() - started < 5, 'scratch create was not projected'
    time.sleep(.05)
sql(f"INSERT INTO tickets (repo_key,bead_id,stage,stage_changed_at) VALUES ('form-engine','{removal_id}','building',now())")
bd(repo, ["delete", removal_id, "--force"])
started = time.monotonic()
while sql(f"SELECT count(*) FROM beads WHERE repo_key='form-engine' AND bead_id='{removal_id}'") != '0':
    assert time.monotonic() - started < 5, 'scratch deletion was not projected'
    time.sleep(.05)
assert sql(f"SELECT stage || ':' || (orphaned_at IS NOT NULL)::text FROM tickets WHERE repo_key='form-engine' AND bead_id='{removal_id}'") == 'building:true'
result = dict(writer=summary, counts=counts, note_visible_seconds=freshness,
              created_issues_and_notes_audited=audited, deletion_and_overlay_orphan_preservation=True)
(root / "acceptance.json").write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
