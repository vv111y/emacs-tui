# Project state

Updated 2026-10-24 (America/Toronto).

## Active implementation

PR #23 merged at `135aea3b22343c8496d2ece99e2ab5acdb262984` after independent
review and all eight final-head CI jobs in
[40071844167](https://github.com/vv111y/emacs-tui/actions/runs/40071844167).
Runtime jobs passed 241 ERT, strict compilation/checkdoc, six PTY scripts,
three Python regressions and all five benchmark workloads in both source and
fresh-bytecode modes. Package build/clean-install passed on 31.1/28.1.
Named current-view/focus-view, identity-based set-selection and named current-item
reads preserve query/mark/sort state and avoid implicit actions. The dashboard
uses them to inspect a process's associated buffer explicitly.

Source-mode paired profiles and the full fresh-bytecode profile retain all raw
records, environment, source/artifact hashes and percentiles under bench/results.
The compiled profile has 1,100 records and separate controlled provider stages.
On this Emacs 29.3/Linux host, 10,000-row table navigation p50/p95/p99 is
0.546/0.789/0.849ms, while full table query clearing is 272.447/320.990/333.227ms.
This is one configuration with interpreted fixture callbacks and native JIT off;
GUI/emulator paint and native compilation remain unmeasured. Full table rebuilds
and nonempty matching remain candidates for later measured work.

Current work adds repeated lifecycle/resource stress: 75 batch lifetimes and
45 additional real-PTY lifetimes across 120x40, 90x30 and 140x45. Each rotates
ephemeral, persistent and embedded presentations, with a separate live embedded
anchor throughout each batch. Real debounce dispatch, application-owned pipe
processes and producer timers exercise cancellation. Some sessions close before
debounce, others via explicit repeated close or killing an owned buffer;
ephemeral query changes supersede running generations. Obsolete publish/error
closures are rejected during replacement and after disposal. Assertions cover
owned buffers/processes/timers, request invalidation, detached origin/host
markers, removed source hooks/window claims, restored frame/window sets,
application host edits/point, anchor selection/marks and final global hooks.

This is repeated bounded stress, not evidence for every OS, terminal emulator,
GUI or multi-terminal topology. Existing fault-injection tests cover callback
errors and exceptional cleanup. Next: more concrete consumer capabilities and
broader display validation. The package remains experimental; public maintenance
and human-review gates remain. Independent review and current-head CI are still
required for this stress addition. Local 242 ERT, seven PTY scripts, strict
package/example compilation/checkdoc, strict compilation of both new test
fixtures, three Python regressions and both benchmark modes passed on Emacs
29.3/Linux. No local child-frame capability or GUI/macOS validation is claimed.

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
