# Project state

Updated 2026-10-27. This is the current handoff. Earlier checkpoints through
initial beta3 preparation are preserved byte-for-byte in
[STATE-HISTORY.md](STATE-HISTORY.md). Their pending checks describe their own
dates, not current blockers; later intermediate edits remain in Git history.

## Native sibling-popup departure candidate — 2026-10-27

The shared real-frame journey now leaves the source through both buffer and
window commands, checks that all three old frames/view buffers/anchor markers
are released and that popup command routing is removed, edits the destination,
then returns and explicitly recreates the panels with retained selection. Source
text, point and undo are checked. This tests existing lifecycle behavior and adds
no production API. Local Emacs29.3 passes415 ERT, strict compile/checkdoc and
strict shared/GUI/TTY fixture compilation; positive native hosted checks and
independent review remain integration gates. The local29.3 runtime cannot prove
native terminal child-frame behavior.

## Integrated native multi-popup gallery launch — 2026-10-27

PR #77 merged at a32e3f64b8ada0007a71fc8b131f7f9b33095fec after independent
exact-head review5672728137 and all eleven checks passed. Reviewed head a53067a
and tested merge26a5c04 share treefebd48d4d8cbd2257028ebb716a7b6b29ca92d71.
The shared journey selects the gallery entry, reads its tour with RET and
launches with C-c C-o, then asserts chooser disposal and the three real sibling
frames. A failed tour command releases the chooser; the regression uses a real
ordinary-window gallery. Local/hosted415 ERT and strict compile/checkdoc pass.
CI40565040105 has eight successful jobs; GTK40565039863 and Linux/macOS tmux
40565039877 explicitly report gallery launch. Package job122403958392 installs
the same archive on31.1/28.1; SHA256
c3047a0ce4a8c1feb1ab8a2b034836a80dd7c96714e62fb2d3522fede2600ece.

## Integrated multi-popup demo — 2026-10-27

PR #75 merged at47070b0b9ea1c975ab9aef28dab6cd1e38ead73b after independent
review5671981968 and all eleven exact-head checks passed. The reviewed head
94682cf6b372da8db94733426958589d6af4320d and tested merge
f7d186dcd7766e9dc43407a8ca1f04120490f3e1 share integrated tree
9fb17a2b9de8e5afb5b8da46ec08c49e7e51a25f.

The owner requested multiple simultaneous floating child frames, with keys for
each panel and the complete group. The new make multi-popup-demo target and
gallery entry compose three existing popup sessions without adding core API.
C-c 1/2/3 toggles Objects/Details/Keys; C-c 0 hides all if any is visible,
otherwise shows all. Selection survives hidden panels; reopening recreates
owned surfaces. M-n/p browses, C-c C-p moves Objects independently, C-g hides,
and C-c C-q removes the buffer-local bindings. Source typing/undo stay native.

Independent review found callback-context cleanup, close-error containment,
dismissal-during-start and partial-publication issues; dedicated regressions
cover the fixes. Native GUI/TTY fixtures share a real three-frame keyboard
journey, including direct frame deletion, major-mode changes and source death.
Local Emacs29.3 passes414 ERT, strict library/example compilation/checkdoc
and strict compilation of the shared helper plus GUI/TTY fixtures. Hosted CI
40555916227 passes all eight compatibility/package jobs; graphical40555916247
passes GTK/Xvfb job122371806698; tmux40555916274 passes Linux/macOS jobs
122371807141/122371806507. All three native environments explicitly report the
three-sibling-popup/individual-and-collective-toggle journey. The package job
122371805766 clean-installs the same archive on31.1/28.1; artifact SHA256
eaf725128183fff6b2d116b153d7a33e4a8df36858b691fab87d7a52c53499b0.
The extracted local runtime disables unavailable JIT compilation; its29.3 PTY
unsupported branch does not establish native composition. Physical display,
Ghostty/iTerm2 and broader input-method coverage remain open. Fixed beta1/2/3
refs are unchanged. Current main has twelve gallery entries; fixed beta3 has ten.

Next: finish the native sibling-popup departure candidate above, then prioritize
concrete beta feedback and measured application costs. Keep one independently
owned session per floating panel; no speculative group/window-manager API.

PR #73 merged at496056c455695edaec9518c702e633c6104a2b4f after independent
review5671654221 and all eight CI jobs40552001701 passed. It preserves the
original111672-byte checkpoint file unchanged in STATE-HISTORY.md.

## Current release

PR #72 integrated beta3 at a43239cfca0c455b4512525f323afdd1e11b20e0.
The new fixed release/0.1.0-beta3 ref was created and read back at that SHA.
Reviewed head: f033c2e655b5fa0f75c9794bf99dd20a7c90f2c9.
Tested merge: 8716ba4b4d7942f390d7effda00e57424618b535.
Tree: bc4fba1870dd2d41855ef988c013f9c6eed62134.
Independent coding-agent reviews: 5671420206 (final input-preservation follow-up).

All 13 applicable jobs passed before integration. Never move these fixed refs:

- release/0.1.0-beta3: a43239cfca0c455b4512525f323afdd1e11b20e0
- release/0.1.0-beta1: fd976f725c2bbb111d9fe6700bcabccfab1f3774
- release/0.1.0-beta2: c120d9f09612f29674fc0c08f90c39ecc61967da

A fixed Git installation branch is distinct from a GitHub prerelease tag.
No MELPA submission, acceptance, stable API or mature-package claim is made.

## Validation and integration evidence

The release candidate runs CI 40549386943 (8 jobs), graphical 40549388704 (1),
tmux 40549386969 (2) and movement 40549386952 (2). All thirteen passed before integration.
Package job 122348673852 confirms beta3 metadata and clean installation of the
same archive on Emacs 31.1 and 28.1; source 8716ba4 above, archive SHA256
c29ecfd9827eab086e7c8141a85971a25ac5be96891acc531a0cf0da0d699fa4.
The installed-client test exercises public preview scrolling while retaining
source point, text, selected window, logical focus and selection.

Local Emacs 29.3 passes 396 ERT, strict compilation and checkdoc, independently
reproduced by the reviewer. Exact-checkout package-build and clean install at
1c02cd8 pass; archive SHA256
a2b34d2b812f335fe6ac82845ba2ccdf1f71992375123db771d95230746f195f.
Native input edited while modification hooks are inhibited now survives focus,
refresh, same-reflow render hooks, hidden-pane restoration and quiet updates.
Five regressions preserve text properties/undo; explicit replacement still wins.
The initial GUI attempts timed out during apt installation before native tests.
Excluding recommended packages and bounding install at 20/job at 25 minutes keeps
all native assertions and 60-second execution limits intact. The renewed GUI job
122348680456 passes real child-frame/input/inspector and CAPF tests.
Native display evidence comes from hosted GTK/Xvfb and Emacs 31.1 TTY jobs;
local 29.3's unsupported-popup branch does not establish native TTY behavior.

Recent integrated units: [#68](https://github.com/vv111y/emacs-tui/pull/68)
real graphical CAPF coverage, [#69](https://github.com/vv111y/emacs-tui/pull/69)
twenty native command-loop lifetimes,
[#70](https://github.com/vv111y/emacs-tui/pull/70) related-object inspector history,
and [#71](https://github.com/vv111y/emacs-tui/pull/71) release-delta documentation.
Exact earlier heads, reviews, test logs and measured performance are preserved
in the history and [PERFORMANCE.md](PERFORMANCE.md).

## Capabilities to preserve

General-purpose, terminal-first toolkit: persistent applications, borrowed
panels and ephemeral workspaces share views, layouts and lifecycle. Applications
own data/actions, navigation and persistence; XOB remains an intended consumer.
List, table, tree, editable input and read-only text views support explicit
selection/marks/actions, queries, layout changes and cancellable providers.

Native floating candidate and object popups preserve the source window/buffer,
with eight compass positions, tracked anchors and scrolling without source focus.
The optional CAPF adapter uses native providers/styles/affixes and native undo.
The equipment inspector follows related objects with bounded Back/Forward history
and separate acknowledgements. Run make gallery, make inspector-demo or
make completion-demo from the matching checkout. Ordinary-window presentations
support Emacs 28.1+; floating popups require native child-frame capability.

## Next work and remaining limits

1. Collect concrete beta/API feedback and fix reported defects before expanding
   scope; the fixed beta3 install instructions and examples now match.
2. PR #74 integrated a distinct settings form at
   42d2217b23c8e1823982f6b525293f7c30d9b140: native fields, checkbox-style
   options, live validation and explicit Apply/Revert with session-only storage.
   Run make form-demo from current main. At that checkpoint main had eleven gallery entries;
   fixed beta3 keeps ten. Reviews 5671472509/5671539213 cover final head
   25010393 and tree 00e57ee0158176fc8059dcf7b3e5cbfbd992a969. All eleven
   exact-head jobs passed: CI 40550730712, GUI 40550730612 and tmux 40550730589.
   Local and hosted 404 ERT, strict compilation/checkdoc and real PTY showcase
   pass. Preserve native undo and the stale-draft publication regression.
3. Expand physical-emulator, GUI/display and input-method coverage. Hosted Linux/
   macOS PTYs, tmux and GTK/Xvfb do not establish Ghostty/iTerm2 or human visual QA.
4. Measure new bottlenecks with the checked-in benchmark protocol before
   optimizing. Preserve provider/display stage separation and raw evidence.
5. Implement an XOB adapter only against its actual public APIs. Do not turn
   query/origin/commit policies into universal core requirements.

[MELPA.md](MELPA.md) records the rules rechecked on 2026-10-27: at least one month
of public maintenance and substantive human review. Earliest known time gate is
approximately 2026-11-23; elapsed time and coding-agent review do not satisfy all
maturity/human-review gates. Latest checked package-lint 1865be7 still warns that
emacs is redundant in the package name; the warning is disclosed, not suppressed.
[API-STABILITY.md](API-STABILITY.md) defines the experimental compatibility policy.

Follow AGENTS.md: inspect remote heads/open PRs, respect recent draft ownership,
use independent coding-agent review and passing exact-head checks before merge,
and never overwrite intervening work. No Sunday work or notifications in Toronto.
Keep this file concise and current; retain dated detailed evidence in the history.
