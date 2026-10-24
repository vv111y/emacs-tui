# Project state

Updated 2026-10-24 (America/Toronto).

## Active implementation

PR #21 merged at `132b9fe7c45919065b45670ca2142a048e9559f8` after independent
review and all eight final-head jobs in
[40069047213](https://github.com/vv111y/emacs-tui/actions/runs/40069047213).
Both macOS versions now pass the benchmark. Runtime jobs each passed 228 ERT,
strict compilation/checkdoc, six PTY scripts, two Python regressions and all
five benchmark workloads; package build/clean-install also passed. Diagnostic
logs located the earlier failures in post-protocol timed waits on Python 3.15.
The driver now drains PTY output and polls exit status, bounds its lifecycle
and terminates owned descendants. Exact underlying OS causality is not asserted.

PR #20 is being rebased onto that merged fix using an expected-head lease.
Its library change still only skips per-item predicates when there are no
literal search terms; trees retain expansion projection and sorting copies
the source list. The source-order/identity/selection/marks regression is retained.
Local validation of this combination passed 229 ERT tests, strict compilation,
checkdoc, six PTY scripts, both Python regressions and five-workload benchmark
smoke. Fresh independent review and all eight current-head CI jobs gate merge;
the old stalled run/cancelled jobs are not passing evidence.

Reviewed native-input data is under bench/results/2026-10-24-query-clear.
All 440 raw records per run and pooled/per-command summaries remain unchanged.
The historical source/benchmark hashes refer to the exact original experiments,
including their older coordinator. On interpreted Emacs 29.3/Linux,
10,000-row list clearing p50 changed 654.340ms -> 61.093ms; p95/p99 changed
740.079/753.666ms -> 76.158/86.183ms. Median cons cells changed
2,420,932 -> 90,466. Full table clearing still costs 1604.862ms p50 and nonempty
matching remains expensive. Each operation has 50 samples, making p99 the
maximum and weak tail evidence. This is one ordinary-window source-mode pair,
not bytecompiled/native-code or physical-paint performance evidence.

Next: add bytecode benchmark mode on top of the final bounded driver, then
measure compiled costs before further rendering changes. Broaden resource
stress/display validation and continue concrete application capabilities.
Public-history, human-review and actual MELPA acceptance remain external gates.

## Implementation and handoff

This is an experimental development release, not a stable or MELPA package.

Scope clarification from the owner, 2026-10-23: build a general-purpose TUI
toolkit for Emacs. The ephemeral XOB-style workflow is one supported application
pattern. Persistent applications and embedded panels must not require query
input, an origin marker, or commit-then-close. See docs/DESIGN.md and the new
immediate priorities in ROADMAP.md. PR #6 merged the persistent lifecycle and
dashboard. PR #7 added borrowed-window embedding over the same primitives.

- [PR #1](https://github.com/vv111y/emacs-tui/pull/1): merged foundation with
  editable temporary queries, independent list/text views, explicit selection
  and atomic origin-buffer commit, columns/rows/grid, native child frames and
  an ordinary-window fallback.
- [PR #2](https://github.com/vv111y/emacs-tui/pull/2): merged automatic resize
  reflow, state preservation, owned-subtree invalidation and real TTY resizing.
- [PR #3](https://github.com/vv111y/emacs-tui/pull/3): merged debounced async
  providers with cancellation, streaming replacement updates, obsolete callback
  rejection, failure recovery and a chunked buffer-search example.
- [PR #4](https://github.com/vv111y/emacs-tui/pull/4): merged opt-in
  multi-selection, stable identity marks, non-color indicators and explicit
  batch commits. Final-head CI also passed on all four supported test versions.
- [PR #5](https://github.com/vv111y/emacs-tui/pull/5): merged by the owner;
  general-purpose toolkit scope and lifecycle priorities are now on main.
- [PR #6](https://github.com/vv111y/emacs-tui/pull/6): persistent lifecycle,
  dashboard, explicit actions and application cleanup.
- [PR #7](https://github.com/vv111y/emacs-tui/pull/7): borrowed-window embedding
  and host restoration without changing host buffer contents.
- [PR #8](https://github.com/vv111y/emacs-tui/pull/8): composed application/view
  keymaps and a public current-session accessor.
- [PR #9](https://github.com/vv111y/emacs-tui/pull/9): sortable table columns,
  structured dashboard rows and failure-safe updates.
- [PR #10](https://github.com/vv111y/emacs-tui/pull/10): preview reading position
  survives focus changes and unchanged updates.
- [PR #11](https://github.com/vv111y/emacs-tui/pull/11): native editable inputs,
  application change callbacks and a persistent composer with explicit copying.
- [PR #12](https://github.com/vv111y/emacs-tui/pull/12): finite tree views, stable
  expansion/hidden marks, ancestor search context and a buffer-tree application.
- [PR #13](https://github.com/vv111y/emacs-tui/pull/13): maximize/restore and
  per-view hidden reading state, including native background input edits.
- [PR #14](https://github.com/vv111y/emacs-tui/pull/14): required ARM64 macOS
  30.2/31.1 validation alongside the four-version Linux matrix.
- [PR #15](https://github.com/vv111y/emacs-tui/pull/15): independent per-view
  queries and native persistent search composition without replacing sources.
- [PR #16](https://github.com/vv111y/emacs-tui/pull/16): explicit named context
  actions over marks/current objects with native-menu target revalidation.
- [PR #17](https://github.com/vv111y/emacs-tui/pull/17): real candidate-recipe
  builds, clean archive installations and declared-floor Emacs 28.1 CI.
- [PR #18](https://github.com/vv111y/emacs-tui/pull/18): real native-key/PTY
  benchmark with separate command/render/provider stages and source provenance.
- [PR #19](https://github.com/vv111y/emacs-tui/pull/19): cached selection
  navigation with raw measured latency/allocation evidence and edge-case fixes.
- [PR #21](https://github.com/vv111y/emacs-tui/pull/21): bounded benchmark
  lifecycle, PTY exit drainage, diagnostics and descendant cleanup.

API and runnable examples are in README.md. `make demo` explores an in-memory
sample graph; `make async-demo` searches buffer snapshots. Marks are per view
and preserve local filtered-hidden selections. Source replacement prunes absent
identities; async query supersession clears provider-owned results and marks.
The graph demo deliberately filters only nodes so forward/backlinks remain
navigable. Query edits there may prune marks as its source results change.

## Validation

Current evidence is recorded above. Runtime CI covers Linux Emacs 28.1,
28.2, 29.4, 30.2 and 31.1, plus ARM64 macOS 30.2 and 31.1. Each job runs ERT,
strict compilation, checkdoc and six real terminal scripts. Emacs 31.1 uses
native TTY child frames for ephemeral/persistent/input/tree interfaces on both
platforms; earlier versions use windows. Embedded/table scripts borrow a
window. Resize coverage is 120x40 -> 90x30 -> 140x45, including maximize/restore
and explicit action-menu invocation. A real `cat` subprocess test covers
streaming and disposal. The separate package job builds the candidate archive
and clean-installs the same tar on 31.1 and the declared 28.1 floor.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was rerun against the current action implementation. Its only findings are the two warnings
that `emacs` is redundant in the main/layout package names; the table and tree modules
are clean. This remains a packaging question, not an overall clean lint pass.
The extracted local runtime disables native compiler trampoline generation
because it has no configured native compiler toolchain.

## Remaining work

1. Extend application controls
   through concrete consumers. Preserve ephemeral behavior. Extend layouts, history, per-view
   input, maximize/restore and tree/form controls as real consumers require them. Avoid treating every preview as navigation.
2. Broaden actual display validation: GUI child frames, macOS terminal emulators,
   multiplexers, narrow screens, multiple clients/terminals and visual behavior.
   Linux PTY smoke is not complete UI QA.
3. Measure large-result rendering, input-to-display latency and allocations.
   Source/filter/sort/mark/tree updates replace full view contents; selection
   navigation reuses rendered rows and unchanged text previews avoid replacement. Async providers remain
   cooperative and must return promptly; cancellation must stop their own
   processes/timers. Snapshot acquisition in the async demo is synchronous.
4. Resolve the package-name lint question, document API/migration stability and accumulate
   real usage. Continue through ROADMAP.md; only the limited navigation baseline is established; maturity has not
   been established.

## External gates and continuity

MELPA guidance was rechecked on 2026-10-24: public maintenance of at least one
month and human review expectations remain. Earliest known time eligibility is
approximately 2026-11-23, not a promised completion date. Autonomous reviews do
not satisfy the human-review expectation. See docs/MELPA.md for source links;
never claim acceptance from a submission alone.

Work continues hourly Monday through Saturday. No Sunday work or notifications
(America/Toronto). Scheduled sessions are discrete, not an uninterrupted daemon.
The owner expects to check in Saturday 2026-10-24 around 09:00; that is not a stop
time. Treat recently updated active drafts as claimed scope, use expected-head
leases, and leave actual test evidence and remaining work in this file.
