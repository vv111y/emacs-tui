# Project state

Updated 2026-10-23 (America/Toronto).

## Active implementation

PR #12 merged at `07612ba43c82430bfedadf9b260776ab158ccd22` after independent
agent review and final-head CI
[40055670701](https://github.com/vv111y/emacs-tui/actions/runs/40055670701).
All four versions passed 180 ERT tests, strict compilation, checkdoc and six
real PTY scripts. Trees retain original objects, expansion and hidden marks
through source snapshots, expose ancestor paths for local queries, and work
in persistent, embedded and ephemeral interfaces. `make tree` demonstrates a
mode-grouped buffer browser. Snapshots are eager finite forests with globally
unique IDs; lazy/shared graph occurrences remain future work.

Current work adds `emacs-tui-toggle-maximize` on C-c C-f: enlarge the focused
view within the owned TUI surface and restore the chosen layout. Query input
and unrelated windows retain their space. Focus navigation still reaches all
views while maximized. Native text cursor/scroll is cached per view across
hiding/reflow; edits, undo, narrowing, selection, marks and tree expansion
remain intact. Changed text invalidates stale reading positions. Single-view
panels are unchanged. Maximization invokes no application actions/providers.

Local Emacs 29.3 passes 190 ERT tests, strict compilation, checkdoc and all six
PTY scripts. New tests cover every-view access, layout restoration, hidden
preview updates, input undo/narrowing, ephemeral query editing, quiet callbacks,
single embedded views, unrelated-window geometry and cleanup. The tree PTY
script now focuses both maximized views, resizes with only one visible panel,
restores both panels, and explicitly previews again.

Independent review found one stale-position bug: native edits to a hidden input
moved its native point but an old cached integer overrode it on return. Native
input changes now invalidate that cache without clearing undo. A regression
reproduced point 500 instead of 506 before the fix and now passes, including
undo recovery. Independent review and a local probe also verified a 30-view
compact-layout round trip retains point and horizontal scroll.

Corrected implementation `5ddd8d34f45b56f11c32880c1ff85968b3453993` received
independent approval after the reviewer repeated all 190 ERT tests, strict
compilation, checkdoc and six PTY scripts. Its additional probes confirmed
repeated hidden edits and later layout restoration keep native point and undo.
Corrected implementation CI
[40056269656](https://github.com/vv111y/emacs-tui/actions/runs/40056269656)
passed all checks on Emacs 28.2, 29.4, 30.2 and 31.1, including the real native
TTY child-frame maximize/resize/restore path on 31.1. Final-head CI remains
required for the final handoff-only checkpoint.

The implementation is complete and independently reviewed; this handoff-only
checkpoint needs final-head review and CI before integration. Next:
broader terminal/platform validation, navigation history or richer controls
through concrete consumers. No stability or MELPA-readiness claim is made.

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
checkdoc and six real terminal smoke scripts; the pending maximize change
extends tree coverage through maximize/restore and resizes. Emacs 31.1 uses native TTY child frames in the ephemeral
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

1. Review and integrate maximize/restore, then extend application controls
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
