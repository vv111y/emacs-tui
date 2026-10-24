# Project state

Updated 2026-10-23 (America/Toronto).

## Active implementation

PR #6 is merged at `0d181ea9c48af1a5df3bfd4e0404a130e326001f` after separate
agent review of `a65432bfe04ef1aa91e8400efb817cb6923b4b32`. The reviewer reran
106 ERT tests, compilation, checkdoc, both real Emacs 29.3 TTY scripts and
50 additional lifecycle cycles without retained sessions or owned buffers.
All four CI jobs passed in
[run 40048314834](https://github.com/vv111y/emacs-tui/actions/runs/40048314834).
This was agent review, not human/MELPA review.

[PR #7](https://github.com/vv111y/emacs-tui/pull/7) adds `emacs-tui-embed` for one panel in a borrowed application
window, restoring the original buffer and tracked point/scroll on close. It
preserves repurposed windows, supports async providers and explicit actions,
and never deletes the borrowed host window. A buffer browser demonstrates it.
A dedicated real TTY script checks keyboard actions, marks, resizing and host
restoration. Region-level embedding is outside this increment.

Active worker owns core, embed tests/example/smoke, Makefile, README and this
handoff. Independent review and current-head CI are required before integration.
Local validation passed 118 ERT tests, strict compilation, checkdoc and all
three real TTY scripts on Emacs 29.3. Do not treat these author checks as
independent review.

Implementation head `e81ee3e7d50dd7be226b9f1919907f6c23d9e9ff` passes all four
Emacs versions, including all three real TTY scripts, in
[CI run 40048997759](https://github.com/vv111y/emacs-tui/actions/runs/40048997759).
A separate reviewer reran 118 ERT tests; further restoration probes are in
progress. The reviewer caught a stale README statement about embedding, now
corrected. The owner confirmed routine independent review belongs to a separate
coding agent, not to them; AGENTS.md records this workflow.

## Implementation and handoff

This is an experimental development release, not a stable or MELPA package.

Scope clarification from the owner, 2026-10-23: build a general-purpose TUI
toolkit for Emacs. The ephemeral XOB-style workflow is one supported application
pattern. Persistent applications and embedded panels must not require query
input, an origin marker, or commit-then-close. See docs/DESIGN.md and the new
immediate priorities in ROADMAP.md. PR #6 merged the persistent lifecycle and dashboard. The current increment
proves a borrowed-window embedding policy over the same primitives.

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

1. Review and integrate the borrowed-window embedding increment, then add
   application input/action composition. Preserve ephemeral behavior. Extend
   layouts, history, per-view input, maximize/restore and tables as real consumers
   require them. Avoid treating every preview as navigation.
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
