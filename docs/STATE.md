# Project state

Updated 2026-10-27 (America/Toronto). This is the current handoff.
[STATE-HISTORY.md](STATE-HISTORY.md) preserves prior checkpoints verbatim;
statements about pending checks there apply to their own dates.

## Available community release

**0.1.0-beta4** is available from the fixed `release/0.1.0-beta4` branch at
`f5d8a56ece025964d8a3db31ea07e1399d12150d`. The ref was created after reviewed,
passing integration and read back. README contains the file-filtered straight.el
recipe. Clone that ref for matching examples; the installed runtime excludes
examples. All twelve gallery entries, the validated settings form and three
independent floating panels are included. Beta1–beta3 refs were not moved.
This is an experimental fixed branch, not a GitHub prerelease tag, stable API
promise or MELPA acceptance.

PR [#86](https://github.com/vv111y/emacs-tui/pull/86) has independent review
5676197886. Reviewed `bb3be274`, tested merge `b54240aa` and integrated commit
share tree `e0021f70696c1a5e9e2e46a37b262ac5cf31b877`. All thirteen checks passed:
CI [40607249360](https://github.com/vv111y/emacs-tui/actions/runs/40607249360)
(eight jobs), GTK [40607249371](https://github.com/vv111y/emacs-tui/actions/runs/40607249371),
Linux/macOS tmux [40607249445](https://github.com/vv111y/emacs-tui/actions/runs/40607249445)
and movement comparison [40607249352](https://github.com/vv111y/emacs-tui/actions/runs/40607249352).
All 424 ERT passed. Package job 122549710552 parsed literal `0.1.0-beta4` /
canonical `0.1.0beta4`, built the actual recipe and clean-installed the same
archive on 31.1 and 28.1, including resize API provenance. Local Emacs 29.3 also
passed strict compilation/checkdoc, real recipe build and clean installation.

## Current main work

PR [#87](https://github.com/vv111y/emacs-tui/pull/87) adds C-c C-d to pin visible
Details to one object while browsing Objects; release follows current selection.
The [pinned] header is explicit, hide/show retains the held object, and a fresh
enable resets it. This is example-owned policy over existing public updates.
Failed/stale publication closes only original Details without installing a new
pin. **This later command is absent from fixed beta4.**

Reviewed head `074f4b6834879fe8fb01f739e6541db92a16027e`, tree
`505942e5f2ed832ccdbf89b4374c7880b8cf499c`, has independent review 5676255941.
Local 428 ERT, strict compilation/checkdoc, shared native-fixture compilation
and diffcheck pass. Four new behavioral tests cover retention/release, invalid
contexts, failed release and stale callbacks. Actual GTK and Linux/macOS tmux
journeys passed: scroll before pin, reading position while browsing, rendered
text, reopening/release, same child and source/sibling isolation. PR87 merged at
`158b4bd85e13a084c34530fbda0c0f8a81c5650f` after all eleven final checks passed:
CI [40608047489](https://github.com/vv111y/emacs-tui/actions/runs/40608047489)
(eight jobs), GTK [40608047656](https://github.com/vv111y/emacs-tui/actions/runs/40608047656)
and Linux/macOS tmux [40608047562](https://github.com/vv111y/emacs-tui/actions/runs/40608047562).
Reviewed head and tested merge `2720464e` share the integrated tree above.

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

Beta4 multi-popup keys: C-c 1/2/3 toggles Objects/Details/Keys; C-c 0 hides all if
any are visible, otherwise shows all. C-c p 1/2/3 moves each independently;
C-c [ / ] scrolls Details; C-c C-e expands/shrinks it. Position/size preferences
survive hide/show. Read [DEMOS.md](DEMOS.md) for all application tours.
Repositioning during active reflow rejects before mutation (#83); the additive
`emacs-tui-resize-popup` API (#84) retains the same native frame. Oversized
resize/recovery is checked on GTK/Linux/macOS (#85). Complete reviews, commit
identities and CI evidence for these units remain in the archived checkpoint.

## Next work and external gates

1. Collect beta feedback and address concrete application defects before
   expanding scope. Pinning is integrated on main; keep release
   refs fixed; future examples must state which snapshot contains their APIs.
2. Exercise physical Ghostty/iTerm2, GUI display variants, paste and input
   methods with human use. Hosted PTYs, tmux and GTK/Xvfb do not establish those
   combinations or human visual/usability review.
3. Implement an XOB adapter only against a concrete public snapshot/action
   contract. [XOB-INTEGRATION.md](XOB-INTEGRATION.md) records the pinned source
   audit; no live XOB adapter or user knowledge-base execution is claimed.
4. Measure new bottlenecks using [PERFORMANCE.md](PERFORMANCE.md) and checked-in
   raw protocols before optimizing; keep provider/display costs separate.
5. MELPA guidance rechecked 2026-10-27 still requires at least one month of public
   maintenance and substantive human review. Approximately 2026-11-23 is the
   earliest known time gate, not a maturity guarantee. No recipe is submitted.
   [MELPA.md](MELPA.md) and [API-STABILITY.md](API-STABILITY.md) retain the gates.

Latest upstream package-lint remains `1865be780a16098f972fef50a52b21ca6ee04df9`.
A fresh run against beta4 runtime files on Emacs 29.3 reports only the disclosed
redundant-`emacs` name warning; helpers are clean. It exits nonzero for that
warning and is not reported as warning-free. The initial local invocation used
the lint checkout as cwd and could not resolve helper main-file metadata;
rerunning from the package root resolved those invocation errors.

Follow AGENTS.md: inspect remote heads/open PRs, respect recent draft ownership,
use independent coding-agent review and passing exact-head checks before merge,
and never overwrite intervening work. No Sunday work or notifications in Toronto.
