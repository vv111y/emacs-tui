# Project state

Updated 2026-10-27. This is the current handoff. Earlier checkpoints through
initial beta3 preparation are preserved byte-for-byte in
[STATE-HISTORY.md](STATE-HISTORY.md). Their pending checks describe their own
dates, not current blockers; later intermediate edits remain in Git history.

## Pinned floating Details candidate — 2026-10-27

Development main candidate adds C-c C-d to hold visible Details on its object
while browsing the independent list, then release to follow current selection.
The header shows [pinned]; hide/show retains the held object and fresh enable
resets it. Application policy composes existing public updates; no core API is
added. Failed/stale publication closes only original Details and does not publish
a new pin. Four behavioral regressions cover retention, guards, failed release
and stale callbacks. Local Emacs 29.3 passes 428 ERT, strict compile/checkdoc,
shared-fixture compilation and diffcheck. The shared GTK/TTY journey checks
reading position while pinning and browsing, rendered text, reopening/release,
same frame and source/sibling isolation. Fresh native execution and final
independent review are required before integration. Beta4 remains unchanged.

## Published fixed beta4 — 2026-10-27

PR #86 merged at f5d8a56ece025964d8a3db31ea07e1399d12150d after independent
review 5676197886 and all thirteen final-head jobs: CI 40607249360 (eight),
GTK 40607249371, Linux/macOS tmux 40607249445 and movement comparison
40607249352 (two). Reviewed bb3be274, tested merge b54240aa and integrated
commit share tree e0021f70696c1a5e9e2e46a37b262ac5cf31b877. The fixed branch
release/0.1.0-beta4 was created at that merge and read back; beta3 remains
a43239cfca0c455b4512525f323afdd1e11b20e0 and no older beta ref was moved.
The snapshot contains the settings form and three floating panels with toggles,
independent placement, Details scrolling and resize, with all twelve gallery
tours and matching straight.el instructions. Package job 122549710552 verifies
literal 0.1.0-beta4 / canonical 0.1.0beta4, builds the recipe and clean-installs
the same archive on 31.1/28.1, including installed resize API provenance.
Local 29.3 also passes 424 ERT, strict compilation/checkdoc and actual recipe
build/clean installation. This fixed branch is not a GitHub prerelease tag or
MELPA acceptance. Physical terminal/IME use and substantive human review remain
open; MELPA rules rechecked 2026-10-27 still require at least one month of public
maintenance. Next: collect concrete beta feedback and continue reviewed,
consumer-driven functionality on main without moving the fixed release.

## Integrated oversized native resize coverage — 2026-10-27

The shared GTK/TTY resize journey now requests 10000×10000 cells, verifies
actual frame bounds clamp inside the parent while requested dimensions survive,
then restores 50×12 on the same child with source focus retained. Existing
full-source and sibling-isolation assertions remain. PR #85 merged at
faa6c4caf0fd1c38f95c3c382d307fc995e49f43 after exact-head review 5675642622
and all eleven final checks: CI 40599974496 (eight jobs), GTK 40599974459 and
Linux/macOS tmux 40599974523. Reviewed 03a55674 and tested merge 5dfde8d7
share tree 518c92ba5927ef27e67ce7765ee7588972e5690f. GTK 29.3 and native
TTY 31.1 Linux/macOS execute the new assertions. Local 424 ERT, strict
compile/checkdoc, shared-fixture compilation and diffcheck pass. This adds
regression coverage, not a new clamping implementation.

## Integrated floating Details resize — 2026-10-27

The public `emacs-tui-resize-popup` requests new dimensions on the same child
frame, using existing native clamping/reflow and cleanup. Invalid dimensions,
non-popup sessions and nested reflow reject before mutation. The three-panel
demo uses C-c C-e to expand/shrink visible Details between requested 34×7 and
50×12; it remembers that choice across hide/show without resizing siblings.
Local Emacs 29.3 passes 424 ERT, strict library/example compilation/checkdoc,
strict shared/TTY fixture compilation and diffcheck. Independent review asked
for stronger native coverage: the TTY long-list journey now checks the public
API's return value, same child, requested placement, selection and marks on
grow/shrink. Shared GTK/TTY checks actual growth, same-child shrink, reopened
size, sibling isolation and exact-once cleanup after a failed native resize.
PR #84 merged at 0cbb600dc03424d8eb37a7aaa2d15253f94329be after review
5675233536 and all thirteen final-head checks: CI 40594370108 (eight jobs),
GTK 40594370130, Linux/macOS tmux 40594370115 and movement comparison
40594370123 (two jobs). Reviewed bea94e2f and tested merge cc34390f share
integrated tree 7fbaedf0debc27689d5c24367b8cd00fa21f1f6a. Fixed beta refs unchanged.

## Integrated reentrant popup movement correction — 2026-10-27

A callback trying to reposition a popup during reflow previously changed its
requested placement, then raised an error because nested reflow cannot execute.
The correction rejects before mutation, preserving placement and session life.
A regression fails on the original code and covers explicit and cycling moves.
Local Emacs 29.3 passes 420 ERT, strict compilation/checkdoc and diffcheck.
The original regression fails specifically on changed placement (south-west to
north), not an unrelated surface error. PR #83's independent review narrowed
the documented rejection to reflow: ordinary view updates use a separate
rendering guard and are outside this correction. PR #83 merged at
106d2624232ce99d725f833dbef38a27691f7287 after final-head review 5675159892
and all thirteen checks: CI 40593354924 (eight jobs), GTK 40593355383,
Linux/macOS tmux 40593354964 and movement comparison 40593355961 (two jobs).
Reviewed 81845da9 and tested merge 2a32714c share integrated tree
8b11977e098fdb24cd5367b713f66802da9dfe87. Earlier-head results were not reused.

## Integrated linked floating Details scrolling — 2026-10-27

The three-popup demo adds C-c [ / ] to read longer per-object Details while
source typing focus and sibling panels remain unchanged. This composes the
existing public scroll API; it adds no core API or external actions. Hidden
Details rejects scrolling rather than reopening; moving a visible panel retains
reading position, while hide/reopen recreates it at the beginning.
Local 419 ERT, strict library/example compilation/checkdoc, strict shared native
fixture compilation and diffcheck pass. Review caught a vacuous busy-guard test:
it now asserts rejection while Details is live, before hiding it. The shared
real GTK/TTY journey checks forward/back reading, reading-position preservation
across movement, sibling isolation and the existing full source-state checks.
PR #82 merged at 4a6c82696794af6680e3b788257de0ff2ff488ab after exact-head
review 5674395969 and all eleven checks passed: CI 40584520344, GTK 40584520796,
and Linux/macOS tmux 40584520282. Reviewed 3680b632 and tested merge ff0ff7ac
share tree 4fc6675aeefc0ee65cc68831fd7161f2328819e6. Fixed beta refs unchanged.

## Integrated graphical form coverage — 2026-10-27

PR #81 merged at 374ba1c1d0a2d3c204ed3ad787b75418b627ff8e after corrected
exact-head review 5674290580 and all eleven final checks passed: CI 40583445694
(eight jobs), GTK 40583445561 and Linux/macOS tmux 40583445534. Reviewed c6b7f21b
and tested merge 88c1cc21 share tree 22568d85f1fd5df265e5e6a82eea12185931c073.
GTK job 122468626559 explicitly reports form validation/options/apply/revert
and a separate CAPF PASS. The earlier failure and correction are retained below.

## Graphical form correction evidence — 2026-10-27

The GTK fixture exercises the settings form's native ordinary windows: field
editing, rejected invalid Apply, option toggling, successful Apply and Revert,
then owned-window/view-buffer cleanup and source preservation. It requires four
live distinct view windows on the graphical parent, with no extra frame.
The initial PR #81 GTK run 40575334155 / job 122440124319 failed at
`(frame-live-p child)`: the test incorrectly assumed the form uses a child frame,
although its public command deliberately uses `emacs-tui-mount`'s windows default.
The correction tests the actual application presentation, preserving all existing
child-frame journeys; no production behavior is changed. Initial eight CI jobs
40575334183 and Linux/macOS tmux 40575334117 passed, but do not validate the fix.
The corrected helper completes locally against actual ordinary windows, including
native editing and cleanup; independent review also injected an editing error
and verified disposal of all four windows/buffers plus source restoration.
Local Emacs 29.3 passes 418 ERT, strict library/example compilation/checkdoc,
strict GUI-fixture compilation and diffcheck. These do not prove GTK behavior.
The fresh exact-head review and native results above supersede this pending gate.

PR #79 integrated at 7a32848159cf65af901fbb4affc41b8020c60474 after exact-head
review 5673327045 and all eight CI 40572579490 jobs passed. Reviewed a694bc0e
and tested merge d2086007 share tree b963d0e37b1d5c7c02e958b2dec98cf7ea75218e.
The source assessment below remains a documentation boundary, not an adapter.

## XOB integration assessment — 2026-10-27

PR #79 documents the actual owner repository API at pinned org-xob commit
b097f5e255f7cc0a9950c059c81df90eca95795b (2026-10-22), with primary links in
[XOB-INTEGRATION.md](XOB-INTEGRATION.md). Public active-buffer traversal is not
a complete knowledge-base catalogue; navigation/insertion commands and private
content/link collectors do not constitute a pure snapshot API. Loading/starting
XOB has application-wide effects, so core must not implicitly do so for preview.
The next adapter unit should establish read-only snapshots and separate explicit
actions, test disposable data, and state any active-buffer-only scope honestly.
No XOB code was executed and no user knowledge-base files were accessed or
modified. The original documentation-only head 54a7957 passed eight CI jobs in
40569203071 and exact-head coding-agent review 5673040497; the rebased final
head still needs its own review and CI before integration. No adapter is shipped.

## Integrated independent panel placement — 2026-10-27

PR #80 merged at b6a5ff0757722d6b5562dcf183c96c954cdaf811.
The multi-popup demo adds C-c p 1/2/3 to move Objects/Details/Keys through the
eight requested positions independently. C-c C-p remains the Objects alias.
Each requested position survives hiding/reopening and source departure/return;
disabling/re-enabling starts from defaults. Hidden panels must be shown before
moving. Placement is application-owned, with no core API change; native bounds
still clamp and can cause overlap. Stale/dismissed moves cannot publish saved
placement. Policy regressions and a native keyboard journey cover all eight
positions per panel, sibling geometry isolation and retained reopened placement.
Local and hosted 418 ERT, strict compile/checkdoc and native fixture compilation
pass. Independent final-head review 5673190020 covers 42eb1365; reviewed tree
e87305b9fcf5c868f87fbe6af2f248d5e7dd2d4c matches tested merge d09b44c9 and
integrated commit. All eleven final checks passed: CI 40570898030 (eight jobs),
GTK 40570898065 and Linux/macOS tmux 40570898070. Native logs explicitly include
independent placement and source departures. Package job 122424477328 installs
the same archive on 31.1/28.1; SHA256
91fca4341de8e5a9555d38e7b2ce2492347f4fdd4356740f1163354000413dfa.
Physical terminal/display and broader input-method testing remain open;
no maturity or new fixed-release claim is made.

## Integrated sibling-popup departure coverage — 2026-10-27

PR #78 merged at 484286408a3c715c2034033c6faf0fa7a0e7a49a. It extends the
shared real-frame journey through both buffer and window commands. It checks that all three old frames/view buffers/anchor markers are
released and popup command routing is removed, edits the destination, then
returns and explicitly recreates the panels with retained selection. Source
text, point and undo are checked. This adds no production API.

The initial GTK journey failed its final complete window-state comparison.
Diagnostic run 40567170801, job 122411438165, at head 9ebb209 printed both states:
only prev-buffers differed, gaining the source buffer itself after the fixture's
intentional switch-away/return commands. Dimensions, selected buffer, point,
start and other fields were unchanged. Linux/macOS tmux had passed the preceding
b0264c3 head in 40566268666; those results do not validate the correction.

The correction retains the original complete-state assertion around popup
operations before navigation, and adds a new complete-state assertion around
reopening after each return. It does not filter history fields or relax equality.
Source and resource assertions still cover the deliberate navigation. Local
Emacs 29.3 passes 415 ERT, strict compile/checkdoc and strict shared/GUI/TTY fixture
compilation. Independent exact-head review 5673096905 covers 10724484; its tree
16f6ce1537e5a52fe10ce1e1b161546020d67f71 matches tested merge 19858866 and the
integrated commit. All eleven checks passed: CI 40569899852 (eight jobs),
GTK 40569899845 and Linux/macOS tmux 40569899947. All three native environments
explicitly report source departures. Package job 122421009193 clean-installs the
same archive on 31.1/28.1; SHA256
f547f30ac460a1669e2a34fc4597a7bcf96d8c40b773b20561d71d315dce22bb.
The local 29.3 runtime alone cannot prove native terminal child-frame behavior.

## Integrated native multi-popup gallery launch — 2026-10-27

PR #77 merged at a32e3f64b8ada0007a71fc8b131f7f9b33095fec after independent
exact-head review 5672728137 and all eleven checks passed. Reviewed head a53067a
and tested merge 26a5c04 share tree febd48d4d8cbd2257028ebb716a7b6b29ca92d71.
The shared journey selects the gallery entry, reads its tour with RET and
launches with C-c C-o, then asserts chooser disposal and the three real sibling
frames. A failed tour command releases the chooser; the regression uses a real
ordinary-window gallery. Local/hosted 415 ERT and strict compile/checkdoc pass.
CI 40565040105 has eight successful jobs; GTK 40565039863 and Linux/macOS tmux
40565039877 explicitly report gallery launch. Package job 122403958392 installs
the same archive on 31.1/28.1; SHA256
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

Next: use the pinned XOB assessment to define an optional snapshot/action
adapter; prioritize concrete beta feedback and measured application costs. Keep one independently
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
   scope; the fixed beta4 aligns installation and all twelve gallery examples.
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
