#!/usr/bin/env python3
"""Audit a completed probe's raw commands and final exports; emit content-free evidence."""
import hashlib
import json
from pathlib import Path
import sys


def verify(run):
    summaries = json.loads((run / 'summary.json').read_text())
    results = []
    for summary in summaries:
        raw = run / summary['name'] / 'probe-output'
        data = (raw / 'commands.jsonl').read_bytes()
        assert hashlib.sha256(data).hexdigest() == summary['commands_sha256']
        rows = [json.loads(line) for line in data.splitlines()]
        assert summary['seconds'] >= 600 and summary['elapsed'] >= 600
        for role in ('read', 'write'):
            selected = [r for r in rows if r['role'] == role]
            assert len(selected) == summary['counts'][role]['attempts']
            assert sum(r['rc'] != 0 for r in selected) == summary['counts'][role]['failed']
        assert set(summary['counts']['write']['operations']) == {'create', 'update', 'note', 'dep', 'close'}
        final_index = next(i for i, r in enumerate(rows) if r['role'] == 'verify')
        assert rows[final_index]['rc'] == 0
        exported = {issue['id']: issue for issue in
                    map(json.loads, (raw / f'{final_index:06d}.stdout').read_text().splitlines())}
        created, checked = set(), 0
        for i, row in enumerate(rows):
            if row['role'] != 'write' or row['rc']:
                continue
            args = row['args']
            if args[0] == 'create':
                issue_id = (raw / f'{i:06d}.stdout').read_text().strip()
                assert issue_id in exported
                created.add(issue_id)
                assert exported[issue_id]['title'] == args[1]
            elif args[0] == 'note':
                assert args[2] in exported[args[1]]['notes']
            elif args[0] == 'dep':
                assert any(d['depends_on_id'] == args[3] and d['type'] == 'related'
                           for d in exported[args[2]]['dependencies'])
            elif args[0] == 'close':
                assert exported[args[1]]['status'] == 'closed'
            elif args[0] == 'update':
                # Closed supersedes in_progress: check the command acknowledgment.
                assert args[1] in (raw / f'{i:06d}.stdout').read_text()
            checked += 1
        assert len(exported) == summary['initial_issues'] + 1 + len(created)
        results.append(dict(scenario=summary['name'], successful_writes_checked=checked,
                            created=len(created), final_issues=len(exported), verified=True))
    return results


if __name__ == '__main__':
    print(json.dumps(verify(Path(sys.argv[1])), indent=2))
