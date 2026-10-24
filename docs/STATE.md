# Project state

Updated 2026-10-23 (America/Toronto).

## Active implementation

PR #9 merged at `c298015a47a073365fe12d58408c89415f6da012` after separate
agent review and final-head CI
[40051525489](https://github.com/vv111y/emacs-tui/actions/runs/40051525489):
143 ERT tests, strict compilation, checkdoc and four real PTY scripts on Emacs
28.2, 29.4, 30.2 and 31.1. Tables share existing identities, selection, marks,
queries/actions and async updates. The dashboard demonstrates numeric sorting
and metadata columns. Fixed widths and first-line headers remain initial limits.

Review found and resolved a partial-update bug: comparator/projection failures
now preserve previous source, selection, marks, sort and displayed content by
staging new state and rendered content. Independent review repeated the complete
suite on Emacs 29.3 and reproduced failing-update/nonlocal-exit cases.

PR #10 implementation `1c0c34a490cbea3c37c1b9645d756eee5b5a9f7b` preserves
text-preview reading position across focus changes and identical updates,
including properties and narrowing. Changed content retains its reset behavior.
The pre-fix regression suite reproduced three failures. Independent review
approved the implementation and repeated 149 ERT tests, strict compilation,
checkdoc and four real PTY scripts on Emacs 29.3. Additional probes covered an
inactive narrowed preview without disturbing selection in another view.

Implementation CI [40051880355](https://github.com/vv111y/emacs-tui/actions/runs/40051880355)
passed all checks on Emacs 28.2, 29.4, 30.2 and 31.1. The persistent PTY script
verifies preview point across focus round trips and real terminal resizes.
This handoff-only checkpoint still requires final-head review and CI before
integration. No other scope is claimed. Next: application input widgets or tree
controls proved through a concrete example; retain the shared lifecycle API.
Package-lint still has only the two known package-name warnings. No stability
or MELPA-readiness claim is made.

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

API and runnable examples are in README.md. `make demo` explores an in-memory
sample graph; `make async-demo` searches buffer snapshots. Marks are per view
and preserve local filtered-hidden selections. Source replacement prunes absent
identities; async query supersession clears provider-owned results and marks.
The graph demo deliberately filters only nodes so forward/backlinks remain
navigable. Query edits there may prune marks as its source results change.

## Validation

Current evidence is recorded above. The suite covers persistent, embedded and
ephemeral presentations, async cancellation/streaming, stable selection and
marks, tables, callback failure rollback and preview position. All four CI
versions run strict package/example byte compilation, checkdoc and four actual
terminal smoke scripts. Emacs 31.1 uses native TTY child frames in the ephemeral
and persistent scripts; earlier versions use ordinary windows. Embedded/table
scripts use a borrowed window. Resize coverage is 120x40 -> 90x30 -> 140x45.
A separate real `cat` subprocess test verifies streaming and process disposal.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was rerun against the PR #9 sources. Its only findings are the two warnings
that `emacs` is redundant in the main/layout package names; the new table module
is clean. This remains a packaging question, not an overall clean lint pass.
The extracted local runtime disables native compiler trampoline generation
because it has no configured native compiler toolchain.

## Remaining work

1. After PR #10 final-head checks and integration, extend application input/action
   composition. Preserve ephemeral behavior. Extend layouts, history, per-view
   input, maximize/restore and tree/form controls as real consumers require them. Avoid treating every preview as navigation.
2. Broaden actual display validation: GUI child frames, macOS terminal emulators,
   multiplexers, narrow screens, multiple clients/terminals and visual behavior.
   Linux PTY smoke is not complete UI QA.
3. Measure large-result rendering, input-to-display latency and allocations.
   List/table rendering currently replaces full view contents; unchanged text
   previews avoid replacement. Async providers remain
   cooperative and must return promptly; cancellation must stop their own
   processes/timers. Snapshot acquisition in the async demo is synchronous.
4. Complete real package-build recipe and clean-install testing, resolve the
   package-name lint question, document API/migration stability and accumulate
   real usage. Continue through ROADMAP.md; no performance or maturity claim
   has been established.

## External gates and continuity

MELPA guidance was rechecked on 2026-10-23: public maintenance of at least one
month and human review expectations remain. Earliest known time eligibility is
approximately 2026-11-23, not a promised completion date. Autonomous reviews do
not satisfy the human-review expectation. See docs/MELPA.md for source links;
never claim acceptance from a submission alone.

Work continues hourly Monday through Saturday. No Sunday work or notifications
(America/Toronto). Scheduled sessions are discrete, not an uninterrupted daemon.
The owner expects to check in Saturday 2026-10-24 around 09:00; that is not a stop
time. Treat recently updated active drafts as claimed scope, use expected-head
leases, and leave actual test evidence and remaining work in this file.
