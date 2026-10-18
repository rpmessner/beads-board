#!/usr/bin/env python3
"""Scratch-only bd concurrency probe. No dependencies beyond Python 3 and bd.

python3 tools/probe-bd-concurrency.py --seconds 600
Copies whole repos (excluding .git and symlinks) into a new /tmp/bb-probe run.
Four isolated scenarios run concurrently; each has exactly one writer and reader.
Raw outputs stay in scratch; summary/errors contain no issue content.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import threading
import time

ROOT = Path('/tmp/bb-probe')


def scratch(path):
    path = path.resolve()
    if not path.is_relative_to(ROOT.resolve()) or path == ROOT.resolve():
        raise ValueError(f'Not a scratch child: {path}')
    return path


def probe_env(dest):
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('BEADS_', 'BD_', 'DOLT_', 'GIT_'))}
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null',
               GIT_TEMPLATE_DIR='', BEADS_ACTOR='concurrency-probe',
               DOLT_METRICS_DISABLED='1', BD_METRICS_DISABLED='true',
               BD_NO_HOOKS='true', BD_DOLT_AUTO_PUSH='false',
               BD_BACKUP_ENABLED='false', BD_EXPORT_PATH='issues.jsonl',
               BD_ROUTING_DEFAULT=str(dest), BD_ROUTING_MAINTAINER=str(dest),
               BD_ROUTING_CONTRIBUTOR=str(dest))
    return env


def copy_repo(source, dest):
    # Never preserve redirect files or links to a live worktree/store.
    def ignore(directory, names):
        return [n for n in names if n == '.git' or (Path(directory) / n).is_symlink()]
    shutil.copytree(source, scratch(dest), ignore=ignore)
    for name in ('redirect',):
        p = dest / '.beads' / name
        if p.exists():
            raise ValueError(f'Redirect not supported: {p}')
    allowed_keys = {'issue-prefix', 'issue_prefix', 'sync.remote', 'types.custom',
                    'export.auto', 'dolt.mode'}
    for line in (dest / '.beads/config.yaml').read_text().splitlines():
        if line.strip() and not line.lstrip().startswith('#'):
            if line.partition(':')[0] not in allowed_keys:
                raise ValueError(f'Config requires safety review before probing: {line}')
    meta = json.loads((dest / '.beads/metadata.json').read_text())
    if meta.get('dolt_mode', 'embedded') != 'embedded':
        raise ValueError('Only embedded stores allowed')
    # Isolate git discovery/config and hooks as well as bd state.
    subprocess.run(['git', 'init', '-q', str(dest)], check=True, env=probe_env(dest))


def scenario(source, run, interval, seconds):
    name = f'{source.name}-{interval:g}s'
    dest = run / name
    copy_repo(source, dest)
    env = probe_env(dest)
    records = []
    mutex = threading.Lock()
    raw = dest / 'probe-output'
    raw.mkdir()

    def command(role, args):
        started = time.monotonic()
        try:
            result = subprocess.run(['bd', *args], cwd=scratch(dest), env=env,
                                    capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired as error:
            def text(value):
                return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
            result = subprocess.CompletedProcess(
                ['bd', *args], 124, text(error.stdout),
                text(error.stderr) + '\nPROBE HARNESS: command exceeded 60 seconds; killed\n')
        row = dict(role=role, args=args, start=started, elapsed=time.monotonic()-started,
                   rc=result.returncode, stderr=result.stderr)
        with mutex:
            number = len(records)
            records.append(row)
            (raw / f'{number:06d}.stdout').write_text(result.stdout)
            with (raw / 'commands.jsonl').open('a') as f:
                f.write(json.dumps(row) + '\n')
        return result

    initial = command('setup', ['export'])
    if initial.returncode:
        raise RuntimeError(initial.stderr)
    anchor = command('setup', ['create', 'Probe dependency anchor', '--silent'])
    if anchor.returncode:
        raise RuntimeError(anchor.stderr)
    anchor_id = anchor.stdout.strip()
    start = time.monotonic()
    deadline = start + seconds
    stop = threading.Event()
    lock_samples = {}

    def observe():
        # /proc/locks is passive: unlike flock tests it cannot obstruct bd.
        while not stop.is_set():
            paths = [p for p in (dest / '.beads').rglob('*') if 'lock' in p.name.lower()]
            text = Path('/proc/locks').read_text()
            for p in paths:
                try:
                    st = p.stat()
                except FileNotFoundError:
                    continue
                key = str(p.relative_to(dest))
                entry = lock_samples.setdefault(key, dict(samples=0, held=0))
                entry['samples'] += 1
                token = f'{os.major(st.st_dev):02x}:{os.minor(st.st_dev):02x}:{st.st_ino}'
                matches = [line for line in text.splitlines() if token in line]
                if matches:
                    entry['held'] += 1
                    entry['example'] = matches[0]
            stop.wait(.02)

    def writer():
        cycle = 0
        while time.monotonic() < deadline:
            cycle += 1
            made = command('write', ['create', f'Probe cycle {cycle}', '--silent'])
            if made.returncode == 0:
                issue = made.stdout.strip()
                for args in (['update', issue, '--status', 'in_progress'],
                             ['note', issue, f'Probe note {cycle}'],
                             ['dep', 'add', issue, anchor_id, '--type', 'related'],
                             ['close', issue, '--reason', 'Probe complete']):
                    command('write', args)
            time.sleep(.05)

    def reader():
        next_read = start
        while time.monotonic() < deadline:
            command('read', ['export'])
            next_read += interval
            # No overlapping reads and no catch-up burst if export is slow.
            next_read = max(next_read, time.monotonic())
            time.sleep(max(0, min(next_read, deadline)-time.monotonic()))

    observer = threading.Thread(target=observe)
    observer.start()
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(writer), pool.submit(reader)]
            for future in futures:
                future.result()
    finally:
        stop.set()
        observer.join()
    elapsed = time.monotonic()-start
    final = command('verify', ['export'])
    summary = dict(name=name, seconds=seconds, elapsed=elapsed,
                   initial_issues=len(initial.stdout.splitlines()), locks=lock_samples,
                   final_export_rc=final.returncode, counts={}, errors=[])
    for role in ('write', 'read'):
        rows = [r for r in records if r['role'] == role]
        summary['counts'][role] = dict(attempts=len(rows), failed=sum(r['rc'] != 0 for r in rows),
                                      max_seconds=max(r['elapsed'] for r in rows))
        summary['counts'][role]['operations'] = {
            op: dict(attempts=sum(r['args'][0] == op for r in rows),
                     failed=sum(r['args'][0] == op and r['rc'] != 0 for r in rows))
            for op in sorted({r['args'][0] for r in rows})}
    errors = {}
    for r in records:
        if r['rc']:
            key = (r['role'], r['rc'], r['stderr'])
            errors[key] = errors.get(key, 0) + 1
    summary['errors'] = [dict(role=k[0], rc=k[1], stderr=k[2], count=v)
                         for k, v in errors.items()]
    summary['commands_sha256'] = hashlib.sha256((raw/'commands.jsonl').read_bytes()).hexdigest()
    (run / f'{name}.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary), flush=True)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, default=600)
    parser.add_argument('--sources', nargs='+', type=Path, default=[
        Path.home()/'dev/music/form-engine', Path.home()/'dev/games/wow-addons/ui-o-matic'])
    parser.add_argument('--intervals', nargs='+', type=float, default=[3, .1])
    args = parser.parse_args()
    if args.seconds < 1 or any(i <= 0 for i in args.intervals):
        parser.error('positive intervals and duration >= 1 required')
    ROOT.mkdir(exist_ok=True)
    run = ROOT / time.strftime('run-%Y%m%d-%H%M%S')
    run.mkdir()
    print(f'Artifacts: {run}', flush=True)
    jobs = [(source.resolve(), interval) for source in args.sources for interval in args.intervals]
    names = [f'{source.name}-{interval:g}s' for source, interval in jobs]
    if len(names) != len(set(names)):
        parser.error('source basenames and intervals must identify unique scenarios')
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(jobs)) as pool:
        futures = [pool.submit(scenario, source, run, interval, args.seconds)
                   for source, interval in jobs]
        results = [future.result() for future in futures]
    (run/'summary.json').write_text(json.dumps(results, indent=2)+'\n')


if __name__ == '__main__':
    main()
