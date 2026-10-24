# Native query clearing, 2026-10-24

One interpreted-source pair on the same Emacs 29.3/Linux x86_64 host (AMD EPYC
9V74, 9 logical CPUs exposed, Python 3.12.14), ordinary windows and xterm-256color.
The requested PTY was 120x40; Emacs reported 120x39. GC remained 800,000 / 0.1.
Deferred native compilation and local runtime compiler trampolines were disabled.
Scheduling, virtualization and CPU frequency are uncontrolled. No functional
tests or other benchmarks ran during either measurement.

Before library/benchmark source hashes match main at
`2215a195153515cb55f8c02cf5397c814bab9275`; after hashes match reviewed
implementation `330c15a1e87b0956d60cf8d88b7d9bb592e81d21`. Local copies were
untracked, so Git revision/dirty state remains null. The source fingerprints are
authoritative. Only emacs-tui.el differs; the two benchmark scripts and all
other libraries are identical. Both runs loaded .el files after `make clean`.

Reproduce with each source tree:

```sh
make clean benchmark BENCH_ARGS='--sizes 1000 10000 --kinds filter-list filter-table --samples 100 --warmup 10'
```

Each workload alternates native `x` insertion (10% matching rows) and DEL
(clears the query and restores all rows). After 10 warmups, 100 commands yield
**50 measurements per operation**. The optimization only skips the predicate
pass when there are no terms. Rendering all restored rows still occurs.
Nonempty queries still perform full matching; their data is retained too.

## DEL: keyboard to terminal-output latency, milliseconds

| View | Rows | Before p50 / p95 / p99 | After p50 / p95 / p99 |
| --- | ---: | ---: | ---: |
| filter-list | 1,000 | 61.311 / 76.553 / 88.650 | 2.569 / 12.451 / 14.515 |
| filter-table | 1,000 | 190.013 / 253.196 / 304.922 | 137.063 / 154.552 / 195.922 |
| filter-list | 10,000 | 654.340 / 740.079 / 753.666 | 61.093 / 76.158 / 86.183 |
| filter-table | 10,000 | 2223.731 / 2607.576 / 2738.148 | 1604.862 / 1870.849 / 1912.249 |

## DEL: median immediate command cons cells

| View | Rows | Before | After |
| --- | ---: | ---: | ---: |
| filter-list | 1,000 | 242,887 | 9,462 |
| filter-table | 1,000 | 719,364 | 485,941 |
| filter-list | 10,000 | 2,420,932 | 90,466 |
| filter-table | 10,000 | 7,181,510 | 4,851,044 |

Counters include instrumentation. These are allocations, not retained memory.
Percentiles use nearest rank; with 50 samples p99 is the maximum, not a robust
tail bound. This pair does not establish compiled/native-code performance or
emulator/physical paint latency. Nonempty matching and full table rendering
remain substantial costs; further optimization needs separate measurement.

[before.json](before.json) and [after.json](after.json) retain environment,
hashes and pooled/per-command summaries. [before.csv](before.csv) and
[after.csv](after.csv) retain every warmup/measured record, with metadata CSV
SHA256/counts. Warmup is `true`/`false`; indices/counters are integers and times
are milliseconds. Export preserves raw values; only this table rounds them.
See the [methodology](../../../docs/PERFORMANCE.md) and
[earlier navigation pair](../2026-10-24-navigation/README.md).
