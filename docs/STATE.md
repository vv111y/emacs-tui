# Project state

Updated 2026-10-23 (America/Toronto).

## Current work

The foundation [PR #1](https://github.com/vv111y/emacs-tui/pull/1) is merged.
Automatic viewport reflow and real terminal resize tests shipped in merged
[PR #2](https://github.com/vv111y/emacs-tui/pull/2), commit `80e552d`.
Cancellable asynchronous query providers are implemented in
[PR #3](https://github.com/vv111y/emacs-tui/pull/3). Inspect its live review/check
and merge status before starting overlapping work. The current worker owns
core, provider tests, examples, terminal smoke and README until integration.
The repository started empty; this is still an experimental development release.

Implemented: pure columns/rows/grid geometry, editable temporary queries,
independent list/text views and selection, literal filtering or custom query
callback, update-in-place buffers, explicit selection/commit, origin markers,
atomic origin-buffer commit rollback, owned window cleanup, capability-based
child-frame backend and ordinary-window fallback, graph demo.

Validation so far: 44 Emacs 29.3 local ERT tests, strict byte compilation and
checkdoc pass. Real pseudo-terminal typing/select/commit smoke now shrinks and
expands the terminal (120x40 -> 90x30 -> 140x45) with query/cursor/selection and
source preservation assertions. Final-head PR #2 CI
[40042620243](https://github.com/vv111y/emacs-tui/actions/runs/40042620243)
passed all 44 tests, strict compilation, checkdoc and PTY smoke on Emacs 28.2,
29.4, 30.2 and 31.1. The 31.1 job explicitly used native TTY child frames and
passed both actual resize transitions. Initial GUI fitting remains unverified
on an actual graphical display.

PR #3 adds mutually exclusive `:provider` / `:on-query`, configurable debounce,
per-session request identities, replacement streaming publications, failure
callbacks and cancellation. Old provider-owned results clear on query changes;
static views remain. Reflow does not restart providers. Async work is still
cooperative: providers must return promptly, and application cancellation must
actually stop its own processes/timers.

Local PR #3 validation: 68 ERT tests pass on Emacs 29.3, including real `cat`
process streaming/disposal and lifecycle races. Strict compilation and checkdoc
include both examples and pass. The interactive TTY smoke now waits for async
results before selection/resize/commit and verifies cancellation. Final-head CI
and independent review must pass before integration. The buffer-search example
is available with `make async-demo`; its snapshots are collected synchronously,
then searched in bounded batches. No performance claims are established.

Latest package-lint was inspected and executed from upstream commit
`1865be780a16098f972fef50a52b21ca6ee04df9`: both source files produce only its
package-name warning that the word `emacs` is redundant. This is a known
packaging question to resolve before MELPA submission, not a clean lint pass.
Local checks required disabling native compiler trampoline generation because
the extracted test runtime has no configured native compiler toolchain.

## Next work

1. Finish PR #3 independent review and final-head CI if still open, then
   integrate the reviewed head. Do not reimplement shipped provider lifecycle.
2. Broaden TTY coverage beyond Linux pseudo-terminals, including macOS terminals,
   multiple clients and visual behavior; CI smoke alone is not complete UI QA.
3. Expand narrow-terminal and multiple-client coverage. Automatic reflow and
   owned-subtree invalidation are now implemented; verify actual GUI behavior.
4. Develop around-point layouts, explicit traversal history and per-view query
   state through real examples. Avoid treating every preview as navigation.
   Add measured large-result rendering work once these interactions settle.
5. Follow ROADMAP.md through performance, installation and release readiness.

## Completion gates

No stable API release, mature-use evidence, performance claim or MELPA acceptance
exists yet. Earliest known public-maintenance eligibility is approximately
2026-11-23; meaningful maintenance and real human review are still needed.

Continued work is scheduled hourly, Monday through Saturday, starting at 20:00
America/Toronto on 2026-10-23. Scheduled sessions are discrete work runs, not a
continuous daemon. The owner expects to check in Saturday 2026-10-24 around
09:00; that is not a stop time. Each run should checkpoint actual new evidence
and inspect recently active draft PRs to avoid conflicting work.
