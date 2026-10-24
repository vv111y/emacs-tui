# Project state

Updated 2026-10-23 (America/Toronto).

## Active implementation

PR #16 merged at `5747c4a1505805bd92e8fe5597bc9221a3f88983` after independent
review, resolution of native case-folded action completion and final-head CI
[40059656569](https://github.com/vv111y/emacs-tui/actions/runs/40059656569).
All six Linux/macOS jobs passed 218 ERT tests, strict compilation, checkdoc and
six real PTY scripts, including native action menus on ARM64 macOS 31.1.

Current work adds actual candidate-recipe/package-build and clean-install
validation. The recipe includes all five library files and LICENSE. Pinned
package-build/compat tools operate on an isolated clone of the tested checkout,
with a test-only commit constraint and no-fetch mode. The source checkout is
never reset. The tar is installed in a separate Emacs with a fresh package
folder, empty working directory and no source/build-tool load path. Checks
verify installed library/definition paths and exercise public APIs.

Local Emacs 29.3 built/installed a committed fixture containing the current
library files and LICENSE, using the pinned real upstream tools. Archive file
coverage, actual installed definitions, table/query/hidden action targets,
input undo, tree navigation, maximize and disposal all passed. Python syntax
and strict compilation of the two build/install Lisp scripts passed. This is
local fixture evidence, not yet a CI pass for the repository commit.

The new CI job builds/installs using 31.1, then installs the identical tar
in a fresh 28.1 process with explicit version assertions. Initial CI built and
clean-installed the exact repository artifact on 31.1, but switching versions
through the shared Nix profile failed with a package-file collision. The older
install now uses a pinned profile-free Nix invocation; this correction still
needs review and a passing CI run. The ordinary matrix
also adds Linux 28.1, matching the declared API floor. All seven runtime jobs
and the package job must pass; independent review and actual CI are pending.
This verifies recipe layout/build/install, not network fetching, a live MELPA
archive, API stability or human review. See docs/PACKAGING.md.

Active worker owns package recipe/runner/install smoke, CI/build integration,
packaging documentation and this handoff through review and CI. Next: measured
input/display latency and allocations, broader display validation and API
stability through real use. Public-history and human-review MELPA gates remain.

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
through terminal resizes. ARM64 macOS 30.2 and 31.1 also passed that suite in the implementation CI above. Emacs 31.1 uses native TTY child frames in the ephemeral
persistent and input scripts; earlier versions use ordinary windows. Embedded/table
scripts use a borrowed window. Resize coverage is 120x40 -> 90x30 -> 140x45.
A separate real `cat` subprocess test verifies streaming and process disposal.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was rerun against the current action implementation. Its only findings are the two warnings
that `emacs` is redundant in the main/layout package names; the table and tree modules
are clean. This remains a packaging question, not an overall clean lint pass.
The extracted local runtime disables native compiler trampoline generation
because it has no configured native compiler toolchain.

## Remaining work

1. Validate and integrate recipe/clean-install checks, then extend application controls
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
4. Complete the pending recipe/clean-install CI and resolve the
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
