# Project state

Updated 2026-10-30 (America/Toronto). This is the current handoff.
[STATE-BETA6-TO-BETA7.md](STATE-BETA6-TO-BETA7.md) preserves the complete beta6
publication and subsequent implementation, review, checks and failure evidence.
Earlier archives remain linked there.

## Beta7 candidate

Version `0.1.0-beta7` packages the post-beta6 rendering protection and table
improvements for community use. README, API policy, demo/testing guides, bug
report placeholder and CI literal-version expectation match. All twelve demos,
public signatures and hotkeys remain available; runtime installation excludes
examples, so use a matching source checkout.

This is a release candidate until exact-head review, supported-version CI,
recipe build/clean installation and fixed-ref publication finish. No beta7
release ref has been published at this checkpoint. The existing community
snapshot `release/0.1.0-beta6` remains fixed at
`0789f8af3ce4e6e741247a308335150366e30f7c`. No older release ref may move.
Fixed-branch distribution is not a GitHub prerelease/tag or MELPA acceptance.

## Included changes

- PR105 protects renderer edits from before/after-change hooks that switch
  buffers, with native-hook execution and error behavior preserved. Guards
  clean up on unwind. This does not undo hook side effects or guarantee general
  reentrant transactions. The archived handoff records exact review, 452 ERT
  and thirteen passing hosted checks; PR107 adds real terminal regression.
- PR109 adds multiple fill-width columns without changing single-fill behavior;
  the catalog divides spare width between Name and Description. Its reviewed
  head, tested merge and integration `bf369525dacc1efdc87f0bacbaef2dbd94775ec2`
  share tree `89703d5960c98460fde0cbd02928e6607bdf7aa7`. All eleven applicable
  checks passed, including the seven-runtime/package matrix, GTK and tmux.
- PR111 writes Unicode failure evidence as UTF-8, including when ASCII output
  is selected. Reviewed head, tested merge and integration
  `cb3f4f053bd2fc480df94104623eb7e63f411e7f` share tree
  `73d020fbcfc925ac4405b7da40488b4ccf026ae9`. All eleven applicable checks passed;
  local 455 ERT, strict compilation/checkdoc and terminal showcase passed.
- PR112 refits ordinary tables after native margin changes without rebuilding
  their windows or siblings. Selection/marks and margins survive. Independent
  review caught and resolved projection-quit cleanup; error/quit regression
  covers disposal. Local 457 ERT, strict compilation/checkdoc and native TTY
  margin shrink/restore plus actions and resize passed. Exact-head review
  5716821137 covers `86f0ff92dc877d1e765d0099f5a6a34ba5ed22ed`, tree
  `b675d9978709a7e275fdbfc15f4b29d361d1108c`. All thirteen hosted checks passed:
  CI 41106315158 (eight), GTK 41106315214, Linux/macOS tmux 41106315695 and
  movement 41106315252. Tested merge `7ad0613a9ef803cc19142fd55211cd2642a2f17f`
  and actual integration `e8cce3adbf6066954537dc4a2b4cb6fd736f73fd` have that
  same tree. No failing hosted check was bypassed.

## Terminal findings and limits

The additional local full `make tty-smoke` passed through graph, then failed
showcase phase 4 with invalid-subtree reflow and a native compiler warning.
That invocation remains a failure. Separate unchanged-baseline and reviewer
instrumented candidate showcases passed; no bounds/assertions were relaxed.

A later logging-only reproduction captured `display-buffer("*Warnings*")`
during phase 4, then the preview window displaying `*Warnings*` instead of its
owned buffer. Jobs/progress remained owned. The existing invalid-subtree reflow
path then disposed the session, preventing stream completion. Independent
review confirms expected ownership protection against external replacement.
This identifies the cause of that captured failure; it does not explain earlier
resize failures or establish a universal environment-only diagnosis.
With native compiler warnings logged but not displayed (`silent`), a separate
instrumented showcase passed. That controlled diagnostic run is not substituted
for an unmodified full-suite pass.

Input/tree delayed/disabled-reflow fault probes passed. Local client/hangup
probes could not start Emacs servers because Unix-socket creation returned
`Operation not permitted`; no local lifecycle pass is claimed for them.
Fresh hosted release checks must cover the supported matrix and these paths.
Popup viewport changes retain full reflow; native margin preservation is not
promised across full layout rebuilds or arbitrary external window replacement.

## Release validation and remaining gates

Beta7 passes 457 local ERT, strict byte compilation and checkdoc on Emacs 29.3.
The metadata smoke parses literal `0.1.0-beta7` and canonical `0.1.0beta7`.
The real recipe built and clean-installed on local Emacs 29.3 from
`0647ce52ee7d823df90365ed78584424d67f16d2`; public installed-client checks passed.
Build-tool Lisp files matched the pinned upstream blob hashes. Local archive
SHA256: `2500b8da13c770ef8b9436258caa8604bc102ef4a7bb2efbe586a573d886c290`.
Hosted release validation and exact-head independent review remain pending.
Earlier implementation checks are not release-head checks. The recipe
must build and clean-install the identical archive on Emacs 31.1 and 28.1 before
publishing the fixed beta7 ref. Physical Ghostty/iTerm2, GUI variants and human
paste/input-method/API feedback remain separate from hosted PTY/tmux/Xvfb tests.

MELPA's recipe checklist and CONTRIBUTING.org were checked on 2026-10-30:
public maintenance for at least one month and a human first/most thorough review
of AI-assisted code remain external gates. Approximately 2026-11-23 is the
earliest known time gate, not a maturity guarantee. No recipe was submitted.
Upstream package-lint was rechecked on 2026-10-30 and remains at
`1865be780a16098f972fef50a52b21ca6ee04df9`. Prior package-lint evidence retains
the redundant-`emacs` package-name warning; this is not a claim of a new or
warning-free package-lint result.

## Next work

1. Validate and publish beta7 after reviewed, passing PR112 integration,
   without moving earlier release refs. Record release-head checks and archive
   identity before announcing availability.
2. Prioritize concrete community failures and substantive application use.
   Preserve the twelve distinct demos and general-purpose lifecycle boundaries.
3. Continue investigating any reproducible resize failures; the captured
   warning-window replacement explains only that particular showcase episode.
4. Use the pinned XOB public snapshot/action assessment in
   [XOB-INTEGRATION.md](XOB-INTEGRATION.md) before building a live adapter.
   No user knowledge base has been executed or live adapter claimed.
5. Use retained [performance protocols](PERFORMANCE.md) to investigate measured
   bottlenecks. Existing samples do not establish uniform speedups or emulator
   paint latency. Region embedding, lazy trees and further table policies need
   concrete consumers.

Follow AGENTS.md: fresh remote heads/open PRs, independent coding-agent review,
passing checks and expected-head integration; no Sunday work or notifications.
