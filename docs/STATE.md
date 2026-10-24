# Project state

Updated 2026-10-23 (America/Toronto).

## Active implementation

PR #11 merged at `13cbc56a6a1d20e40b95ee3f47ef735b7d59baf4` after independent
agent review and final-head CI
[40052760805](https://github.com/vv111y/emacs-tui/actions/runs/40052760805).
All four Emacs versions passed 165 ERT tests, strict compilation, checkdoc and
five real PTY scripts, including native editable input/undo on 31.1 child frames.

Current work adds `emacs-tui-tree` over the existing original-item selection,
marks, actions and source-update APIs. Expansion, first-child/parent navigation
and non-color branch cues are display state. Local search reveals matching
paths without changing stored expansion. Source replacements retain surviving
expansion/selection/marks and reject invalid hierarchies before publication.
The buffer-tree example groups live buffers by major mode with refresh, preview
and explicit display actions. `make tree` runs it.

Initial boundaries: the entire finite forest is indexed once per snapshot;
children accessors must be pure and return promptly. Plist nodes require stable
non-nil :id values and all identities must be globally unique. Cycles and shared
occurrences are rejected. Lazy loading, tree tables and graph occurrence IDs
are not implemented. Applications/providers own data acquisition and search
policy. Tree views support mount, embed and the ephemeral query lifecycle.

Local Emacs 29.3 passes 180 ERT tests, strict compilation, checkdoc and six real
PTY scripts. New cases exercise navigation, original-object actions, hidden
marks, retained expansion, query ancestor paths, failed update/render rollback,
provider supersession, descriptor reuse, embedding and the buffer example.
The new PTY script expands/collapses, marks a hidden leaf, replaces its source,
retains selection through real resizes and invokes preview actions explicitly.
Package-lint still reports only the two existing main/layout name warnings;
the tree module has no new findings. Independent review and four-version CI
are pending.

Active worker owns tree indexing/navigation, the buffer-tree example and tests,
build integration and documentation through review and CI. Next: view
maximize/restore, navigation history or richer form controls through concrete
applications, plus broader terminal validation. No maturity or MELPA claim.

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

API and runnable examples are in README.md. `make demo` explores an in-memory
sample graph; `make async-demo` searches buffer snapshots. Marks are per view
and preserve local filtered-hidden selections. Source replacement prunes absent
identities; async query supersession clears provider-owned results and marks.
The graph demo deliberately filters only nodes so forward/backlinks remain
navigable. Query edits there may prune marks as its source results change.

## Validation

Current evidence is recorded above. The suite covers persistent, embedded and
ephemeral presentations, async cancellation/streaming, stable selection and
marks, tables, editable inputs, callback failure rollback and preview position. The merged four-version CI suite runs strict package/example byte compilation,
checkdoc and five real terminal smoke scripts; the pending tree change adds
a sixth script. Emacs 31.1 uses native TTY child frames in the ephemeral
persistent and input scripts; earlier versions use ordinary windows. Embedded/table
scripts use a borrowed window. Resize coverage is 120x40 -> 90x30 -> 140x45.
A separate real `cat` subprocess test verifies streaming and process disposal.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was rerun against the current tree implementation. Its only findings are the two warnings
that `emacs` is redundant in the main/layout package names; the table and tree modules
are clean. This remains a packaging question, not an overall clean lint pass.
The extracted local runtime disables native compiler trampoline generation
because it has no configured native compiler toolchain.

## Remaining work

1. Review and integrate tree views, then extend application controls
   through concrete consumers. Preserve ephemeral behavior. Extend layouts, history, per-view
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
