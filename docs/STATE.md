# Project state

Updated 2026-10-29 (America/Toronto). This is the current handoff.
[STATE-BETA5-TO-BETA6.md](STATE-BETA5-TO-BETA6.md) preserves the preceding
checkpoint, including beta5 publication, PR98/99/100/101 evidence and the
then-pending projection patch. Earlier archives remain linked there.

## Available community release

Version `0.1.0-beta6` packages the reviewed post-beta5 corrections below.
README, API policy, demo/feedback guides, bug-report placeholder and the CI
literal-version expectation match this version. The twelve demos, hotkeys and
public signatures are unchanged. Runtime installation still excludes examples;
use a matching source checkout. This is an experimental beta, not stable API,
human usability validation or MELPA acceptance.

Fixed `release/0.1.0-beta6` is available at
`0789f8af3ce4e6e741247a308335150366e30f7c`. The branch was created after
reviewed, passing PR [#103](https://github.com/vv111y/emacs-tui/pull/103)
integration and read back. Its tree matches the tested release head and merge.
The README straight.el recipe and matching source-checkout instructions now
resolve to this published snapshot. No prior release ref was moved; beta5 was
read back at `7c601abbc925269dd67bb59341aaf1fb08319720`.

This is fixed-branch distribution, not a GitHub prerelease/tag or MELPA package.
GitHub prerelease/tag creation is not exposed by the connected tools. Existing
release refs must remain fixed; subsequent corrections belong on main and in
a future explicitly versioned snapshot.

## Reviewed corrections included

- PR98 rejects explicit commit after its query/results surface is repurposed,
  before callback invocation or origin edits. PR99 continues disposal of later
  owned buffers and the origin marker after a kill hook errors/quits, then
  re-signals the first failure; it does not force-kill the failing buffer or
  bypass hooks. Their exact review, merge and thirteen-check evidence is in
  the preceding checkpoint. They are already on main and absent from beta5.
- PR [#101](https://github.com/vv111y/emacs-tui/pull/101) rejects maximize/restore
  after a surface is repurposed, before changing state or closing the session.
  Independent review 5690799225, 443 local ERT, strict compilation/checkdoc and
  actual TTY persistent-mount smoke passed. All thirteen exact-head checks
  passed: CI 40783953683 (eight), GTK 40783953657, tmux 40783953666 and movement
  40783953661. Head `bc4a8034`, tested merge `96917470` and integration
  `c4ca3745e8c40813395f5ac3242b51434b432991` share tree
  `c4e1562ade9a83c0d3443b96010a07e334bfe29a`.
- PR [#102](https://github.com/vv111y/emacs-tui/pull/102) prevents a table
  projection's current-buffer change from redirecting rendering into unrelated
  text. Content preparation has its own buffer context; a live target/session
  check and explicit buffer re-entry precede writes. Closing during projection
  raises user-error. Both new regressions fail on the original runtime.
  Independent exact-head review 5691276683 passed 21 focused tests; local
  445 ERT, strict compilation/checkdoc and actual TTY table/action/resize smoke
  passed. All thirteen checks passed: CI 40791661051 (eight), GTK 40791661193,
  tmux 40791661169 and movement 40791661168. Head `75ee63d7`, tested merge
  `6d297122` and integration `492262e0381e7043ddaa2c925bfc26588d1b4eb7` share
  tree `9ff639ad774fbad5406ada3a588a7c3238fdab9f`.

Projection isolation is not a general transaction across reentrant updates or
provider generations. Pure projection/comparator/child-accessor/availability
callbacks must return promptly and avoid UI side effects, as the API policy
requires. No human or physical terminal-emulator coverage follows from these
regressions or hosted checks.

## Release validation and remaining gates

The beta6 release passes all 445 ERT, warning-free byte compilation and
checkdoc on local Emacs 29.3. Package metadata smoke verifies literal
`0.1.0-beta6` and canonical `0.1.0beta6`; CI's expectation matches. Independent
exact-head review 5691325295 found no remaining issues. Head
`f4b168b171b04a6a237fc2ba98781a344aea43f3`, tested merge
`02973f20bd5c30c54d9974ddff57da1f974cce25` and published integration share tree
`a7f40b82549b6b9564422c6b89660b4e8abe2b1b`.

All thirteen release-head checks passed before integration:

- CI [40792486963](https://github.com/vv111y/emacs-tui/actions/runs/40792486963):
  eight jobs, Linux Emacs 28.1/28.2/29.4/30.2/31.1, macOS 30.2/31.1 and package.
- GTK [40792486962](https://github.com/vv111y/emacs-tui/actions/runs/40792486962).
- Linux/macOS tmux [40792486944](https://github.com/vv111y/emacs-tui/actions/runs/40792486944).
- Linux/macOS movement [40792486928](https://github.com/vv111y/emacs-tui/actions/runs/40792486928).

Package job 123180835780 built the real candidate recipe from the tested merge
and clean-installed the identical archive on Emacs 31.1 and 28.1 with public API
smoke checks. Archive SHA256:
`a91c5fee8b553b0e6de5cec5c19c86ffac0a753dd65a5c5d297e9a33d315ced8`.
No earlier development jobs were substituted for release-head checks.

Current upstream package-lint `1865be780a16098f972fef50a52b21ca6ee04df9`
was verified on 2026-10-28. A fresh beta6 run reports only the disclosed
redundant-`emacs` package-name warning; helpers are clean. Its exit status is 1,
not warning-free. Current MELPA CONTRIBUTING.org and recipe PR checklist still
require public maintenance for at least one month and a human author as the
first and most thorough reviewer of AI-assisted code. Approximately 2026-11-23
is the earliest known time gate, not a maturity guarantee. No recipe submitted.

## Render modification-hook isolation candidate

PR104 integrated the beta6 publication handoff at
`aef5a1b27c09883924b9c11d18de99ecbc46adb8` after exact-head independent review
5693540620 and all eight CI 40827163935 jobs passed. Reviewed head `b185867c`
and tested merge `064c2ae8` share tree `ead77f7020a5d67a6458d9f0e2cfaf33790c4aa8`.

A follow-up to PR102 protects the erase/insert phase from native modification
hooks that change the current buffer. Previously an after-change hook could
redirect the next insertion into unrelated text or prevent overlay rollback.
Each edit now has its own saved buffer context, including on failure, and
rendering rechecks target/session liveness before continuing. Independent review
found that this alone did not protect before-change hooks: the native edit
resumes before the saved context unwinds. A temporary final before-change guard
now checks liveness and restores the target before that native edit resumes.
The guard is removed on unwind; native hooks and their error handling still run.

Regressions cover deletion/insertion stages, local and inherited global hooks,
exact hook-error preservation with text/selection rollback, session closure,
self-removing/replaced hooks and guard cleanup. All six buffer-switch regressions fail on beta6; the before-change cases
also fail on the initial partial fix. Final local Emacs 29.3 validation passes
452 ERT, strict byte compilation and checkdoc. Actual TTY table/action/resize
smoke also passes. Independent coding-agent re-review passed all nine focused render tests; it
resolved both the before-change redirection and hook-replacement findings.
Exact remote-head review and fresh hosted checks remain required before
integration.

Native change-group cleanup can report a deleted-buffer error if a hook kills
the render buffer; no particular error subtype or rollback of a killed buffer
is promised. The fix prevents subsequent toolkit text/display writes into the
foreign buffer. It does not undo effects made by hooks themselves or Emacs's
native hook-list clearing after an error. In particular, a hook that switches
buffers then errors may cause Emacs to clear the foreign buffer's hook list.
This is focused rendering protection, not arbitrary hook transaction isolation.
Fixed beta6 remains unchanged.

## Next work and boundaries

1. Keep beta6 available for community testing and prioritize reproducible bug
   reports. Preserve this fixed snapshot while reviewing future main changes.
2. Prioritize concrete community application feedback. Human use must exercise
   physical Ghostty/iTerm2, graphical variants, paste/input methods and API
   ergonomics; hosted PTYs/tmux and GTK/Xvfb do not establish these environments.
3. Use a concrete public XOB snapshot/action contract before implementing a live
   adapter. [XOB-INTEGRATION.md](XOB-INTEGRATION.md) records the source audit;
   no user knowledge base has been executed and no live adapter is claimed.
4. Use [PERFORMANCE.md](PERFORMANCE.md) and retained raw protocols to measure
   actual bottlenecks, keeping provider and display costs separate.
5. Preserve general-purpose persistent, embedded and ephemeral policies. Query
   input, origin and commit-close are optional; applications own data/effects.
   Popup siblings remain independent sessions with eight requested positions,
   native clamping and no automatic collision avoidance. Region embedding,
   lazy trees and adaptive table widths require concrete consumers.

Follow AGENTS.md: inspect remote heads/open PRs, respect recent draft claims,
use independent coding-agent review and passing checks before integration,
never overwrite intervening work, and perform no Sunday work/notifications.
