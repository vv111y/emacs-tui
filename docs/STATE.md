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

The current focused fix preserves text-preview reading position when switching
views or repeating unchanged text/properties. It avoids erasing identical text,
including narrowed previews; changed content retains the existing reset behavior.
The pre-fix regression suite reproduced three failures. Local checks pass 149
ERT tests, compilation, checkdoc and four real PTY scripts, including the narrowing
regression. The persistent PTY script now verifies preview
point across focus round trips and actual terminal resizes.

Active worker owns core rendering, preview tests, persistent TTY smoke, README
and this handoff through independent review and current-head CI. After this fix,
continue application input widgets or tree controls with a concrete example.
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

The implementation at `d83cd66d75f437cd58d24ce6614505ad7956d43a` passes all
**88 ERT tests**, strict package/example byte compilation, checkdoc and real
terminal smoke on **Emacs 28.2, 29.4, 30.2 and 31.1** in
[CI run 40044053847](https://github.com/vv111y/emacs-tui/actions/runs/40044053847).
Independent review repeated the suite locally on Emacs 29.3 with no remaining
review blockers.

The real PTY smoke waits for async results, marks two items, preserves query,
cursor, selection and marks through 120x40 -> 90x30 -> 140x45 terminal resizes,
then explicitly commits the batch and verifies cancellation. Emacs 31.1 uses
native TTY child frames; earlier versions use ordinary windows. A separate
real `cat` subprocess test verifies streaming output and process disposal.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was rerun against the PR #4 sources. Its only findings are the two warnings
that `emacs` is redundant in package names. This remains a packaging question,
not a clean lint pass. The extracted local runtime disables native compiler
trampoline generation because it has no configured native compiler toolchain.

## Remaining work

1. Review and integrate preview-position preservation, then extend application input/action
   composition. Preserve ephemeral behavior. Extend layouts, history, per-view
   input, maximize/restore and tree/form controls as real consumers require them. Avoid treating every preview as navigation.
2. Broaden actual display validation: GUI child frames, macOS terminal emulators,
   multiplexers, narrow screens, multiple clients/terminals and visual behavior.
   Linux PTY smoke is not complete UI QA.
3. Measure large-result rendering, input-to-display latency and allocations.
   Rendering currently replaces full view contents. Async providers remain
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
