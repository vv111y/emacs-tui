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
The last recorded run against beta4 runtime files on Emacs 29.3 reports only the disclosed
redundant-`emacs` name warning; helpers are clean. It exits nonzero for that
warning and is not reported as warning-free. The initial local invocation used
the lint checkout as cwd and could not resolve helper main-file metadata;
rerunning from the package root resolved those invocation errors.

Follow AGENTS.md: inspect remote heads/open PRs, respect recent draft ownership,
use independent coding-agent review and passing exact-head checks before merge,
and never overwrite intervening work. No Sunday work or notifications in Toronto.
