# Project state

Updated 2026-10-28 (America/Toronto). This is the current handoff.
[STATE-BETA5-TO-BETA6.md](STATE-BETA5-TO-BETA6.md) preserves the preceding
checkpoint, including beta5 publication, PR98/99/100/101 evidence and the
then-pending projection patch. Earlier archives remain linked there.

## Beta6 release candidate

Version `0.1.0-beta6` packages the reviewed post-beta5 corrections below.
README, API policy, demo/feedback guides, bug-report placeholder and the CI
literal-version expectation match this version. The twelve demos, hotkeys and
public signatures are unchanged. Runtime installation still excludes examples;
use a matching source checkout. This is an experimental beta, not stable API,
human usability validation or MELPA acceptance.

Publish a new fixed `release/0.1.0-beta6` branch only after this release PR has
independent exact-head review and all thirteen fresh checks pass. Read back the
release ref and integrated tree. The instructions are prepared for that ref;
this checkpoint does not claim it has already been created. No existing release
refs may move. The last verified community release is fixed beta5 at
`7c601abbc925269dd67bb59341aaf1fb08319720`; beta4 is fixed at
`f5d8a56ece025964d8a3db31ea07e1399d12150d`. GitHub prerelease/tag creation is
not exposed by the connected tools; the fixed branch is the available release
transport. Do not describe it as a tag or claim MELPA submission.

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

The beta6 candidate passes all 445 ERT, warning-free byte compilation and
checkdoc on local Emacs 29.3. Package metadata smoke verifies literal
`0.1.0-beta6` and canonical `0.1.0beta6`; CI's expectation matches. Separate
release review and fresh hosted package-build/clean-install/native checks still
gate integration and publication; passing prior development jobs do not replace
release-head validation.

Current upstream package-lint `1865be780a16098f972fef50a52b21ca6ee04df9`
was verified on 2026-10-28. A fresh beta6 run reports only the disclosed
redundant-`emacs` package-name warning; helpers are clean. Its exit status is 1,
not warning-free. Current MELPA CONTRIBUTING.org and recipe PR checklist still
require public maintenance for at least one month and a human author as the
first and most thorough reviewer of AI-assisted code. Approximately 2026-11-23
is the earliest known time gate, not a maturity guarantee. No recipe submitted.

## Next work and boundaries

1. Complete release-head review/checks, create and read back the fixed beta6
   ref, then record publication evidence. Keep prior release refs fixed.
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
