# Native popup movement comparison — 2026-10-27

Paired [run 40463828773](https://github.com/vv111y/emacs-tui/actions/runs/40463828773)
measures PR #54 against its exact main base on each hosted runner. All eight raw
JSON reports are preserved losslessly as gzip; no fields or warmup samples were
removed. The manifest records original ZIP, compressed and raw report SHA-256,
source commits and candidate tree. Run `python3 bench/results/2026-10-27-popup-movement/check.py`
to verify 6,720 records and recompute every aggregate and per-command quantile.

Baseline: `e76da73b8935c6a199bedceb86f6b12f171b3736`.
Candidate CI merge: `e2c990014e4ce339ead3dcb17c8743138b22d9bb`
(tree matches reviewed head `05f72bcb823c18ad4227b9e54b93772a70513ba2`).
Integrated by [PR #54](https://github.com/vv111y/emacs-tui/pull/54) at
`0fd29554674e743f691a6664764f6d7c73f23c2a`.

## Method and limits

Emacs 31.1 native TTY child frames, 120×40 PTY; 100 and 10,000 finite Unicode
rows; 200 measured native-key commands after 10 warmups per case. Navigation
and eight-position movement run in source and bytecode modes. Source and driver
hashes, loaded library paths, compiled hashes and host metadata remain in each
report. Both sides use byte-identical benchmark fixtures; source undo is disabled
in the disposable benchmark buffer. Creation, acceptance and physical screen
paint are not timed. PTY timing includes post-command validation. Command and
final-redisplay clocks overlap and must not be added.

Each host runs source baseline then candidate, followed by bytecode baseline
then candidate. This sequential shared-runner comparison is not randomized or
a universal latency guarantee. GC and scheduling contribute to tails. The fast
path retains rows only while cached geometry is current and fitted content size
is unchanged; resize, margin changes and explicit refresh still render.

Linux: AMD EPYC 9V74, 4 logical CPUs, x86_64 Linux 6.17.0-1022-azure, Python 3.12.3.
macOS: Apple M1 (Virtual), 3 logical CPUs, arm64 macOS 26.6.2, Python 3.15.0.

## Paired PTY observations

Milliseconds, nearest-rank p50 / p95 / p99. Each side has 200 measured samples.

| Host | Mode | Rows | Operation | Baseline | Candidate |
| --- | --- | ---: | --- | --- | --- |
| linux | source | 100 | navigate-popup | 1.545 / 9.322 / 9.652 | 1.329 / 8.950 / 9.363 |
| linux | source | 100 | move-popup | 2.925 / 10.816 / 11.003 | 2.674 / 10.696 / 11.816 |
| linux | source | 10000 | navigate-popup | 1.568 / 9.972 / 11.263 | 1.370 / 9.997 / 11.207 |
| linux | source | 10000 | move-popup | 71.098 / 77.404 / 85.839 | 2.716 / 13.939 / 15.999 |
| linux | bytecode | 100 | navigate-popup | 1.364 / 1.607 / 8.835 | 1.179 / 1.363 / 12.122 |
| linux | bytecode | 100 | move-popup | 2.351 / 9.533 / 10.167 | 2.335 / 11.597 / 12.858 |
| linux | bytecode | 10000 | navigate-popup | 1.397 / 1.517 / 9.626 | 1.173 / 1.320 / 12.697 |
| linux | bytecode | 10000 | move-popup | 39.940 / 44.695 / 47.523 | 2.331 / 11.604 / 13.029 |
| macos | source | 100 | navigate-popup | 0.861 / 6.195 / 6.731 | 0.709 / 6.063 / 6.264 |
| macos | source | 100 | move-popup | 1.691 / 7.390 / 7.687 | 1.477 / 7.033 / 7.253 |
| macos | source | 10000 | navigate-popup | 1.017 / 7.170 / 8.806 | 0.726 / 6.595 / 6.825 |
| macos | source | 10000 | move-popup | 48.725 / 67.695 / 73.865 | 1.502 / 7.679 / 7.875 |
| macos | bytecode | 100 | navigate-popup | 0.960 / 1.290 / 7.179 | 0.624 / 0.885 / 5.758 |
| macos | bytecode | 100 | move-popup | 1.504 / 7.230 / 7.844 | 1.308 / 6.295 / 6.440 |
| macos | bytecode | 10000 | navigate-popup | 0.803 / 1.444 / 6.549 | 0.639 / 0.713 / 6.232 |
| macos | bytecode | 10000 | move-popup | 26.957 / 28.854 / 30.042 | 1.329 / 7.005 / 7.169 |

The 10k bytecode movement medians decrease from 39.940 to 2.331 ms on Linux
and 26.957 to 1.329 ms on macOS in this run. The small-list Linux movement case
does not improve uniformly; use the complete table and tails rather than a
blanket speedup claim. These observations apply to position-only movement,
not completion filtering or full view updates.

## Behavioral gate

Runtime/package run [40463828758](https://github.com/vv111y/emacs-tui/actions/runs/40463828758)
passed all eight jobs on the exact candidate head: 358 ERT, strict compile and
checkdoc, package build/clean installation, compatibility and native TTY tests.
Linux/macOS 31.1 verify retained row text, nonzero scroll and marks over all
eight positions; changed viewport and explicit refresh render; fitting failure
disposes the captured child, buffer and markers exactly once. The earlier
horizontal-scroll fixture precondition failure was fixed, then rerun successfully.
Both comparison jobs passed. Separate coding-agent review covers the exact head.
Fixed beta refs remain unchanged. This does not establish maturity or MELPA acceptance.
