# Project state

Updated 2026-10-30 (America/Toronto). This is the current handoff.
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

## Render modification-hook isolation on main

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
PR [#105](https://github.com/vv111y/emacs-tui/pull/105) was integrated at
`c5a29ac888e5147e4ad65cd5173dc66de55a4980` after exact-head review 5693653664
and all thirteen checks passed: CI 40828538787 (eight), GTK 40828538774,
Linux/macOS tmux 40828538781 and movement 40828538789. Reviewed head
`0eed430c1b0975d190dd54a669d6e615c6946c7f`, tested merge
`65c4b6361658ba51cd2140cbe3649a994ca7aeee` and actual integration share tree
`23d90fb8326ea1cea13e3423ec2cc6df7052ce57`. This correction is on main,
not the fixed beta6 snapshot.

Native change-group cleanup can report a deleted-buffer error if a hook kills
the render buffer; no particular error subtype or rollback of a killed buffer
is promised. The fix prevents subsequent toolkit text/display writes into the
foreign buffer. It does not undo effects made by hooks themselves or Emacs's
native hook-list clearing after an error. In particular, a hook that switches
buffers then errors may cause Emacs to clear the foreign buffer's hook list.
This is focused rendering protection, not arbitrary hook transaction isolation.
Fixed beta6 remains unchanged.

## Retained render-hook measurements

[Filtering measurements](../bench/results/2026-10-29-render-hooks/README.md)
retain both complete reports and a reproducibility auditor: 140 records,
including 120 measured commands and 20 warmups. The same native PTY host ran
beta6 then PR105 with freshly compiled Emacs 29.3 libraries at 100/10,000 rows.
The auditor verifies matching fixtures/host and every pooled/per-command
quantile. Small-list insertion tails worsen while deletion tails improve;
10k medians are close. This small sequential sample does not establish a
uniform speedup, negligible overhead or a latency bound. Only the normal
filtering path is measured, with no custom modification hooks. Native popup,
31.1/macOS, emulator paint and retained-heap claims are outside this evidence.

## Interactive render-hook regression on main

PR106 integrated the retained measurement pair and the PR105 handoff at
`b0ebda428a33e46bd08c057c81b3a188dacb2ce2` after independent exact-head review
5693714453 and all eight CI 40829360637 jobs passed. Reviewed head `dc6f04ce`,
tested merge `6262506a` and integration share tree
`0e513fa0843924fc4d3cef13be42eed2d99a7256`.

The table terminal journey now exercises eight rendering updates through
Emacs keyboard macros: before/after-change hooks at deletion/insertion,
each succeeding or signaling an error after switching to the unrelated host.
It checks target display visibility, selection/marks, exact error and text
rollback, host text/point/modified state, and then the existing two resizes,
actions and disposal. These are native command/redisplay checks inside a real
PTY; the commands are keyboard macros, not injected physical keyboard bytes.
No physical emulator paint or human interaction is claimed.

Local Emacs 29.3 passes the extended real-TTY journey and strict fixture byte
compilation. The same fixture fails on beta6 at the first missing rendered row,
so it detects the original redirection. The unchanged batch suite remains at
452 ERT; it is not recounted as new tests. PR [#107](https://github.com/vv111y/emacs-tui/pull/107) integrated this
validation-only change at `331a6038297da622877d7e91bd7c56c7682e48ab` after
independent exact-head review 5693789132 and all eleven jobs passed: CI
40830345155 (eight), GTK 40830345144 and Linux/macOS tmux 40830345156.
Reviewed head `51f807eb6c015517b8d2d39750523ac48ee168f5`, tested merge
`579a0daea5bbd02ee854bf91d33ce8522a4de441` and actual integration share tree
`7f4fc8c553e492327c6c5783ad7dfa4b1202d218`. The ordinary-window fixture runs
in the supported-version CI matrix, including minimum Emacs 28.1 and
Linux/macOS 31.1. GTK and tmux passing results cover their existing journeys;
the eight new table-hook cases are not part of those separate fixtures.
Runtime code and the fixed beta6 snapshot are unchanged.

## Equal-share table columns on main

PR108 integrated the terminal validation handoff at
`6d3ecf1a0ebdcc1ea6ab62a2d71389ae963ffe65` after independent review 5697342263
and all eight CI 40870065418 jobs passed. Reviewed and tested tree:
`afda627b3b361f3f9696cf9fa3ad7720bb189f0d`.

The catalog now puts Name and Description in two fill columns beside fixed
Type and KiB columns. Fill columns divide the remaining display width equally;
earlier columns receive remainders and each keeps at least one display column.
Fixed-only and single-fill behavior remains unchanged, and descriptions are
never mutated. Weighted widths and automatic content measurement are not added.

Local Emacs 29.3 passes 454 ERT, strict compilation/checkdoc and
actual TTY table commands, rightmost numeric payload visibility, hook cases,
selection/marks and resizing from 120x40 to 90x30 to 140x45. The fixture uses
two fill columns. Independent review passed 21 table tests and extra three-fill
allocation checks, with no substantive API/allocation findings. Its first TTY
run failed the existing resize-growth assertion; the second passed. That
intermittent failure remains an investigation item, not an ignored success.
The broader showcase reached its later stream phase but failed to settle on
both this candidate and unchanged main in this local runtime (warning buffers
and reflow disposal appeared); neither run is counted as passing showcase
coverage. All eleven hosted checks passed without reruns or waived assertions: CI
40977037294 (eight), GTK 40977037331 and Linux/macOS tmux 40977037308.
Logs on minimum 28.1, 29.4 and Linux/macOS 31.1 confirm 454 ERT, table resizing
and complete showcase journeys. Six additional local diagnostic table runs,
retaining the resize assertion, passed; they did not establish the earlier
failure's cause. Local failures remain recorded above, not reclassified as passes.

Independent exact-head review 5706516504 and integration assessment 5708603916
supported PR [#109](https://github.com/vv111y/emacs-tui/pull/109), merged at
`bf369525dacc1efdc87f0bacbaef2dbd94775ec2`. Reviewed head
`e63dfe8c2a4a284a91fcc312fcb26ae8217f0015`, tested merge
`adeef55baf9eb5d4ffac0590a323700a222b7f5d` and integration share tree
`89703d5960c98460fde0cbd02928e6607bdf7aa7`.
Fixed beta6 does not include multiple fill columns. Investigate a repeat local
resize failure with recorded geometry before changing assertions; hosted PTY
success is not physical-emulator or human validation.

## Showcase failure-report encoding on main

PR110 integrated the equal-share validation handoff at
`929601dac5584fcb1222c6d5127b7d3ec5fdbc2a` after exact-head review 5708615247
and all eight CI 41011395960 jobs passed. Its tested merge and reviewed tree
match `1588e6967dd1a06afa54aedb4c924b12d5dcaccb`.

The prior local showcase transcript shows native-compiler warnings followed by
an encoding-selection prompt while the failure reporter writes diagnostics.
The reporter now explicitly writes UTF-8, following the existing completion
and GUI fixtures. A regression with ASCII output selected verifies Unicode
error/warning preservation, no encoding prompt, and exit status 1. It fails
against the original writer through lossy replacement characters and passes
with the fix. The test scopes fixture startup-hook registration locally.

Local Emacs 29.3 passes 455 ERT, strict runtime/example compilation and
checkdoc. The complete actual TTY showcase also passed on this run, including
catalog actions and streaming failure/recovery. This does not establish the
cause of earlier intermittent resize or stream failures: the change affects
only diagnostic writing after failure, not successful rendering or polling.
PR [#111](https://github.com/vv111y/emacs-tui/pull/111) integrated at
`cb3f4f053bd2fc480df94104623eb7e63f411e7f` after exact-head review 5711964056
and all eleven checks passed: CI 41052522423 (eight), GTK 41052555643 and
Linux/macOS tmux 41052522093. Reviewed head `dfde8d49`, tested merge
`8bfd6032` and actual integration share tree
`73d020fbcfc925ac4405b7da40488b4ccf026ae9`. No runtime API or fixed beta6 ref
changes.

## Native table-width candidate

While investigating resize coverage, a separate deterministic case reproduced:
changing native window margins leaves outer edges unchanged, so the existing
geometry cache skips table rendering. A two-pane batch example retained a
38-column row in a 31-column text area. This does not establish the cause of
the earlier intermittent frame-resize failure.

The candidate includes usable table widths in the geometry signature. In
ordinary/embedded windows, a change confined to those widths redraws only
affected visible tables in their existing windows, preserving native margins
and untouched sibling content. Outer layout
changes retain the existing reflow/disposal path. There is no new public API.
The regression changes and removes margins while retaining selection/marks,
window identity, unchanged outer edges and an untouched sibling preview; an
unchanged second hook call performs no further rendering. It fails on old main.
Final local Emacs 29.3 validation passes 457 ERT, strict compilation/checkdoc
and the real-TTY table journey with native margin shrink/restore hook delivery, followed by the
existing two resizes, modification-hook cases and actions. The fixture never
calls explicit refresh or the toolkit window hook for the margin phases.
Independent review found that a projection quit needed the same unwind cleanup
as full reflow. The corrected path now disposes on unsuccessful rendering and
has an error/quit regression. Independent re-review passes both focused tests.
The same TTY margin fixture fails the margin-preservation assertion against
the old runtime; it is not counted as an old-runtime width-timeout reproduction.
Fresh hosted checks and exact-head review gate integration.
An additional full local `make tty-smoke` passed through the graph journey but
failed showcase phase 4 with an invalid-subtree reflow message and a native
compiler warning. A separate unchanged PR111 showcase run passed; one reviewer
diagnostic candidate run also passed without capturing an invalid subtree.
These results leave the earlier intermittent issue unresolved. The failed
full-suite invocation is not a pass, and no assertions or polling bounds were
waived. The static review found no demonstrated connection to the new
table-only rendering branch; this is not a proven environment-only diagnosis.
Separate delayed/disabled-reflow fault probes passed for input and tree.
Terminal-client and terminal-hangup probes could not start their Emacs servers:
the local Unix-socket creation returned `Operation not permitted`. They provide
no local lifecycle pass; hosted checks remain required for those paths.
Popup viewport changes retain their existing full-reflow path. No claim of
physical-emulator validation or general preservation of window decorations
across full layout rebuilds is made; fixed beta6 remains unchanged.

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
