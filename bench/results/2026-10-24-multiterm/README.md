# Multi-term filtering: one search projection per item

Measured 2026-10-24. This is one sequential before/after pair on one Linux
Emacs 29.3 configuration using freshly bytecompiled libraries, ordinary windows
and a real native-key/PTY protocol. It is not a universal latency claim.

## Workload and provenance

The editable field starts with `row 日本語 ` (two terms matching every fixture
row). Native `x` insertion adds a third term and retains 10% of rows; DEL
removes that term and restores all rows while keeping the two initial terms.
The initial prefix setup is outside measurement; point is at the end. Both
setup and every acknowledged result count are asserted. This differs from the
earlier one-term/empty-query profile; do not compare their absolute times as an
optimization pair.

Before uses the five library sources from
[`1a0616c87f717a6ee14d02a7d238f1a33cf19712`](https://github.com/vv111y/emacs-tui/tree/1a0616c87f717a6ee14d02a7d238f1a33cf19712).
After changes only `emacs-tui.el`: escape literal patterns once per query and
prepare each item's searchable label/full column values once per search.
No persistent search cache is introduced. Both runs use identical benchmark
scripts from this change; their SHA256 hashes and all five library hashes are
in [before.json](before.json) and [after.json](after.json). Local measurement
copies are untracked, so their Git revision is honestly null. Actual loaded
bytecode definition paths and artifact hashes are recorded.

Each run has four cases (list/table × 1,000/10,000 rows), 10 warmup and 100
measured native edits per case: 440 retained records per run. Alternation gives
50 measured samples per operation; per-operation p99 is the maximum and is a
weak tail estimate. The repeated sequential pair below ran after local tests
finished, without concurrent local validation workloads. An earlier pilot pair
was used to validate the fixture, not included in these published results.

## Native input through terminal output

PTY elapsed milliseconds, nearest-rank quantiles; includes dispatch, forced
redisplay, instrumentation and transport. It does not measure emulator paint.

| View | Rows | Edit | Before p50 / p95 / p99 ms | After p50 / p95 / p99 ms |
| --- | ---: | --- | ---: | ---: |
| filter-list | 1,000 | DEL | 9.197 / 11.431 / 17.306 | 1.937 / 10.993 / 11.181 |
| filter-list | 1,000 | x | 9.060 / 11.912 / 17.284 | 1.602 / 13.039 / 14.471 |
| filter-table | 1,000 | DEL | 53.491 / 67.141 / 116.623 | 36.614 / 44.241 / 46.999 |
| filter-table | 1,000 | x | 46.603 / 53.898 / 63.160 | 19.873 / 24.616 / 24.877 |
| filter-list | 10,000 | DEL | 84.988 / 104.144 / 108.877 | 60.013 / 98.255 / 110.427 |
| filter-list | 10,000 | x | 59.019 / 74.948 / 79.213 | 40.216 / 54.238 / 59.701 |
| filter-table | 10,000 | DEL | 600.395 / 698.465 / 779.584 | 449.426 / 528.104 / 549.279 |
| filter-table | 10,000 | x | 508.011 / 624.640 / 628.287 | 199.834 / 251.801 / 261.690 |

## Allocation and limitations

Median immediate-command cons-cell deltas for the 10,000-row table (including
instrumentation):

| Edit | Before | After |
| --- | ---: | ---: |
| DEL | 270,320 | 210,310 |
| x | 205,328 | 85,308 |

Other allocation/GC counters and separate Emacs command-through-redisplay
latencies are retained in both raw reports. No background provider is involved.
All rows still render on full-table updates, so large-table DEL remains costly.
The list cases retain roughly the same cons counts; no broad allocation claim
is inferred from their timing change. The 10,000-row list DEL p99 did not
improve (108.877ms to 110.427ms); tail behavior is not uniformly faster.

Host: Linux-6.18.55-x86_64-with-glibc2.39, x86_64,
AMD EPYC 9V74 80-Core Processor, 9 logical CPUs,
Python 3.12.14. PTY/frame 120×40; GC threshold
800,000, percentage 0.1.
Native JIT is off and fixture callbacks remain interpreted. CPU frequency,
shared-host scheduling and thermal conditions are uncontrolled. This pair
provides evidence of reduced projection work and its cost on this workload,
not a cross-platform speed guarantee or proof of tail-latency stability.

## Reproduce

Use the benchmark scripts in this change for both source snapshots (including
when checking out the linked baseline libraries); verify their hashes match
both reports. From each otherwise idle source directory, run:

```sh
EMACS=/path/to/emacs python3 bench/run.py --load-mode bytecode \
  --filter-prefix 'row 日本語 ' --kinds filter-list filter-table \
  --sizes 1000 10000 --samples 100 --warmup 10 --timeout 600 \
  --output /tmp/multiterm.json
```

See [docs/PERFORMANCE.md](../../../docs/PERFORMANCE.md) for clock boundaries
and load-mode verification. Source and fresh-bytecode smoke cases now exercise
both the original empty-prefix workload and these multi-term list/table cases.
