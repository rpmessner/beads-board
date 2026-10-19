#!/usr/bin/env python3
"""Replay saved exports and scratch clones; never export from or modify a real repo.

Usage: python3 tools/adopt-format-dry-run.py EXPORT_DIRECTORY NEW_EVIDENCE_DIRECTORY
The source directory contains NAME-export.jsonl and NAME-clone for each repo.
Build this checkout's foreman escript first. Existing destinations are refused.
Adapted from the coordinator's dry.py: saved exports replace its live bd export.
"""
import collections
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

source, evidence = map(lambda p: Path(p).resolve(), sys.argv[1:])
worktree = Path(__file__).resolve().parents[1]
escript = worktree / "foreman"
evidence.mkdir(parents=True, exist_ok=False)


def run(args, **kwargs):
    return subprocess.check_output(list(map(str, args)), text=True, stderr=subprocess.STDOUT, **kwargs)


def hashes(root, config):
    paths = [p for p in root.rglob("*") if p.is_file() and ".git" not in p.relative_to(root).parts]
    paths += [p for p in config.rglob("*") if p.is_file()]
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


for name in ("dotfiles", "ui-o-matic", "cooldown-o-matic"):
    root, config = evidence / f"{name}-clone", evidence / f"{name}-config"
    export = source / f"{name}-export.jsonl"
    records = [json.loads(line) for line in export.read_text().splitlines()]
    run(["git", "clone", "-q", "--no-hardlinks", source / f"{name}-clone", root])
    origin = run(["git", "-C", source / f"{name}-clone", "remote", "get-url", "origin"]).strip()
    run(["git", "-C", root, "remote", "set-url", "origin", origin])
    beads = root / ".beads"
    beads.mkdir(exist_ok=True)
    (beads / "issues.jsonl").write_bytes(export.read_bytes())
    run(["git", "-C", root, "config", "core.hooksPath", ".beads/hooks"])
    env = dict(os.environ, FOREMAN_CONFIG_DIR=str(config), FOREMAN_URL="http://127.0.0.1:1")
    first = json.loads(run([escript, "adopt", root, "--json"], env=env))
    (config / "first.json").write_text(json.dumps(first, indent=2))
    assert first["comparison"]["count"] == len(records), first
    # Adopt re-encodes JSON keys; compare records, not serialization order.
    assert [json.loads(line) for line in Path(first["export"]).read_text().splitlines()] == records
    assert Path(first["backup"]).is_file()
    assert not beads.exists()
    check = json.loads(run([escript, "check", "--json"], cwd=root, env=env))
    assert check == {"valid": True, "errors": []}, check
    comparison = run(["mix", "run", "--no-start", "tools/adopt-compare.exs", export, root], cwd=worktree)
    (config / "comparison.txt").write_text(comparison)
    tickets = json.loads(run([escript, "ls", "--json"], cwd=root, env=env))
    by_id = {t["id"]: t for t in tickets}
    expected_edges, actual_edges = collections.Counter(), collections.Counter()
    for record in records:
        ticket = by_id[record["id"]]
        assert ticket["type"] == ("epic" if record["issue_type"] == "convoy" else record["issue_type"])
        for dep in record.get("dependencies", []):
            kind = "related" if dep["type"] == "tracks" else dep["type"]
            expected_edges[(record["id"], kind, dep["depends_on_id"])] += 1
        for field, kind in (("blocked_by", "blocks"), ("related", "related"), ("supersedes", "supersedes")):
            for target in ticket[field]:
                actual_edges[(ticket["id"], kind, target)] += 1
        for field, kind in (("parent", "parent-child"), ("discovered_from", "discovered-from")):
            if ticket[field]:
                actual_edges[(ticket["id"], kind, ticket[field])] += 1
    assert expected_edges == actual_edges
    before = hashes(root, config)
    rerun = json.loads(run([escript, "adopt", root, "--json"], env=env))
    assert rerun["changes"] == [], rerun
    assert before == hashes(root, config)
    (config / "rerun.json").write_text(json.dumps(rerun, indent=2))
    counts = collections.Counter()
    for (_, kind, _), count in actual_edges.items():
        counts[kind] += count
    summary = dict(repo=name, count=len(tickets), comparison="equal", mapped_relations=dict(counts), check=check, rerun="no-op; hashes unchanged")
    (config / "summary.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary), flush=True)
