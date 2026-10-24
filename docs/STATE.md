# Project state

Updated 2026-10-23 (America/Toronto).

## Active implementation

PR #13 merged at `288a1b54c129067f78e29d763a4eb5cfd73903b8` after independent
agent review, resolution of the hidden-native-edit cursor finding and final-head
CI [40056387223](https://github.com/vv111y/emacs-tui/actions/runs/40056387223).
All four Linux Emacs versions passed 190 ERT tests, strict compilation, checkdoc
and six real PTY scripts. Maximize/restore preserves native input and reading
state while keeping all views accessible and respecting unrelated windows.

Current work extends the same checks to hosted macOS on Emacs 30.2 and 31.1,
while retaining the four-version Linux matrix. Both macOS jobs must execute the
entire ERT/compile/checkdoc and real PTY suite; no platform-specific checks are
skipped. Runtime OS/architecture, Emacs version and build features are printed
so capability-based backend results can be interpreted accurately.

The pinned setup-emacs action documents Linux and macOS support. This is a new
validation target, not evidence of a pass yet: independent review and actual
macOS CI results are pending. Hosted PTYs do not establish Ghostty/iTerm2,
zellij/tmux, GUI child-frame or physical Apple M5 compatibility.

Active worker owns CI platform expansion and this handoff through review and
passing current-head CI. Next: richer application controls, broader display
validation and measured performance. No stability or MELPA-readiness claim.

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
checkdoc and six real terminal smoke scripts, including maximize/restore
through terminal resizes. The macOS extension is not yet validated. Emacs 31.1 uses native TTY child frames in the ephemeral
persistent and input scripts; earlier versions use ordinary windows. Embedded/table
scripts use a borrowed window. Resize coverage is 120x40 -> 90x30 -> 140x45.
A separate real `cat` subprocess test verifies streaming and process disposal.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was rerun against the current maximize implementation. Its only findings are the two warnings
that `emacs` is redundant in the main/layout package names; the table and tree modules
are clean. This remains a packaging question, not an overall clean lint pass.
The extracted local runtime disables native compiler trampoline generation
because it has no configured native compiler toolchain.

## Remaining work

1. Validate and integrate macOS CI, then extend application controls
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
