#!/usr/bin/env python3
"""Prepare isolated real-repo copies for live-board acceptance; never opens originals with bd."""
import importlib.util
import json
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("probe", Path(__file__).with_name("probe-bd-concurrency.py"))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
root = Path("/tmp/bb-exec")
probe.ROOT = root
sources = ["music/form-engine", "utils/beads-board", "utils/skills", "dotfiles",
           "games/wow-addons/ui-o-matic", "games/wow-addons/cooldown-o-matic",
           "games/wow-addons/we_go_next_dev"]
(root / "config").mkdir(parents=True, exist_ok=True)
blocks = []
for relative in sources:
    source = Path.home() / "dev" / relative
    dest = root / "repos" / source.name
    if not dest.exists():
        if source.name == "we_go_next_dev":
            # Preserve only server-mode metadata. Never copy server PID/port files
            # which could cause an accidental connection to the live database.
            (dest / ".beads").mkdir(parents=True)
            shutil.copyfile(source / ".beads/metadata.json", dest / ".beads/metadata.json")
        else:
            probe.copy_repo(source, dest)
    blocks.append(f'[[repos]]\nkey = {json.dumps(source.name)}\npath = {json.dumps(str(dest))}\n')
(root / "config/board.toml").write_text("\n".join(blocks))
print("Prepared", len(blocks), "isolated repos under /tmp/bb-exec/repos")
