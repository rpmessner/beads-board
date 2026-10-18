#!/usr/bin/env python3
"""Exercise the built escript offline; print a reproducible demo and final files."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

board = Path(__file__).resolve().parents[1] / "board"
with tempfile.TemporaryDirectory(prefix="board-files-demo-") as directory:
    root = Path(directory)
    subprocess.run(["git", "init", "-q", directory], check=True)
    config = root / "config"
    config.mkdir()
    (config / "board.toml").write_text(
        '[[repos]]\nkey = "demo"\nprefix = "demo"\npath = ' + json.dumps(directory) + "\n"
    )
    env = dict(os.environ, BOARD_CONFIG_DIR=str(config), BOARD_URL="http://127.0.0.1:1",
               BOARD_DATABASE_URL="postgres://none:none@127.0.0.1:1/none", PGPORT="1")

    def run(*args):
        print("$ board " + shlex.join(args) + " --json")
        result = subprocess.run([str(board), *args, "--json"], cwd=root, env=env,
                                text=True, capture_output=True, check=True)
        print(result.stdout.strip())
        return json.loads(result.stdout)

    epic = run("new", "Offline epic", "--type", "epic")["id"]
    first = run("new", "Foundation", "--parent", epic)["id"]
    second = run("new", "Consumer", "--parent", epic, "--blocked-by", first)["id"]
    run("ready")
    run("close", first, "--reason", "Tests passed")
    run("ready")
    run("check")
    run("tree")
    run("renumber", first, epic + ".4")
    run("check")
    for path in sorted((root / "tickets").glob("*.md")):
        print("\n# tickets/" + path.name)
        print(path.read_text(), end="")
