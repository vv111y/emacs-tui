# Project state

Updated 2026-10-23 (America/Toronto).

## Current work

Initial foundation is under independent review on `codex/workspace-foundation`.
The repository started empty. The default branch initially contains only the
project charter; follow the open PR for implementation until integration.

Implemented: pure columns/rows/grid geometry, editable temporary queries,
independent list/text views and selection, literal filtering or custom query
callback, update-in-place buffers, explicit selection/commit, origin markers,
atomic origin-buffer commit rollback, owned window cleanup, capability-based
child-frame backend and ordinary-window fallback, graph demo.

Validation so far: 32 Emacs 29.3 local ERT tests, strict byte compilation and
checkdoc pass; real pseudo-terminal typing/select/commit smoke passes with the
windows backend. Independent review found six lifecycle/provider/compact-view
defects; each has a fix and regression coverage, with independent retest in
progress. Remote multi-version CI is not yet verified.

Latest package-lint was inspected and executed from upstream commit
`1865be780a16098f972fef50a52b21ca6ee04df9`: both source files produce only its
package-name warning that the word `emacs` is redundant. This is a known
packaging question to resolve before MELPA submission, not a clean lint pass.
Local checks required disabling native compiler trampoline generation because
the extracted test runtime has no configured native compiler toolchain.

## Next work

1. Complete independent retest and publish the foundation PR.
2. Check remote CI, especially actual 31.1 TTY child-frame creation/focus; fix
   failures before merging the reviewed head.
3. Add robust resize/reflow and compact-view navigation; verify narrow terminals
   and lifecycle across source/window/frame deletion.
4. Develop around-point layouts, traversal history and per-view state through
   the graph demo; add bounded async provider lifecycle and stale-result tests.
5. Follow ROADMAP.md through performance, installation and release readiness.

## Completion gates

No stable API release, mature-use evidence, performance claim or MELPA acceptance
exists yet. Earliest known public-maintenance eligibility is approximately
2026-11-23; meaningful maintenance and real human review are still needed.

Continued work is scheduled Monday through Saturday at approximately 08:00,
15:00 and 20:00 America/Toronto. Scheduled sessions are discrete work runs, not a
continuous daemon. Each run should update this file with actual new evidence.
