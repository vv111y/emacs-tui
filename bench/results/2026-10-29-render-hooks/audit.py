"""Validate the retained render-hook filtering pair and print its comparison."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('benchmark', ROOT / 'bench/run.py')
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)
reports = [json.loads((HERE / name).read_text()) for name in ('before.json', 'after.json')]
for report in reports:
    assert report['schema'] == 1
    assert report['emacs'] == '29.3' and report['load_mode'] == 'bytecode'
    assert report['presentation'] == report['backend'] == 'windows'
    assert not report['source']['source_dirty']
    assert report['samples'] == 30 and report['warmup'] == 5
    assert report['quantile_method'] == 'nearest-rank'
    assert report['cases'] == [{'kind': 'filter-list', 'size': n} for n in (100, 10000)]
    assert len(report['records']) == 70
    assert len(report['summaries']) == 2
    assert all(value.endswith('.elc') for value in report['loaded_libraries'].values())
    assert report['deferred_native_compilation'] is False
    for index, case in enumerate(report['cases']):
        records = [r for r in report['records'] if r['case'] == index]
        assert [r['sequence'] for r in records] == list(range(35))
        assert [r['warmup'] for r in records] == [True] * 5 + [False] * 30
        for r in records:
            insertion = r['sequence'] % 2 == 0
            assert r['command'] == ('self-insert-command' if insertion else 'delete-backward-char')
            assert r['visible_rows'] == (case['size'] // 10 if insertion else case['size'])
        measured = [r for r in records if not r['warmup']]
        summary = report['summaries'][index]
        assert summary['metrics'] == benchmark.metrics(measured)
        assert [c['command'] for c in summary['by_command']] == [
            'delete-backward-char', 'self-insert-command']
        for command in summary['by_command']:
            rows = [r for r in measured if r['command'] == command['command']]
            assert command['samples'] == len(rows) == 15
            assert command['metrics'] == benchmark.metrics(rows)

before, after = reports
for field in ('host', 'emacs', 'system_configuration', 'features', 'terminal',
              'frame_columns', 'frame_rows', 'gc_cons_threshold', 'gc_cons_percentage',
              'pty', 'filter_fixture', 'provider_fixture', 'completion_stages', 'pty_launcher'):
    assert before[field] == after[field], field
for field, changed in (('sha256', 'emacs-tui.el'),):
    a, b = (r['source'][field] for r in reports)
    assert a.keys() == b.keys()
    assert [key for key in a if a[key] != b[key]] == [changed]
for name in ('bench/run.py', 'bench/interactive.el'):
    assert before['source']['sha256'][name] == hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
assert before['bytecode_sha256'].keys() == after['bytecode_sha256'].keys()
assert [key for key in before['bytecode_sha256']
        if before['bytecode_sha256'][key] != after['bytecode_sha256'][key]] == ['emacs-tui.elc']
print('PASS: 140 raw records, matching host/fixtures, all pooled/per-command quantiles')
for i, case in enumerate(before['cases']):
    for j, command in enumerate(before['summaries'][i]['by_command']):
        values = []
        for report in reports:
            m = report['summaries'][i]['by_command'][j]['metrics']
            values.append(' / '.join(f'{m["pty_output_ms"][q]:.3f}' for q in ('p50', 'p95', 'p99')))
        print(case['size'], command['command'], *values, sep=' | ')
