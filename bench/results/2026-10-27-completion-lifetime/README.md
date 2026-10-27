# Completion snapshot lifetime comparison — 2026-10-27

[PR #60](https://github.com/vv111y/emacs-tui/pull/60) releases the copied full
candidate snapshot after popup publication. It retains the snapshot through
decoration/display callbacks and recomputes candidates for acceptance.
This reduces object lifetime, not initial candidate allocation or provider caches.

[Paired run 40487652908](https://github.com/vv111y/emacs-tui/actions/runs/40487652908)
retains 16 lossless reports: 6,720 records including all warmups and fields.
The manifest records original artifact digests, raw/compressed report hashes,
source hashes and measured commits. Candidate merge tree matches reviewed
head `9f1e6611311633a07168d6e0a206c539111d339e`.
Baseline: `99676a80786716abfa5242fbfebee53d411734c6`.
Measured candidate: `c48d4f6127afec64633855f203d47a0d679cda3e`.

Run `python3 bench/results/2026-10-27-completion-lifetime/check.py` to audit
digests, every quantile, stage calls, sample sequence and paired environment.
All eight measured source hashes were checked against the corresponding git trees.

PR #60 integrated at `db8bfd9b2d2cf5cb0d3e8d09d8921de00ff53ec4` after
independent review 5665491072, all eight runtime/package jobs in
[CI 40487652957](https://github.com/vv111y/emacs-tui/actions/runs/40487652957)
and all four paired jobs passed. The measured/reviewed tree is
`d391d587a2f354410728dabb900ebae9fe8f4871`. The initial Emacs 28 GC-test
failure was fixed by isolating the fixture's stack references in a joined
thread; the zero-key assertion and its old-code failure remain. No failing
job was waived. The paired fixture uses no worker threads.

## Method and limits

Emacs 31.1 native TTY child frames, 120×40 PTY, 100/10,000 finite Unicode rows.
Each case has 200 native-key commands after 10 warmups: 100 insertions narrow
to one tenth of the matches; 100 deletions restore all matches. Display cap: 200.
Each OS/sorter job runs source baseline then candidate, then bytecode baseline
then candidate, using identical fixtures on the same runner. Sorter jobs are
independent and are not a controlled comparison of sorting policies.
Sequential runs are not randomized, and shared-host scheduling affects tails.

GC defaults are unchanged (800000 bytes, .1 fraction). Advice/counter clocks
add timing and allocation overhead; native matching lies inside projection.
Do not sum overlapping stage clocks or subtract independently summarized medians.
PTY latency includes validation/transport; creation, acceptance and physical
paint are not timed. Source undo is disabled. All allocation, GC, stage, host
and loaded-library provenance remains in the raw reports.

## Paired latency observations

Milliseconds, nearest-rank p50 / p95 / p99. Each row uses 100 samples per side.
Both modes and sizes are shown, including regressions; no blanket speedup is claimed.

| Host | Sorter | Mode | Rows | Edit | Baseline PTY | Candidate PTY |
| --- | --- | --- | ---: | --- | --- | --- |
| linux | identity | source | 100 | insert | 2.878 / 10.014 / 10.186 | 2.894 / 9.687 / 9.895 |
| linux | identity | source | 100 | delete | 11.334 / 18.374 / 18.987 | 11.283 / 18.182 / 19.434 |
| linux | identity | source | 10000 | insert | 40.524 / 42.171 / 42.779 | 38.509 / 45.097 / 46.014 |
| linux | identity | source | 10000 | delete | 132.289 / 135.688 / 136.645 | 137.087 / 149.673 / 155.240 |
| linux | identity | bytecode | 100 | insert | 2.367 / 9.626 / 10.551 | 2.375 / 9.454 / 9.840 |
| linux | identity | bytecode | 100 | delete | 9.010 / 10.513 / 11.039 | 9.151 / 10.430 / 10.603 |
| linux | identity | bytecode | 10000 | insert | 33.457 / 41.225 / 48.093 | 31.423 / 36.514 / 38.419 |
| linux | identity | bytecode | 10000 | delete | 120.551 / 132.118 / 135.203 | 119.620 / 133.743 / 141.249 |
| linux | none | source | 100 | insert | 2.893 / 10.258 / 11.598 | 2.902 / 10.394 / 11.347 |
| linux | none | source | 100 | delete | 11.537 / 18.622 / 19.948 | 11.456 / 18.370 / 19.416 |
| linux | none | source | 10000 | insert | 32.405 / 40.570 / 44.368 | 30.268 / 35.922 / 40.510 |
| linux | none | source | 10000 | delete | 105.449 / 129.788 / 141.542 | 103.969 / 123.440 / 138.263 |
| linux | none | bytecode | 100 | insert | 2.340 / 8.812 / 9.603 | 2.348 / 9.429 / 10.096 |
| linux | none | bytecode | 100 | delete | 9.029 / 11.552 / 12.036 | 8.893 / 10.711 / 11.225 |
| linux | none | bytecode | 10000 | insert | 27.697 / 34.069 / 35.705 | 28.844 / 36.689 / 40.532 |
| linux | none | bytecode | 10000 | delete | 86.261 / 92.151 / 100.027 | 88.060 / 103.064 / 106.148 |
| macos | identity | source | 100 | insert | 5.264 / 18.327 / 27.271 | 4.513 / 16.460 / 23.470 |
| macos | identity | source | 100 | delete | 19.621 / 32.465 / 36.659 | 16.811 / 33.549 / 43.147 |
| macos | identity | source | 10000 | insert | 57.285 / 90.680 / 124.281 | 49.724 / 71.118 / 79.535 |
| macos | identity | source | 10000 | delete | 197.149 / 292.654 / 459.855 | 179.875 / 210.698 / 255.189 |
| macos | identity | bytecode | 100 | insert | 2.656 / 11.779 / 18.876 | 2.662 / 11.814 / 14.823 |
| macos | identity | bytecode | 100 | delete | 9.752 / 13.140 / 16.031 | 9.760 / 15.170 / 17.470 |
| macos | identity | bytecode | 10000 | insert | 44.525 / 64.194 / 84.802 | 42.502 / 57.814 / 68.504 |
| macos | identity | bytecode | 10000 | delete | 163.923 / 213.167 / 254.531 | 168.961 / 264.083 / 306.593 |
| macos | none | source | 100 | insert | 6.124 / 20.429 / 24.497 | 9.373 / 25.446 / 90.192 |
| macos | none | source | 100 | delete | 20.641 / 35.384 / 38.845 | 23.891 / 52.583 / 160.368 |
| macos | none | source | 10000 | insert | 51.879 / 97.987 / 173.497 | 39.380 / 60.492 / 62.012 |
| macos | none | source | 10000 | delete | 171.631 / 352.875 / 442.516 | 141.078 / 182.954 / 214.433 |
| macos | none | bytecode | 100 | insert | 3.910 / 16.450 / 27.572 | 3.793 / 17.971 / 25.852 |
| macos | none | bytecode | 100 | delete | 11.746 / 21.828 / 23.347 | 12.319 / 20.608 / 23.789 |
| macos | none | bytecode | 10000 | insert | 37.893 / 50.630 / 64.734 | 33.540 / 55.204 / 66.291 |
| macos | none | bytecode | 10000 | delete | 109.753 / 150.280 / 163.469 | 108.185 / 155.394 / 223.153 |

The weak-key regression establishes snapshot collectibility while the popup
remains live. These hosted measurements do not establish a uniform latency
improvement or remove the previously measured native matching/allocation costs.

## Hosts

- linux, identity: `{"logical_cpus": 4, "machine": "x86_64", "processor": "AMD EPYC 9V74 80-Core Processor", "python": "3.12.3", "system": "Linux-6.17.0-1022-azure-x86_64-with-glibc2.39"}`
- linux, none: `{"logical_cpus": 4, "machine": "x86_64", "processor": "AMD EPYC 9V74 80-Core Processor", "python": "3.12.3", "system": "Linux-6.17.0-1022-azure-x86_64-with-glibc2.39"}`
- macos, identity: `{"logical_cpus": 3, "machine": "arm64", "processor": "Apple M1 (Virtual)", "python": "3.15.0", "system": "macOS-26.6.2-arm64-arm-64bit-Mach-O"}`
- macos, none: `{"logical_cpus": 3, "machine": "arm64", "processor": "Apple M1 (Virtual)", "python": "3.15.0", "system": "macOS-26.6.2-arm64-arm-64bit-Mach-O"}`

This is experimental beta evidence, not a maturity or MELPA acceptance claim.
