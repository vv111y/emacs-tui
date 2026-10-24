# Fresh-bytecode profile, 2026-10-24

One current-state profile on Emacs 29.3/Linux x86_64, AMD EPYC 9V74 (9 logical
CPUs exposed), Python 3.12.14, ordinary windows and xterm-256color. Requested PTY
120x40; actual Emacs frame 120x39. GC remained 800,000/0.1. Libraries were freshly
bytecompiled in an isolated copy with the selected runtime; all five actual
loaded definition paths/types were verified. The benchmark fixture and callbacks
remained interpreted. Deferred native compilation and local compiler trampolines
were disabled. This measures terminal output; emulator/physical paint, native
compilation, other runtimes and sustained application usage remain unmeasured.
Host scheduling, virtualization and CPU frequency are uncontrolled.

Source/benchmark hashes match reviewed implementation
`8f3718defd561238a46c13bb7df3601044838fae`. Local source copies were untracked,
so their Git revision/dirty fields remain null. Source hashes are authoritative;
metadata also records exact bytecode hashes and loaded-file paths. No functional
tests or other benchmarks ran concurrently with this profile.

Reproduce with that source tree:

```sh
make benchmark BENCH_ARGS='--load-mode bytecode --sizes 1000 10000 --samples 100 --warmup 10'
```

Each workload has 10 warmups then 100 measured commands. Navigation has 100 samples
per operation; alternating filtering/provider cases have 50 per operation. Nearest
rank is used; with 50 samples p99 is the maximum and weak tail evidence. All
raw values are retained; the tables round to three decimals. This is a current
profile, not a before/after compiled-code comparison. Historical source-mode
pairs are separate experiments with their own versioned coordinators.

## Keyboard to terminal-output latency, milliseconds

| Workload | Rows | Native command | Samples | p50 / p95 / p99 |
| --- | ---: | --- | ---: | ---: |
| navigate-list | 1,000 | n | 100 | 0.355 / 0.547 / 0.632 |
| navigate-table | 1,000 | n | 100 | 0.425 / 0.704 / 0.829 |
| filter-list | 1,000 | DEL | 50 | 0.841 / 11.594 / 12.869 |
| filter-list | 1,000 | insert x | 50 | 1.446 / 12.159 / 12.463 |
| filter-table | 1,000 | DEL | 50 | 34.933 / 49.536 / 52.028 |
| filter-table | 1,000 | insert x | 50 | 14.770 / 19.849 / 25.502 |
| navigate-list | 10,000 | n | 100 | 0.452 / 0.623 / 0.722 |
| navigate-table | 10,000 | n | 100 | 0.546 / 0.789 / 0.849 |
| filter-list | 10,000 | DEL | 50 | 32.483 / 44.590 / 49.320 |
| filter-list | 10,000 | insert x | 50 | 48.017 / 63.220 / 69.479 |
| filter-table | 10,000 | DEL | 50 | 272.447 / 320.990 / 333.227 |
| filter-table | 10,000 | insert x | 50 | 205.160 / 239.170 / 248.052 |

## Controlled provider stages

The fixture requests 10ms debounce and 20ms timer delay, with no external I/O.
PTY time waits for result output. Provider waiting and publish/redisplay remain
separate from immediate query-command timing; this is not a real data-source
latency measurement.

| Rows | Native command | Samples | PTY p50 / p95 / p99 | Provider wait p50 | Publish/redisplay p50 |
| ---: | --- | ---: | ---: | ---: | ---: |
| 1,000 | DEL | 50 | 31.988 / 45.298 / 63.751 | 20.214 | 1.315 |
| 1,000 | insert x | 50 | 31.259 / 42.793 / 43.005 | 20.221 | 0.622 |
| 10,000 | DEL | 50 | 67.086 / 78.068 / 84.568 | 20.162 | 36.336 |
| 10,000 | insert x | 50 | 32.679 / 44.623 / 50.507 | 20.164 | 1.207 |

The profile keeps navigation below 1ms median for these workloads, while full
table rendering and nonempty matching remain candidates for further measured
work. Source/query/sort/mark/tree updates still rebuild contents. These data do
not define a universal latency target or a cross-machine performance promise.

[run.json](run.json) retains environment, mode/provenance, pooled/per-command
metrics and immediate command GC/allocation counters. [raw.csv](raw.csv) retains
all 1,100 records including warmups; metadata records CSV SHA256/count. Provider
columns are blank for non-provider rows (absent, not zero). Warmup is true/false,
indices/counters are integers and times are milliseconds. Counter scope and
clock boundaries are documented in the [methodology](../../../docs/PERFORMANCE.md).
