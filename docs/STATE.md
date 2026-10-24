# Project state

Updated 2026-10-24 (America/Toronto).

## Active implementation

PR #28 merged at `32b558f360b5c83d6c0579b36a5c8644069e6c0f` after exact-head
independent review and all eight final-head CI jobs in
[40074519434](https://github.com/vv111y/emacs-tui/actions/runs/40074519434).
Runtime jobs passed 257 ERT, strict compilation/checkdoc, seven PTY scripts,
three Python regressions and all five source/fresh-bytecode benchmark smoke
workloads. The actual recipe built and the resulting archive clean-installed
on 31.1/28.1. Linux/macOS 31.1 logs explicitly confirm native child frames for
ephemeral/persistent/input/tree and repeated-lifetime fixtures, including new
bulk keys in the ephemeral fixture. Agent review additionally verified native
bulk bindings and insertion-hook rollback with properties/highlight retained.

Packaging cleanup makes the layout file an explicit helper of emacs-tui, like
the table/tree/action modules, instead of repeating standalone version/dependency
metadata. `package-lint-main-file` now points to the actual main library, and
the header describes general text interfaces. All executable Lisp forms are
unchanged. Latest upstream package-lint reports only the remaining main package
name warning; the layout warning is resolved through correct package ownership,
not suppression. Local 257 ERT, strict compilation and checkdoc passed on Emacs
29.3/Linux. Independent review and fresh current-head recipe/installation and
runtime CI remain integration gates. Preliminary independent review confirmed
all executable forms match, metadata ownership is appropriate and only the
main-name lint warning remains. The remaining naming warning and external
MELPA gates are not waived.

PR #27 merged at `b532d7bcd73fbaa342bde5271e1ce94a054ed75e` after exact-head
independent review and all eight CI jobs in
[40074067095](https://github.com/vv111y/emacs-tui/actions/runs/40074067095).
Runtime jobs passed 249 ERT, strict compilation/checkdoc, seven PTY scripts,
three Python regressions and all five source/fresh-bytecode benchmark smoke
workloads; package build and clean installs passed on 31.1/28.1. This closes the
focus-cycling ownership hole described below.

Bulk marking adds `emacs-tui-mark-all` and `emacs-tui-invert-marks`, accepting
optional session/view ID. They operate on the current list/table/tree projection,
including off-screen rows while preserving marks on filtered items/collapsed
descendants. Operations on named hidden panels preserve current focus. Each
command stages a copied identity table and renders once; empty projections are unchanged. Native keys
are C-c * and C-c C-t; ordinary query characters remain editable. No exploration,
context-action or commit callback runs implicitly. The graph example documents
the keys and tests bulk selection followed by explicit ordered commitment.

Local 257 ERT, strict compilation/checkdoc, seven PTY scripts, three Python
regressions and both benchmark modes passed on Emacs 29.3/Linux. Eight new ERT
cases cover hidden marks/panels, tree collapse, source order with descending
sort, unchanged selection, 200 projected cells once per bulk operation, failure
rollback/retry, invalid targets, native editing/keys and explicit graph commit.
The real ephemeral PTY fixture now exercises both bulk bindings before its
original selection/resize/commit sequence. Exact-head independent review and
all eight final-head CI jobs passed as recorded above. Independent review
passed 257 ERT and the updated real-PTY bulk bindings, plus an insertion-hook
failure probe preserving marks, properties, highlight bounds and recovery.
Next: consumer-driven controls, actual GUI/emulator/multiplexer and multiple-terminal validation, real usage
and measured remaining rendering bottlenecks. No new latency claim is made.

PR #26 merged at `c9871bc591295b2c640c63d9e606f7f7099a9cec` after independent
implementation/fixture review and all eight final-head CI jobs in
[40073781778](https://github.com/vv111y/emacs-tui/actions/runs/40073781778).
Runtime jobs passed 247 ERT, strict compilation/checkdoc, seven PTY scripts,
three Python regressions and all five source/fresh-bytecode benchmark smoke
workloads; package build and clean installs passed on 31.1/28.1.

PR #27 makes focus cycling reject invalidated surfaces before logical focus changes or
hidden-panel reuse. The named focus API already had this guard. Without it, a
maximized session whose visible pane was repurposed could replace an unrelated
buffer when cycling to a hidden panel; a visible foreign pane could also acquire
native focus. Two regressions fail on prior code and pass with this guard. They
cover ephemeral/persistent maximized cases and visible foreign panes, both
cycling directions, logical/native focus, pane mapping, buffer content/cursor/
scroll and normal disposal. Local 249 ERT, strict compilation/checkdoc, seven
PTY scripts, three Python regressions and both benchmark modes passed on Emacs
29.3/Linux. Independent review also confirmed valid deleted-window
reveal and preservation of unrelated windows outside the owned subtree. Its final-head CI run is linked above.

Recent integrated behavior:

- PR #23 exposes named view focus/selection and hidden-panel reads without
  implicit actions; the dashboard explicitly inspects a process's buffer.
- PR #24 adds 75 batch and 45 real-PTY lifetimes at three sizes, preserving a
  second session and checking timers/processes/buffers/markers/windows/frames,
  stale callbacks, host edits and hook cleanup. Fault probes detect skipped
  cancellation and invalid stale acknowledgements. Linux/macOS 31.1 uses native
  child frames; other tested runtimes use ordinary windows.
- PR #25 stages mark changes until successful rendering. Projection and native
  after-change-hook failures preserve marks, hidden targets, indicators and
  highlight; retries work. Independent review verified old-code failures,
  table isolation, hidden-panel clearing and property/overlay rollback.
- PR #26 prevents late renders from moving unrelated window cursors before
  ownership invalidation. Tests cover list updates/marks/navigation and provider
  preview replacement, then normal refresh/cancellation and stale rejection.

Initial PR #26 CI run 40073514199 failed Linux 29.4's persistent resize assertion:
terminal dimensions matched while cached geometry differed. All 247 ERT passed
there. The fixture now waits for terminal dimensions and automatic cached
geometry convergence within its original 100-poll bound, retaining assertions
and forcing no refresh. A delayed-hook probe fails the old fixture and passes
the revised one; disabling automatic reflow still fails at the bound. Independent
review repeated these probes. The failed run was not counted as a pass; the
fresh final-head run linked above passed all eight jobs. This identifies an
ordering-sensitive assertion, not a proven cause of every resize race.

Published source pairs and the full bytecode profile retain raw samples,
environment, source/artifact hashes and percentiles under bench/results. The
compiled profile has 1,100 records and separate controlled-provider stages.
On that Emacs 29.3/Linux configuration, 10,000-row table navigation p50/p95/p99
was 0.546/0.789/0.849ms; full table query clearing was 272.447/320.990/333.227ms.
These are historical measurements with interpreted fixture callbacks and native
JIT off, not new measurements of this ownership change. Full table rebuilds and
nonempty matching remain measured bottlenecks for later work.

Latest upstream package-lint now reports the one documented main-name warning.
The package remains experimental. GUI/emulator/multiplexer, physical macOS and
multi-terminal validation and substantive real usage remain incomplete. Repeated
bounded stress and hosted PTYs do not establish all display combinations or
long-term stability. Public-maintenance and human-review MELPA gates remain.

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
- [PR #20](https://github.com/vv111y/emacs-tui/pull/20): empty-term predicate
  fast path and reviewed native query-clear latency/allocation evidence.
- [PR #22](https://github.com/vv111y/emacs-tui/pull/22): isolated source/bytecode
  benchmark modes and a reviewed full compiled-library workload profile.
- [PR #23](https://github.com/vv111y/emacs-tui/pull/23): named view focus and
  projected selection APIs, with dashboard process-buffer inspection.
- [PR #24](https://github.com/vv111y/emacs-tui/pull/24): repeated batch/native
  terminal ownership stress, cancellation and live-session isolation.
- [PR #25](https://github.com/vv111y/emacs-tui/pull/25): mark targets and
  indicators remain consistent after projection or native editing failures.
- [PR #26](https://github.com/vv111y/emacs-tui/pull/26): late view updates
  preserve repurposed-window cursors; bounded automatic resize synchronization.
- [PR #27](https://github.com/vv111y/emacs-tui/pull/27): view cycling validates
  ownership before changing focus or revealing hidden panels.
- [PR #28](https://github.com/vv111y/emacs-tui/pull/28): bulk projection marking
  and inversion, hidden-mark retention and explicit graph batch commitment.

API and runnable examples are in README.md. `make demo` explores an in-memory
sample graph; `make async-demo` searches buffer snapshots. Marks are per view
and preserve local filtered-hidden selections. Source replacement prunes absent
identities; async query supersession clears provider-owned results and marks.
The graph demo deliberately filters only nodes so forward/backlinks remain
navigable. Query edits there may prune marks as its source results change.

## Validation

Current evidence is recorded above. Runtime CI covers Linux Emacs 28.1,
28.2, 29.4, 30.2 and 31.1, plus ARM64 macOS 30.2 and 31.1. Each job runs ERT,
strict compilation, checkdoc and seven real terminal scripts. Emacs 31.1 uses
native TTY child frames for ephemeral/persistent/input/tree interfaces on both
platforms; earlier versions use windows. Embedded/table scripts borrow a
window. Resize coverage is 120x40 -> 90x30 -> 140x45, including maximize/restore
and explicit action-menu invocation. A real `cat` subprocess test covers
streaming and disposal. The separate package job builds the candidate archive
and clean-installs the same tar on 31.1 and the declared 28.1 floor.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was confirmed as the latest upstream main and rerun on 2026-10-24. With the
layout helper metadata corrected, its only finding is that `emacs` is redundant
in the main package name. All four helper modules are clean. The remaining name
question prevents an overall clean lint claim; no warning is suppressed.
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
approximately 2026-11-23, not a promised completion date. The upstream recipe
path `recipes/emacs-tui` was absent on this check; recheck availability before
submission. docs/MELPA.md records the exact policy file hashes. Autonomous reviews do
not satisfy the human-review expectation. See docs/MELPA.md for source links;
never claim acceptance from a submission alone.

Work continues hourly Monday through Saturday. No Sunday work or notifications
(America/Toronto). Scheduled sessions are discrete, not an uninterrupted daemon.
The owner expects to check in Saturday 2026-10-24 around 09:00; that is not a stop
time. Treat recently updated active drafts as claimed scope, use expected-head
leases, and leave actual test evidence and remaining work in this file.
