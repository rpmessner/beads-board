#!/usr/bin/env python3
"""Ten-minute writer against an already-running board reading isolated scratch.
No reader is simulated here: the application's Oban scheduler must be running.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import time
import sys

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("probe", Path(__file__).with_name("probe-bd-concurrency.py"))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
probe.ROOT = Path("/tmp/bb-exec")
repo = probe.scratch(probe.ROOT / "repos/form-engine")
assert (repo / ".git").is_dir()
anchor = subprocess.run(["bd", "create", "Board acceptance dependency anchor", "--silent"], cwd=repo,
                        env=probe.probe_env(repo), capture_output=True, text=True, timeout=90)
assert anchor.returncode == 0, anchor.stderr
anchor_id = anchor.stdout.strip()
records = []
started = time.monotonic()
cycle = 0
while time.monotonic() - started < 600:
    cycle += 1
    commands = [["create", f"Board acceptance {cycle}", "--silent"]]
    issue = None
    for index in range(5):
        args = commands[index]
        begin = time.monotonic()
        result = subprocess.run(["bd", *args], cwd=repo, env=probe.probe_env(repo),
                                capture_output=True, text=True, timeout=90)
        records.append(dict(args=args, rc=result.returncode, elapsed=time.monotonic()-begin,
                            stderr=result.stderr, stdout=result.stdout))
        if index == 0:
            if result.returncode:
                break
            issue = result.stdout.strip()
            commands.extend([["update", issue, "--status", "in_progress"],
                             ["note", issue, f"Board note {cycle}"],
                             ["dep", "add", issue, anchor_id, "--type", "related"],
                             ["close", issue, "--reason", "Board acceptance complete"]])
    (probe.ROOT / "writer-commands.json").write_text(json.dumps(records, indent=2))
    time.sleep(.05)
summary = dict(elapsed=time.monotonic()-started, attempts=len(records),
               failed=sum(r["rc"] != 0 for r in records), cycles=cycle)
(probe.ROOT / "writer-summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary), flush=True)
