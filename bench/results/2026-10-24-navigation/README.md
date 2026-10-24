# Navigation baseline, 2026-10-24

This is one paired interpreted-source run, not a general speed guarantee.
Both runs used Emacs 29.3 on Linux x86_64, AMD EPYC 9V74 (9 logical CPUs exposed),
Python 3.12.14, ordinary windows, xterm-256color, a 120x40 PTY and an actual
120x39 Emacs frame. GC remained 800,000 bytes / 0.1; deferred native compilation
was disabled. The extracted local runtime also disables native compiler
trampoline generation. Host scheduling, virtualization and CPU frequency are
uncontrolled. No functional tests or other benchmarks ran during either run.

The before sources match main at `ee7066847518c36c639b76ad6d9bac5ac977fdb1`;
after sources match reviewed implementation `aefc7aa1f152e3a2d4124d04f989b20672c9044e`.
Files were compared with the remote commits. These local source copies were
untracked, so their reported Git revision/dirty state remains null. Hashes are
authoritative: only emacs-tui.el differs; both benchmark scripts and all other
libraries are identical. Both runs loaded .el sources after `make clean`.

Reproduce with each corresponding source tree:

```sh
make clean benchmark BENCH_ARGS='--sizes 1000 10000 --kinds navigate-list navigate-table --samples 100 --warmup 10'
```

Each workload has 10 warmups then 100 measured native `n` commands, including
scrolling. Percentiles use nearest rank; p99 from 100 samples is weak tail
evidence. Timings include instrumentation. Selection/display behavior is also
covered by functional tests; the benchmark checks selected identities.

## Keyboard to terminal-output latency (milliseconds)

| View | Rows | Before p50 / p95 / p99 | After p50 / p95 / p99 |
| --- | ---: | ---: | ---: |
| navigate-list | 1,000 | 2.561 / 14.634 / 17.386 | 0.339 / 0.555 / 0.706 |
| navigate-table | 1,000 | 149.670 / 193.238 / 233.609 | 0.425 / 0.685 / 1.035 |
| navigate-list | 10,000 | 66.666 / 89.210 / 108.846 | 0.432 / 0.685 / 0.824 |
| navigate-table | 10,000 | 1465.987 / 1622.462 / 1683.763 | 0.544 / 0.826 / 1.194 |

## Immediate command allocations (median cons cells)

| View | Rows | Before | After |
| --- | ---: | ---: | ---: |
| navigate-list | 1,000 | 7,447 | 232 |
| navigate-table | 1,000 | 483,939 | 232 |
| navigate-list | 10,000 | 70,451 | 232 |
| navigate-table | 10,000 | 4,831,043 | 232 |

The measured bottleneck was reprojecting/reformatting and replacing every row
on each selection movement. Cached row bounds and a selection overlay remove
that work without virtualizing the native buffer. Source, filter, sort, mark
and tree projection updates still rebuild contents; their latency is outside
this comparison. Compiled/native-code performance, child frames, GUI paint,
real emulators, other hosts and sustained application use remain unmeasured.

[before.json](before.json) and [after.json](after.json) retain environment,
source hashes and all summary metrics. Their raw records are exported to
[before.csv](before.csv) and [after.csv](after.csv), including warmups. Metadata
records the CSV SHA256 and row count. CSV fields retain the run report names;
warmup is `true`/`false`, indices/counters are integers and times are milliseconds.
The export only separates raw records from metadata; it does not drop samples
or recompute/round the stored values. The table above rounds to three decimals.
See [methodology](../../../docs/PERFORMANCE.md) for timing boundaries, allocation
counter scope, provider-stage separation and limitations. The published pair
covers navigation only; five-workload CI smoke is functional evidence.
