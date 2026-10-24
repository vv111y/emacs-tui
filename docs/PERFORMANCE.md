# Reproducing latency measurements

The first [published navigation pair](../bench/results/2026-10-24-navigation/README.md)
includes environment/provenance, raw samples, p50/p95/p99 and allocation counters
before/after removing row reconstruction from selection movement. It covers
interpreted Emacs 29.3 and ordinary windows on one host, not universal latency.

Run `make clean benchmark` with Python 3 and a real terminal-capable Emacs.
The driver creates its own 120x40 PTY and starts `emacs -Q -nw`; it does not
use your current Emacs session. Results, including every warmup and measured
sample, are written to `.cache/benchmark.json`. For a smaller run:

```sh
make clean benchmark BENCH_ARGS='--sizes 100 1000 --samples 100 --warmup 10'
```

Set `EMACS=/path/to/emacs` to select a runtime. `BENCH_ARGS` can also select
`--kinds navigate-list navigate-table`, `--output FILE`, and an explanatory
`--label`. Library bytecode is rejected so stale compiled files cannot silently
change the workload. These are interpreted-source measurements. Deferred native
compilation is disabled in the fixture. Normal GC thresholds are retained and
recorded; fixture setup runs GC before each workload, outside measured samples.

## Workloads and clocks

Each size (100, 1,000 and 10,000 rows by default) exercises:

| Workload | Native keyboard operation | Result |
| --- | --- | --- |
| `navigate-list` | Repeated `n` | Move selection, including scrolling and wraparound |
| `navigate-table` | Repeated `n` | Same, with two fixed-width projected columns |
| `filter-list` | Alternate `x` and DEL in an editable field | Callback locally filters the other view to 10% of rows, then restores all rows |
| `filter-table` | Same native edits | Same filtering over two columns |
| `provider-list` | Alternate `x` and DEL in an ephemeral query | 10ms debounce, provider with a deliberate 20ms timer, then replacement results |

Data has stable identities, numeric metadata, Japanese text and a combining
accent. The backend is explicitly ordinary windows to permit comparisons across
the supported Emacs versions. Native child-frame latency needs a separate run
design; this fixture makes no claim about it. Filtering views use two columns
of windows; the provider uses the ephemeral query field above one result view.

The Python driver sends exactly one key and waits for an acknowledgement before
sending the next. The marker is written to the PTY **after** `redisplay t`.
It validates case/sample sequence and Emacs checks selected identities or
visible result counts, so a silently unbound key or failed filter cannot pass.

The driver starts a new session using `start_new_session`, then attaches the
controlling PTY in a fresh Python interpreter before executing Emacs. It does
not run Python via `preexec_fn` after fork. Stage messages are flushed outside
measured commands. This addresses a process-launch hazard while retaining the
same native key/redisplay protocol. Repeated macOS 31.1 CI stalls in the older
driver were not captured with a stack trace, so the exact blocked call is
unknown; successful checks must verify this change rather than assuming a cause.

`--timeout SECONDS` covers the entire driver (default 1,800 seconds). Expiry
dumps the Python stack and fails the run; normal cleanup kills its owned process
group and waits at most five seconds. A C watchdog dumps/exits after ten extra
seconds if Python cannot dispatch the deadline. Git and CPU-model subprocesses
have ten-second limits. Unavailable Git/CPU metadata is recorded as null.
CI smoke uses a 120-second driver deadline, a five-minute outer step limit and
a 15-minute runtime-job limit, including compilation and startup. None of these
limits are performance thresholds. Published earlier pairs retain their original
versioned coordinator hashes; this hardening does not rewrite their data.

- `pty_output_ms`: Python's monotonic clock, just before writing the key through
  receipt of the acknowledgement after terminal output. Includes dispatch,
  scheduling, instrumentation, validation and PTY transport. For the provider
  case, this waits for **result** output, including debounce and provider delay.
- `command_redisplay_ms`: Emacs pre-command hook through forced redisplay in the
  post-command hook. Excludes input decoding/queueing and acknowledgement
  transport. For providers this covers immediate query/clearing display only.
- `provider_wait_ms`: Provider invocation through its timer callback, including
  the deliberately configured delay and scheduling. Not a real data-source
  benchmark and not renderer time.
- `provider_publish_redisplay_ms`: Provider callback's publishing and redisplay.
- `command_to_result_ms`: Emacs command start through result redisplay, including
  debounce, controlled provider delay and publishing.
- `cons_cells`, `string_chars`, `gc_count`, `gc_ms`: cumulative counter deltas
  over the immediate command/redisplay interval, including instrumentation.
  These are allocations, not retained heap or total bytes. Provider publishing
  occurs later and is outside these command allocation/GC counters.

This measures terminal **output**, not terminal-emulator parsing, compositor
latency, physical screen paint or human-perceived latency. There is no emulator
in this PTY fixture. Emacs elapsed clocks and Python's monotonic clock are never
subtracted from one another. Emacs timings use its elapsed wall clock, so clock
adjustments are an additional reason to retain raw data and repeat runs.

## Interpreting results

The report includes raw records, all-row/filtered-row counts, aggregate and
per-command p50/p95/p99 using nearest rank, sample counts, runtime/features,
backend, actual frame geometry, requested PTY geometry, GC settings, host/CPU,
library/benchmark source hashes and tracked Git revision/dirty state when available. Untracked
local copies report a null Git revision rather than inventing provenance.

Defaults use 10 warmups then 100 measured commands per workload. Alternating
filter/provider cases have 50 samples per command; their per-command p99 is the
maximum and is statistically weak. Use more samples for tail analysis. Repeat
before/after runs on the same otherwise idle host. CPU frequency, virtualization,
thermal state and background work are not controlled. These numbers are evidence
for finding bottlenecks, not universal performance promises.

`make clean benchmark-smoke` checks compilation, all five workloads, real native
input and the acknowledgement protocol with six samples and two warmups at
100 rows. CI runs this on each supported runtime; it has **no timing threshold**
and is not a published performance baseline. Required functional ERT/PTY tests
remain separate. Optimize only after measuring, and preserve native buffer
semantics, source identity, application effects and failure-safe updates.
