# Native popup baseline — 2026-10-27

This is the first full native TTY popup profile, collected by
[run 40460297101](https://github.com/vv111y/emacs-tui/actions/runs/40460297101).
It is a baseline for locating expensive work, not an optimization comparison
or a universal latency promise. Source revision, tree, artifact identities
and archive/report SHA256 digests are in [manifest.json](manifest.json).

Each report retains all 1,890 warmup/measured records: three workloads at
100/1,000/10,000 source rows, 10 warmups and 200 measured commands per case.
Alternating completion input has 100 measured samples per individual command.
All stored aggregate and per-command nearest-rank quantiles were independently
recomputed from raw records. Downloaded ZIP digests match GitHub's artifact
digests; all library/fixture hashes match the reviewed measured tree. Reports
are losslessly gzip-compressed without removing any sample/environment field.

- Linux: Emacs 31.1, x86_64, AMD EPYC 9V74 (4 logical CPUs exposed),
  Linux 6.17.0-1022-azure, Python 3.12.3.
- macOS: Emacs 31.1, arm64, Apple M1 Virtual (3 logical CPUs exposed),
  macOS 26.6.2, Python 3.15.0.
- Each host ran source and freshly bytecompiled modes sequentially. Shared
  virtual runners have uncontrolled scheduling and CPU frequency. Fixture
  instrumentation stays interpreted; native JIT is disabled.
- A 120×40 PTY uses native child frames, typed keys, terminal-output paint proof,
  host ownership/cursor checks and exact capped-candidate assertions. There is
  no physical terminal, emulator compositor, GUI or multiplexer here.
- Completion uses a synchronous finite string table, basic style and a 200-row
  display-only cap. Source undo recording is disabled. Initial creation/CAPF
  dispatch are outside timing. This does not estimate filesystem/LSP services.

## 10,000-row observations

Times are milliseconds. PTY includes validation, scheduling and transport;
command ends after forced redisplay but before host assertions. Table callbacks
are a subinterval of command time, not a separate additive cost.
See [clock definitions](../../../docs/PERFORMANCE.md#native-floating-popup-and-completion-workloads).

| Host | Libraries | Command | Samples | PTY p50/p95/p99 | Command p50/p95/p99 | Table p50 |
| --- | --- | --- | ---: | --- | --- | ---: |
| linux | source | Navigate | 200 | 1.507/12.154/12.726 | 1.008/1.155/12.068 | 0.000 |
| linux | source | Move | 200 | 78.919/91.990/95.635 | 78.424/91.437/95.107 | 0.000 |
| linux | source | Delete x | 100 | 174.000/186.724/195.329 | 173.330/186.208/194.847 | 0.315 |
| linux | source | Type x | 100 | 53.429/58.214/65.983 | 49.919/54.684/62.846 | 0.307 |
| linux | bytecode | Navigate | 200 | 1.326/1.442/11.994 | 0.873/0.977/11.375 | 0.000 |
| linux | bytecode | Move | 200 | 42.147/44.075/50.183 | 41.667/43.477/49.669 | 0.000 |
| linux | bytecode | Delete x | 100 | 155.877/161.443/168.856 | 155.382/160.989/168.344 | 0.316 |
| linux | bytecode | Type x | 100 | 36.363/38.645/41.884 | 24.226/24.946/28.027 | 0.308 |
| macos | source | Navigate | 200 | 0.941/7.621/8.156 | 0.633/0.746/7.745 | 0.000 |
| macos | source | Move | 200 | 55.921/64.562/70.507 | 55.559/64.053/70.038 | 0.000 |
| macos | source | Delete x | 100 | 130.849/156.291/168.611 | 130.384/155.985/168.279 | 0.181 |
| macos | source | Type x | 100 | 39.544/46.003/49.366 | 34.881/43.153/44.158 | 0.176 |
| macos | bytecode | Navigate | 200 | 0.976/1.898/8.559 | 0.663/1.226/7.772 | 0.000 |
| macos | bytecode | Move | 200 | 31.486/36.354/37.167 | 31.145/35.957/36.782 | 0.000 |
| macos | bytecode | Delete x | 100 | 118.627/137.212/147.262 | 118.301/136.786/146.763 | 0.185 |
| macos | bytecode | Type x | 100 | 27.437/31.915/33.615 | 18.166/21.235/22.357 | 0.178 |

Navigation stays inexpensive across these sizes, while compass movement grows
with the result collection. Source inspection shows movement currently invokes
full reflow and reconstructs the view; this is a concrete optimization target,
not yet proof that all measured time belongs to reconstruction. Any fast path
must retain native position updates, selection/scroll, viewport resizing and
ownership/error cleanup.

Deleting x restores the full native completion set and costs substantially more
than narrowing it, even though the displayed result is capped. Timed table
callbacks are a small part of the command interval in this fixture; framework/
projection/UI work needs further attribution. A display cap is not a provider
work bound. Command-minus-table is not pure rendering time.

Compare baseline and candidate on the same runner with identical fixture
hashes before claiming improvements. These observations do not establish
universal platform ratios or improvement from any change.

## Raw reports

- [Linux source](linux-source.json.gz)
- [Linux bytecode](linux-bytecode.json.gz)
- [macOS source](macos-source.json.gz)
- [macOS bytecode](macos-bytecode.json.gz)

Run python3 check.py from this directory to verify retained report digests,
all 7,560 sample records and aggregate/per-command quantiles.

Use gzip -dc to read a report without editing its retained compressed file.
Reports include every size, per-command summaries, source/fresh-bytecode
hashes, loaded definitions, GC settings/counters and raw clocks. The source
revision is the tested PR merge commit, not the later main integration commit;
the reviewed tree is recorded in the manifest.
