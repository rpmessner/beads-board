#!/usr/bin/env python3
"""Demonstrate Dolt's lock retry on an existing scratch copy, never a live repo.

Usage: python3 tools/probe-bd-lock.py /tmp/bb-probe/inspect
Holds the actual journal flock for two seconds while a bd export opens.
Records /proc lock visibility, persistent-file behavior and command result.
"""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).parent))
from importlib import import_module
probe = import_module('probe-bd-concurrency')


def main():
    repo = probe.scratch(Path(sys.argv[1]))
    if (repo / '.beads/redirect').exists():
        raise ValueError('Redirect not allowed')
    lock, = (repo / '.beads/embeddeddolt').glob('*/.dolt/noms/LOCK')
    if not lock.resolve().is_relative_to(repo):
        raise ValueError('External lock not allowed')
    env = probe.probe_env(repo)
    with lock.open('rb') as f:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        st = lock.stat()
        token = f'{os.major(st.st_dev):02x}:{os.minor(st.st_dev):02x}:{st.st_ino}'
        visible = [line for line in Path('/proc/locks').read_text().splitlines()
                   if token in line]
        start = time.monotonic()
        proc = subprocess.Popen(['bd', 'export'], cwd=repo, env=env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        time.sleep(2)
        waiting = proc.poll() is None
        fcntl.flock(f, fcntl.LOCK_UN)
        _, stderr = proc.communicate(timeout=60)
    result = dict(lock=str(lock.relative_to(repo)), proc_locks=visible,
                  waiting_after_two_seconds=waiting, elapsed=time.monotonic()-start,
                  rc=proc.returncode, stderr=stderr, file_exists_after=lock.exists())
    print(json.dumps(result, indent=2))
    assert visible and waiting and proc.returncode == 0, result


if __name__ == '__main__':
    main()
