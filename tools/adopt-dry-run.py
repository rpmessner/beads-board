#!/usr/bin/env python3
"""Replay the tracked beads export through the actual escript, without a live store."""
import hashlib
import json
import os
import pathlib
import subprocess
import sys

source = pathlib.Path(__file__).resolve().parent.parent
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/fm-adopt-dry")
config = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "/tmp/fm-adopt-dry-config")
if root.exists() or config.exists():
    raise SystemExit("Use fresh scratch checkout and config paths; existing artifacts are retained.")


def run(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs)


env = dict(os.environ, FOREMAN_CONFIG_DIR=str(config), FOREMAN_URL="http://127.0.0.1:1")
run(["git", "clone", "--no-hardlinks", str(source), str(root)])
origin = run(["git", "-C", str(source), "remote", "get-url", "origin"]).strip()
run(["git", "-C", str(root), "remote", "set-url", "origin", origin])
export = run(["git", "-C", str(source), "show", "main:.beads/issues.jsonl"])
(root / ".beads").mkdir(exist_ok=True)
(root / ".beads/issues.jsonl").write_text(export)
run(["git", "-C", str(root), "config", "core.hooksPath", ".beads/hooks"])
executable = str(source / "foreman")
first = json.loads(run([executable, "adopt", str(root), "--json"], env=env))
(config / "first.json").write_text(json.dumps(first, indent=2))
(config / "source.jsonl").write_text(export)
assert first["comparison"] == {"count": 40, "comments": 2}, first
assert first["entry"]["github"] == "rpmessner/foreman"
assert not (root / ".beads").exists()
assert pathlib.Path(first["backup"]).is_file()
assert run(["tar", "-xOf", first["backup"], ".beads/issues.jsonl"]) == export
check = json.loads(run([executable, "check", "--json"], cwd=root, env=env))
assert check == {"valid": True, "errors": []}, check
for ticket in (root / "tickets").glob("*.md"):
    assert "## Beads provenance" not in ticket.read_text(), ticket


def snapshot():
    paths = [root / "AGENTS.md", root / ".git/config", config / "foreman.toml"]
    paths += list((root / "tickets").glob("*")) + list((root / ".foreman/hooks").glob("*"))
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


before = snapshot()
second = json.loads(run([executable, "adopt", str(root), "--json"], env=env))
assert second["changes"] == [], second
assert snapshot() == before
(config / "rerun.json").write_text(json.dumps(second, indent=2))
comparison = run(["mix", "run", "--no-start", "tools/adopt-compare.exs", str(config / "source.jsonl"), str(root)], cwd=source)
(config / "comparison.txt").write_text(comparison)
print(comparison)
print("tickets/:")
print("\n".join(p.name for p in sorted((root / "tickets").glob("*.md"))))
print("check valid; rerun no-op (change list and file hashes); backup:", first["backup"])
print("No converted ticket contains a provenance section.")
print("fm-zgd.3.md bytes:", (root / "tickets/fm-zgd.3.md").stat().st_size)
print("Full change:", config / "first.json")
