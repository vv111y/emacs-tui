# Project state

Updated 2026-10-23 (America/Toronto).

## Current work

The foundation [PR #1](https://github.com/vv111y/emacs-tui/pull/1) is merged.
Automatic viewport reflow and real terminal resize tests are implemented in
[PR #2](https://github.com/vv111y/emacs-tui/pull/2). Inspect its live merge/check
status and recent updates before starting overlapping work.
The repository started empty; this is still an experimental development release.

Implemented: pure columns/rows/grid geometry, editable temporary queries,
independent list/text views and selection, literal filtering or custom query
callback, update-in-place buffers, explicit selection/commit, origin markers,
atomic origin-buffer commit rollback, owned window cleanup, capability-based
child-frame backend and ordinary-window fallback, graph demo.

Validation so far: 44 Emacs 29.3 local ERT tests, strict byte compilation and
checkdoc pass. Real pseudo-terminal typing/select/commit smoke now shrinks and
expands the terminal (120x40 -> 90x30 -> 140x45) with query/cursor/selection and
source preservation assertions. The windows backend passes locally; PR #2 CI
must verify native 31.1 child-frame resizing before integration. Initial GUI
fitting remains unverified on an actual graphical display.

Foundation independent review found lifecycle/provider/compact-view
defects; all have fixes and regression coverage, independently retested with no
remaining foundation blockers. CI run
[40040890417](https://github.com/vv111y/emacs-tui/actions/runs/40040890417) passed
on Emacs 28.2, 29.4, 30.2 and 31.1 for commit `7959f59`. Its 31.1 log confirms
`PASS Emacs 31.1; real TTY; backend=child-frame`. The final additional nonlocal
startup-exit regression is test 33; the PR's latest checks govern integration.

Latest package-lint was inspected and executed from upstream commit
`1865be780a16098f972fef50a52b21ca6ee04df9`: both source files produce only its
package-name warning that the word `emacs` is redundant. This is a known
packaging question to resolve before MELPA submission, not a clean lint pass.
Local checks required disabling native compiler trampoline generation because
the extracted test runtime has no configured native compiler toolchain.

## Next work

1. Finish PR #2 independent review and final-head CI if still open; then
   integrate the reviewed head. Do not repeat the foundation implementation.
2. Broaden TTY coverage beyond Linux pseudo-terminals, including macOS terminals,
   multiple clients and visual behavior; CI smoke alone is not complete UI QA.
3. Expand narrow-terminal and multiple-client coverage. Automatic reflow and
   owned-subtree invalidation are now implemented; verify actual GUI behavior.
4. Develop around-point layouts, traversal history and per-view state through
   the graph demo; add bounded async provider lifecycle and stale-result tests.
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
