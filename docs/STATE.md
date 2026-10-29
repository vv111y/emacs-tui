# Project state

Updated 2026-10-28 (America/Toronto). This is the current handoff.
[STATE-HISTORY.md](STATE-HISTORY.md) and
[STATE-BETA4-TO-BETA5.md](STATE-BETA4-TO-BETA5.md) preserve prior checkpoints;
pending checks there apply to their own dates.

## Available community release

**0.1.0-beta5** is available from fixed `release/0.1.0-beta5` at
`7c601abbc925269dd67bb59341aaf1fb08319720`. The ref was created after reviewed,
passing integration and read back. README contains matching straight.el and
example-checkout instructions. Runtime installation excludes examples; clone
the same ref for the twelve gallery entries. Beta1–beta4 refs were not moved;
beta4 was read back at `f5d8a56ece025964d8a3db31ea07e1399d12150d`.

This snapshot packages Details pinning, horizontal preview reading, stale
named-action and repurposed-surface selection protection, native input
regressions and the community feedback guide. These were previously reviewed
main changes; publication makes them available together in a fixed beta.
This is an experimental branch, not a GitHub prerelease tag, stable API promise,
human usability result or MELPA acceptance.

## Release validation

PR [#96](https://github.com/vv111y/emacs-tui/pull/96) merged after independent
coding-agent re-review 5688217508 and all thirteen corrected-head checks passed.
Reviewed head `8495e9b7ff904410c67cba4db9f5b73f0f985ff2`, tested merge
`51bf07c4b4b608fb8ec82cb1b951259b56e737d7` and integrated release commit share
tree `9e9a4340dce19dad9afd0bdca4bace07dc0f96cc`.

- CI [40751309079](https://github.com/vv111y/emacs-tui/actions/runs/40751309079):
  eight jobs covering Linux Emacs 28.1/28.2/29.4/30.2/31.1, macOS 30.2/31.1
  and package build/installation.
- GTK [40751309072](https://github.com/vv111y/emacs-tui/actions/runs/40751309072).
- Linux/macOS tmux [40751309346](https://github.com/vv111y/emacs-tui/actions/runs/40751309346).
- Linux/macOS movement [40751309074](https://github.com/vv111y/emacs-tui/actions/runs/40751309074).

All 440 ERT, strict compilation and checkdoc passed locally on Emacs 29.3.
Hosted package job 123038421433 parsed literal `0.1.0-beta5` / canonical
`0.1.0beta5`, built the actual recipe from the tested merge and clean-installed
the identical archive on Emacs 31.1 and 28.1 with public API smoke checks.
Archive SHA256:
`c1f34746ae7a3f4ea9c9ba9ffb352d7c110e6407f49c8c05ed9e67fb5ea35f19`.

The first candidate failed package job 123004977604 in run 40741779165 because
CI still expected literal beta4. That head was not merged. The explicit CI
expectation was corrected to beta5; literal and parsed-version assertions were
retained. Independent re-review and the entire fresh matrix above passed before
integration. Earlier passing jobs were not substituted for corrected-head checks.

The preceding selection fix, PR #95, merged at `7c3cba5` after review 5686639716
and thirteen passing checks; its regression fails on the old runtime. PR #94
added feedback guidance/forms after review 5686040566 and eight passing jobs.
Their detailed evidence and prior feature integrations remain in the archive.

## Commit surface ownership follow-up

PR #97 integrated the release handoff at
`258ac39b8512e47c9f4444e34def3a7588e03f75` after independent review 5688336747
and all eight checks in CI 40752712645 passed. Reviewed head `9a4c1b22`,
tested merge `790af25f` and integration share tree
`c030d3093396d4673e35face1c803bd9d4d60721`.

A focused follow-up makes explicit commit reject an ordinary-window surface
that has been repurposed, matching selection and named-action ownership checks.
Previously an explicit session handle could still commit its old selected item
to the origin after the query or results window displayed an unrelated buffer.
The regression fails on the original runtime. With the check, neither callback
nor origin edit occurs; the unrelated window/text and live session are retained.
Existing successful commit and rollback behavior is preserved.

Local Emacs 29.3 passes all 441 ERT, strict compilation and checkdoc. The new
regression covers both query and result surface replacement. PR #98 merged at
`0ae9600c30e63b4f308df5b60dd395ea8bb6cf62` after independent review 5688907689
and all thirteen exact-head checks passed: CI 40759303665 (eight jobs), GTK
40759303705, tmux 40759304528 and movement 40759304088. Reviewed head
`c6ec703f`, tested merge `0886764b` and integration share tree
`f646adbf6528d0fd6e99ec2ea23c55d36695af65`. Local actual TTY marked-commit and
resize smoke also passed. Fixed beta5 remains unchanged.

## Cleanup failure isolation

PR [#99](https://github.com/vv111y/emacs-tui/pull/99) continues disposing later owned buffers when an
earlier buffer's kill hook signals an error or quit. It releases the origin
marker, then re-signals the first failure; provider cancellation and close
callbacks still run through the existing unwind cleanup. It does not bypass a
failing hook or force-kill its buffer, and does not claim recovery from window
or frame deletion errors or arbitrary nonlocal throws.

The existing provider-disposal regression previously checked only worker
cancellation. Strengthening it to require later buffers and the origin marker
to be released fails on the old runtime. An additional regression checks
first-error/quit preservation, continued disposal after a second failure and
exactly-once close callbacks. With the correction all 442 ERT,
strict compilation and checkdoc pass on local Emacs 29.3. The real 29.3 TTY
main smoke and 45-lifetime resource/isolation stress also pass. Independent
exact-head review 5689749991 found no remaining issues and independently ran
14 focused tests. Head `b83044be`, tree
`1432411307d0dbc29c659d0ffc7f620145cf61fe`, matches tested merge `c7407d74`
and integration `425a97ed95ad935eeea9d7c208b02f94398b155c`.

CI 40769765947 (eight jobs), GTK 40769765948, both tmux jobs in 40769765955
and Linux movement in 40769765949 passed. The original macOS movement job
123103485353 was cancelled with no runner and no steps; its logs are absent.
A targeted retry was requested without changing code or weakening checks.
Retry job 123129585259 acquired a runner and passed. All thirteen required
checks at the reviewed head passed before PR #99 merged. The real recipe built
from tested merge `c7407d74` and clean-installed on Emacs 31.1 and 28.1, with
public API smoke checks. This correction is on main, not in fixed beta5.
No human or physical-emulator coverage follows.

## Maximization ownership follow-up

PR #100 integrated the cleanup handoff at
`4d7e20a7374de6ab13d18b1db8204856d756e4dc` after independent review 5690350643
and all eight CI 40777682790 jobs passed. Reviewed head `7072bb99`, tested
merge `a981e238` and integration share tree
`425ce70c2e048957a3418f703077e6c703d0317f`.

PR #101 checks surface ownership before toggling maximization,
matching explicit layout selection and view navigation. Previously a retained
session handle could toggle maximization on a repurposed window, mutate its
state and close the session through refresh. The regression fails on the old
runtime and covers both maximize and restore: the corrected command signals
user-error, retains the live session and maximization state, does not run the
close callback, and preserves foreign text, point and horizontal scrolling.

Local Emacs 29.3 passes all 443 ERT, strict compilation and checkdoc. The real
TTY persistent-mount smoke also passes. Integration evidence is recorded below.
This correction is not in fixed beta5; no human
or physical-emulator validation is claimed. Continue with concrete beta issues
and the external readiness gates below.

## Projection buffer isolation candidate

PR [#101](https://github.com/vv111y/emacs-tui/pull/101) merged maximization
ownership protection at `c4ca3745e8c40813395f5ac3242b51434b432991`, after
independent exact-head review 5690799225 and all thirteen checks passed:
CI 40783953683 (eight jobs), GTK 40783953657, tmux 40783953666 and movement
40783953661. Reviewed head `bc4a8034`, tested merge `96917470` and integration
share tree `c4e1562ade9a83c0d3443b96010a07e334bfe29a`. Local validation was
443 ERT, strict compilation/checkdoc and real persistent-mount TTY smoke.
The command now rejects repurposed windows before changing maximization state
or closing the session. This is on main and absent from fixed beta5.

The next candidate isolates rendering from application table projections that
change the current buffer, including callbacks that close their session.
Previously, rendering continued in the callback's current buffer and could
replace unrelated text. Content preparation now has its own buffer context;
the renderer checks that the target buffer and session remain live, then
explicitly re-enters the owned buffer before writing. A closed target raises
user-error before any display writes. This is a focused buffer/lifetime fix,
not a general transaction across reentrant application updates or provider
generations. Application projections should still avoid modifying UI state.

Two regressions exercise buffer switching with a live target and session closure.
Both fail on the original runtime; local Emacs 29.3 passes 445 ERT, strict
compilation and checkdoc. The actual TTY table/action/resize smoke also passes.
Separate coding-agent review found no issues and independently passed 21
focused render/table tests, with both regressions failing against the original
runtime. Exact remote-head review and fresh hosted checks remain required before
integration. No human or physical-emulator coverage is claimed. Fixed release
refs remain unchanged.

## Capabilities and boundaries to preserve

General-purpose, terminal-first toolkit. Persistent applications, embedded
panels and ephemeral workflows share views, layouts, input, actions and resource
lifetimes. Applications own data, transactions and persistence. Query input,
origin markers and commit-then-close remain optional policies. Core has no Org
or graph dependency; XOB is an intended consumer.

List/table/tree/text/native-input views support selection, marks, queries, named
actions, layout changes and cancellable providers. Floating popups preserve the
source window/buffer and typing focus, with eight requested positions, tracked
anchors, source-focused scrolling and live dimension changes. Native bounds
clamp geometry; there is no automatic collision avoidance. Ordinary-window
presentations support Emacs 28.1+; popups require graphical or advertised native
TTY child frames. The CAPF frontend is opt-in and preserves native completion
styles, provider callbacks and undo.

Beta5 multi-popup keys: C-c 1/2/3 toggles Objects/Details/Keys; C-c 0 hides all if
any are visible, otherwise shows all. C-c p 1/2/3 moves each independently;
C-c [ / ] scrolls Details; C-c C-e expands/shrinks it. Position/size preferences
survive hide/show. C-c C-d pins/releases Details; C-c < / > pans it horizontally.
Read [DEMOS.md](DEMOS.md) for all application tours.
Repositioning during active reflow rejects before mutation (#83); the additive
`emacs-tui-resize-popup` API (#84) retains the same native frame. Oversized
resize/recovery is checked on GTK/Linux/macOS (#85). Complete reviews, commit
identities and CI evidence for these units remain in the archived checkpoint.

## Next work and external gates

1. Collect beta feedback and address concrete application defects before
   expanding scope. Beta5 includes pinning and horizontal reading; keep release
   refs fixed; future examples must state which snapshot contains their APIs.
2. Exercise physical Ghostty/iTerm2, GUI display variants, paste and input
   methods with human use. Hosted PTYs, tmux and GTK/Xvfb do not establish those
   combinations or human visual/usability review.
3. Implement an XOB adapter only against a concrete public snapshot/action
   contract. [XOB-INTEGRATION.md](XOB-INTEGRATION.md) records the pinned source
   audit; no live XOB adapter or user knowledge-base execution is claimed.
4. Measure new bottlenecks using [PERFORMANCE.md](PERFORMANCE.md) and checked-in
   raw protocols before optimizing; keep provider/display costs separate.
5. MELPA guidance rechecked 2026-10-28 still requires at least one month of public
   maintenance and substantive human review. Approximately 2026-11-23 is the
   earliest known time gate, not a maturity guarantee. No recipe is submitted.
   [MELPA.md](MELPA.md) and [API-STABILITY.md](API-STABILITY.md) retain the gates.

Latest upstream package-lint remains `1865be780a16098f972fef50a52b21ca6ee04df9`.
A fresh beta5 run on Emacs 29.3 reports only the disclosed redundant-`emacs`
name warning; helpers are clean. It exits nonzero for that warning and is not
reported as warning-free. The first attempt used an incomplete local lint
copy and failed to load its data files; rerunning the verified complete lint
checkout from the package root produced the result above.

Follow AGENTS.md: inspect remote heads/open PRs, respect recent draft ownership,
use independent coding-agent review and passing exact-head checks before merge,
and never overwrite intervening work. No Sunday work or notifications in Toronto.
