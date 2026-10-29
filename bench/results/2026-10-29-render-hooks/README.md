# Render modification-hook filtering pair

This pair measures the normal filtering cost of PR105's modification-hook
isolation. It is a correctness fix, not a speed optimization. All 140 records
are retained: two sizes × (5 warmups + 30 measured commands) × two revisions.
Each command has only 15 measured samples; nearest-rank p95 and p99 therefore
both equal its maximum. The small sequential sample cannot establish a
uniform speedup, negligible overhead or a production latency bound.

## Provenance

Collected 2026-10-29 UTC, baseline at 06:18:53 then candidate at 06:19:49 on the
same shared Linux 6.18.55 x86_64 host, Intel Xeon Platinum 8573C, nine exposed
logical CPUs, Python 3.12.14. Emacs 29.3 runs in a real xterm-256color 120×40
PTY (actual Emacs frame 120×39), ordinary windows, freshly compiled libraries,
GC threshold 800000 / percentage 0.1. Deferred native compilation is disabled.
The fixture/instrumentation is interpreted in both runs. See the JSON for full
features, loaded definitions, host fields and source/bytecode hashes.

| Report | Clean local source commit | Equivalent public source |
| --- | --- | --- |
| [before.json](before.json) | `4e1584e4abcb975962c16f362d05a1d6eb44bb6f` | beta6 `0789f8af3ce4e6e741247a308335150366e30f7c`, tree `a7f40b82549b6b9564422c6b89660b4e8abe2b1b` |
| [after.json](after.json) | `32ffa27e4d836b5b67b824b6df30b916ed6d66da` | PR105 head `0eed430c1b0975d190dd54a669d6e615c6946c7f`, tree `23d90fb8326ea1cea13e3423ec2cc6df7052ce57` |

Local commit identities differ because publication uses the GitHub connector;
Git tree equality was checked against each remote source. Only `emacs-tui.el`
and its compiled library differ in the measured source/bytecode manifests.
All other library sources and both measurement fixtures are byte-identical.

## PTY output latency

Milliseconds, p50 / p95 / p99, nearest rank. These clocks include command
dispatch, forced redisplay, validation, scheduling and PTY transport, not
terminal-emulator parsing or physical paint.

| Rows | Native command | Before | After |
| --- | --- | --- | --- |
| 100 | Delete | 0.700 / 10.103 / 10.103 | 0.622 / 1.778 / 1.778 |
| 100 | Insert | 0.616 / 1.555 / 1.555 | 0.719 / 11.713 / 11.713 |
| 10000 | Delete | 35.787 / 39.226 / 39.226 | 36.881 / 39.545 / 39.545 |
| 10000 | Insert | 40.963 / 45.728 / 45.728 | 40.652 / 45.999 / 45.999 |

The small-list insertion tail worsens while deletion improves; GC appears on
different operations. The 10k command medians are close. Pooled Emacs command/
redisplay medians are 0.484 → 0.489 ms at 100 rows and 36.275 → 37.134 ms at
10k. Median cons-cell allocation rises by 10 for each command/size, while
string-character allocation is unchanged. These counters include instrumentation
and measure allocation, not retained heap or bytes. Raw reports retain GC
counts/times and every pooled/per-command metric, including warmups.

No benchmark or tests ran concurrently in this task, but the host is shared
and background load/frequency are uncontrolled. Baseline always ran first;
there was no randomization or repeated paired trial. No custom modification
hook runs in this fixture, so it measures the guard's ordinary-path cost and
cannot characterize arbitrary hook overhead. This is not native-popup,
Emacs 31.1/macOS, GUI or human-use evidence.

## Reproduce and audit

On each clean source revision, use the same Emacs/runtime and fixture:

```sh
EMACS=/path/to/emacs python3 bench/run.py --timeout 120 --load-mode bytecode \
  --sizes 100 10000 --samples 30 --warmup 5 --kinds filter-list \
  --label render-hooks-pair --output /tmp/render-hooks.json
```

The benchmark sends native alternating insertion/deletion, validates result
counts, and acknowledges only after forced redisplay. Compilation/setup are
outside the command clocks. The original reports preserve their actual labels,
local source identities and generated temporary paths; they are not rewritten.

```sh
python3 bench/results/2026-10-29-render-hooks/audit.py
```

The auditor checks all records, sequence/warmup/command/result counts, matching
host and fixtures, the intended single-library change, and recomputes all
pooled and per-command metrics using the hash-verified benchmark implementation.
It is a report consistency check, not independent proof of screen paint.

Assisted-by: OpenAI Codex. Independent coding-agent review is recorded on the
publication PR; no human performance review is asserted.
