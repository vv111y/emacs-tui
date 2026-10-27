# Native completion stages — 2026-10-27

[Run 40477529516](https://github.com/vv111y/emacs-tui/actions/runs/40477529516)
profiles the reviewed PR #58 implementation with opt-in instrumentation.
All eight raw reports are preserved losslessly, including every field and warmup:
15,120 records. The manifest records original ZIP digests, compressed/raw report
hashes and all eight measured input hashes. Those input hashes were checked
against measured commit `47313d05aaaa8e9bd7091a5efd27be6e8586568c`,
tree `71a2b90bbaa35b89ee8bc3394a68238866e7df48`, matching reviewed
head `19ae46168d2232d013e56e20dc03042003b68c5d`.

Run `python3 bench/results/2026-10-27-completion-stages/check.py` to verify hashes,
record order, stage calls, inclusive nesting and every aggregate/per-command
nearest-rank quantile. Original profile artifacts are retained for 90 days.

## Workload and interpretation

Emacs 31.1 native TTY child frames, 120×40 PTY, 100/1,000/10,000 finite Unicode
rows; 200 measured commands and 10 warmups per case. Native `x` insertion narrows
to one tenth of the rows; deletion restores all rows, with a 200-row display cap.
Both identity and absent display sorters run in source and bytecode modes.
Each sorter/platform combination is a separate hosted job; source precedes
bytecode within that job. They are current profiles, not paired before/after
measurements or controlled sorter comparisons. Do not infer a speedup by
subtracting medians across these independently scheduled jobs.

Instrumentation adds advice, clock/counter and allocation overhead. Stage times
include GC and scheduling. Native matching is inside projection; table callback
time overlaps those stages. Do not add overlapping times, or add separate
medians as though they describe one command. Projection includes metadata,
native matching, copies, deduplication and boundaries. Decoration includes
sorting, copying, affixation and validation. Publication is the existing-popup
update. PTY timing additionally includes post-command validation and transport.
Startup, popup creation/acceptance and physical screen paint are not timed.
Undo is disabled in the disposable source buffer. Raw reports retain allocation,
GC, loaded-library, compiled-hash, host and runtime provenance.

## Ten-thousand-row bytecode observations

Milliseconds. PTY is p50 / p95 / p99; stage columns are individual p50 values.
Deletion and insertion each have 100 measured samples per report.

| Host | Sorter | Edit | PTY | Projection | Native matching | Decoration | Publication | Table |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| linux | identity | delete-backward-char | 146.636 / 150.996 / 156.037 | 93.003 | 51.806 | 49.961 | 0.423 | 0.318 |
| linux | identity | self-insert-command | 46.713 / 48.012 / 49.413 | 11.478 | 11.176 | 10.351 | 9.805 | 0.307 |
| linux | none | delete-backward-char | 104.830 / 108.270 / 122.246 | 90.859 | 46.492 | 0.625 | 0.407 | 0.278 |
| linux | none | self-insert-command | 32.459 / 40.866 / 42.072 | 9.647 | 9.329 | 8.958 | 0.367 | 0.260 |
| macos | identity | delete-backward-char | 160.051 / 220.261 / 350.281 | 103.372 | 54.082 | 47.958 | 0.395 | 0.229 |
| macos | identity | self-insert-command | 47.857 / 71.245 / 81.503 | 11.460 | 11.103 | 10.233 | 9.716 | 0.224 |
| macos | none | delete-backward-char | 93.746 / 109.239 / 120.185 | 80.081 | 41.325 | 0.488 | 0.358 | 0.194 |
| macos | none | self-insert-command | 30.882 / 40.232 / 42.051 | 8.667 | 8.303 | 7.450 | 0.366 | 0.191 |

These profiles identify projection/native matching as substantial restoration
costs; they do not justify attributing the entire delay to popup rendering or
the application table. Some stages have GC-sensitive tails: consult the raw
per-command quantiles and GC records before selecting an optimization.

## Host inventory

- linux, identity: `{"logical_cpus": 4, "machine": "x86_64", "processor": "AMD EPYC 7763 64-Core Processor", "python": "3.12.3", "system": "Linux-6.17.0-1022-azure-x86_64-with-glibc2.39"}`
- linux, none: `{"logical_cpus": 4, "machine": "x86_64", "processor": "INTEL(R) XEON(R) PLATINUM 8573C", "python": "3.12.3", "system": "Linux-6.17.0-1022-azure-x86_64-with-glibc2.39"}`
- macos, identity: `{"logical_cpus": 3, "machine": "arm64", "processor": "Apple M1 (Virtual)", "python": "3.15.0", "system": "macOS-26.6.2-arm64-arm-64bit-Mach-O"}`
- macos, none: `{"logical_cpus": 3, "machine": "arm64", "processor": "Apple M1 (Virtual)", "python": "3.15.0", "system": "macOS-26.6.2-arm64-arm-64bit-Mach-O"}`

No package maturity, universal latency guarantee, human review or MELPA
acceptance is established by this evidence.
