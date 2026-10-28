# Project state

Updated 2026-10-28 (America/Toronto). This is the current handoff.
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

## Horizontal preview integration

PR [#89](https://github.com/vv111y/emacs-tui/pull/89) adds `emacs-tui-scroll-view-horizontally` for visible,
read-only text previews. Positive/negative columns reveal/return along a line;
nil uses native window width minus two. Source focus, selection and marks stay
unchanged. An explicitly requested native horizontal minimum survives movement,
layout and popup resize, while changed content resets it. The multi-popup demo
binds C-c < / > to eight-column steps. Fixed beta4 does not include this API.

Local Emacs 29.3 passed 433 ERT, strict byte compilation, checkdoc, shared native
fixture compilation and diffcheck. Five new ERT cover focus/data, layout and
unchanged text, default distance, hidden updates, text-to-list conversion,
invalid/hidden/editable/repurposed/disposed targets. Native GTK and Linux/macOS
fixtures exercise the actual keys, movement, resize, explicit refresh and
content reset; actual GTK and Linux/macOS tmux journeys passed. Package installation now
requires and exercises the new public function. A real recipe build from
`dfc95ac` and clean archive installation on local Emacs 29.3 passed, including
the horizontal API smoke (archive SHA256
`641f9e1f7644f2343360b72e50f1ecd5a1ff0b0e2a16b47b18622bf8a09c7cbd`).
Independent review identified stale horizontal state on text-to-list conversion;
the fix now clears it, and a strengthened regression asserts retirement because
batch redisplay alone did not expose the native minimum. A native conversion
journey supplements that assertion. Independent final review 5676566516 passed. All thirteen exact-head checks
passed before merge `0bf348455b2fdeff9ba2b2a7f597e57c6d16f153`: CI
[40613332736](https://github.com/vv111y/emacs-tui/actions/runs/40613332736)
(eight jobs), GTK [40613332737](https://github.com/vv111y/emacs-tui/actions/runs/40613332737),
tmux [40613332786](https://github.com/vv111y/emacs-tui/actions/runs/40613332786),
and movement [40613332912](https://github.com/vv111y/emacs-tui/actions/runs/40613332912).
Reviewed head `c0d286a3`, tested merge `b92b66c9` and integrated commit share tree
`09fb749581760a26f562c7924352ee24a6f29aa1`. Hosted package installation on 31.1
and 28.1 passed from the same archive, SHA256
`d411e722a8ce3474b3b89d1ff7ffc740202d1cb2443db956c6bc61e9f7f2d597`.
Latest upstream package-lint is still `1865be7`; the updated runtime reports
only the already disclosed redundant-emacs naming warning.

PR88's archival handoff merged at `3dde958b4222e485a682417f2fb13c07955be7dc`
after exact-head independent review 5676303259 and eight successful jobs in
[40608813841](https://github.com/vv111y/emacs-tui/actions/runs/40608813841).
Reviewed head `e8fad7b1`, tested merge `21163461` and integrated tree match
`687a5931c5f706e4e902377f54fce37ff2358cab`. No runtime changes were in that PR.
MELPA contribution guidance was checked again during this work; external gates
below remain unchanged.

## Ordinary-window reading validation

A new `tty-preview-smoke.el` fixture mounts native input beside a wide read-only
preview in ordinary windows, deliberately without child frames. It invokes the
horizontal command through a native key, verifies a far-column payload is
actually visible and painted, retains input text/point through real 120→90→140
terminal resizing, rows layout, maximize/restore and explicit refresh. It then
explicitly focuses the preview, invokes native cursor movement to trigger auto
horizontal scrolling, checks the retained minimum, and returns to the input.
This additional user navigation is distinct from the API preserving focus. It composes
vertical scrolling, resets on changed content and verifies native undo plus
resource cleanup. `make tty-smoke` includes it for every compatibility job.
README adds public-API usage and the demo table distinguishes main-only keys.

The actual PTY journey passed locally on Emacs 29.3, as did strict fixture
compilation and diffcheck. Independent review demonstrated that removing the
manual-minimum restore block still passed the first fixture. The strengthened
native cursor step passes with production code and fails when that block is
removed in an isolated copy; no production files were changed by the experiment.
PR [#90](https://github.com/vv111y/emacs-tui/pull/90) merged at
`d05fd6eaf43dcfc7ba2cd513438ba1f327e4536d` after independent review 5676629123
and all eleven checks passed: CI
[40614367472](https://github.com/vv111y/emacs-tui/actions/runs/40614367472)
(eight jobs), GTK [40614367456](https://github.com/vv111y/emacs-tui/actions/runs/40614367456)
and tmux [40614367514](https://github.com/vv111y/emacs-tui/actions/runs/40614367514).
Reviewed head `614e7901`, tested merge `5ef2c171` and integrated tree match
`bc5a9e8feaf0733b9d9b453a4a993d1e9758b813`. Actual logs confirm the new ordinary
PTY journey on minimum Emacs 28.1 and Linux/macOS 31.1; all 433 ERT passed.
No physical emulator or human usability validation is inferred.

## Terminal text-entry validation

The smoke driver now accepts atomic fixture requests for real UTF-8 PTY input.
Each request ID is delivered once, and reuse with changed bytes is rejected.
A new journey receives multiline bracketed paste with Japanese and combining
text, verifies its callback-fed preview and terminal paint, then removes it with
native undo. It activates built-in latin-postfix and receives actual composition
keystrokes before and after refresh, layout and both real terminal resizes.
A non-inserting fixture command dispatched from terminal bytes distinguishes
Quail's silent preedit from committed application input; asserting while preedit was still active
initially misidentified the trailing provisional space as a missing callback.
No runtime defect was inferred from that incomplete composition. The input
method, text/point, modification tick and callback count survive
redisplay-only changes. Closing removes owned buffers and preserves the original
source and its input-method state. No package runtime behavior changes.

Local Emacs 29.3 passed the actual PTY journey, strict fixture compilation,
and the complete 433-test/compile/checkdoc suite. Independent review strengthened
the fixture to snapshot before refresh/layout,
so those operations cannot hide redundant edits or callbacks. An isolated
sensitivity experiment removing paste delimiters fails at the single native
undo assertion. Six driver tests pass, including
UTF-8 delivery, no replay, changed-request rejection and invalid-input rejection.
Disabling latin-postfix in a second isolated experiment fails the bounded
composition phase with literal keystrokes, proving the input method is exercised.
Independent initial local review found no remaining issues. The initial hosted
macOS tmux run then exposed the fixture's use of C-b as a composition terminator:
that key is tmux's default prefix and is not reliable application input. Text and
callback values were correct, but the completion marker never arrived. The
fixture now uses its own C-c C-t command, which only records dispatch after
Quail commits; it does not insert text or simulate composition. Revised review
and fresh hosted checks were required; the failed head was not merged.
A broader local `make tty-smoke` passed all thirteen single-process journeys
and both resize fault probes, then stopped at the existing two-client test:
this container refused creation of its private Unix server socket with
`Operation not permitted`. The following hangup test was not reached. This is
not reported as a full local native-suite pass; hosted multi-client checks were
still required at that point. The fixture is included in every compatibility job
and both tmux jobs. Clipboard integration, physical
emulators, arbitrary input methods and GUI composition are not established.
MELPA CONTRIBUTING and the recipe checklist were reread in this run; their
public-maintenance and human-review gates are unchanged. Fixed beta refs remain
untouched. This is validation, not a new runtime feature.

PR [#91](https://github.com/vv111y/emacs-tui/pull/91) merged at
`ea6468ee588aab130700f9cd0ae5be50ef222028` after independent exact-head review
5677030411 and all eleven revised checks passed: CI
[40621124833](https://github.com/vv111y/emacs-tui/actions/runs/40621124833)
(eight jobs), GTK [40621124810](https://github.com/vv111y/emacs-tui/actions/runs/40621124810)
and tmux [40621124724](https://github.com/vv111y/emacs-tui/actions/runs/40621124724).
Reviewed head `818337cc`, tested merge `eb52e329` and integrated tree match
`898341d4dd4245fd5bb2d9606953f339abaf0a55`. Logs explicitly verify real text
entry on minimum 28.1 and Linux/macOS 31.1, including both tmux hosts. All 433
ERT and six driver tests pass; hosted multi-client/hangup tests also pass, which
local Unix-socket restrictions prevented exercising. The earlier failed macOS
job was 122593089782; corrected job 122595147328 passes on the reviewed head.

The architecture notes now reflect delivered popup, form and CAPF capabilities
and distinguish application policies from public primitives and unimplemented
features. This documentation checkpoint changes no runtime or fixtures.
Next: collect beta/application feedback and resolve concrete defects; preserve
these native regression paths when modifying editing or lifecycle code.

## Action dispatch validation

PR [#92](https://github.com/vv111y/emacs-tui/pull/92) merged at
`c9b35c1d972f054740a7e3e1441ceacf0b12123b` after independent review 5677083511
and all eight jobs passed in [40621967627](https://github.com/vv111y/emacs-tui/actions/runs/40621967627).
Reviewed head `3c74fc93`, tested merge `50c3ad1f` and integrated tree match
`5bc96c91eef1bd4bce21d79e92e1a726545b9416`. This was documentation only.

The next focused fix rejects stale named-action dispatch after availability
callbacks. Even a pure predicate can yield to timers/process callbacks; a
session can close or its targets can change before the predicate returns. The
old path could run the action with those stale objects. Repurposing an ordinary
window during the action menu also did not prevent dispatch. The new checks
require the same live focused view, owned surface and identical source objects
before using an availability result. Equal labels/IDs do not validate a newly
replaced object. A stale result raises a user error; there is no implicit retry
or action effect. Existing menu-time updates still receive a fresh availability
check and dispatch current objects when the context remains valid.

Three new ERT reproduce these gaps on the original runtime (17 of 20 action
tests pass; all three new tests fail). All 20 action tests pass with the fix on
local Emacs 29.3. They cover direct/menu dispatch, close, focus, replacement by
equal objects, selection/marks, final post-menu predicates and repurposed
surfaces. Independent review additionally exercised a pure predicate yielding to an actual
close timer and a refreshed source-list spine retaining identical marked
objects. Both cases are now bounded regression tests: closure aborts; the
identity-preserving refresh remains valid. All 438 ERT, strict compilation,
checkdoc and diffcheck pass locally on Emacs 29.3. Actual ordinary-window PTY
mount and tree journeys pass, including actions and 120→90→140 resizing.
The extracted runtime's native trampoline compiler is disabled locally; the
first attempted action run encountered that environment error and is not
counted as behavioral evidence. Native child frames and the supported-version
matrix still require hosted checks. Fixed beta references are unchanged.
MELPA CONTRIBUTING and its recipe checklist were rechecked on October 28; the
one-month maintenance and substantive human-review gates remain open.

PR [#93](https://github.com/vv111y/emacs-tui/pull/93) merged at
`5e742a5808ef99b12730c9d57993dacf7099540b` after independent exact-head review
5685862905 and all thirteen checks passed: CI
[40723131218](https://github.com/vv111y/emacs-tui/actions/runs/40723131218)
(eight jobs), GTK [40723131271](https://github.com/vv111y/emacs-tui/actions/runs/40723131271),
tmux [40723131073](https://github.com/vv111y/emacs-tui/actions/runs/40723131073),
and movement [40723131215](https://github.com/vv111y/emacs-tui/actions/runs/40723131215).
Reviewed head `7ec12828`, tested merge `406287e3` and integrated commit share
`1d7edce18a18011bdd9119c333205ba6b52413bd`. Actual minimum 28.1 and macOS 31.1
logs confirm 438 passing ERT and native action journeys; macOS 31.1 additionally
passes child-frame, two-client and abrupt-hangup checks. The package job passes
real build and clean installation on 31.1/28.1. Local ordinary-window preview
PTY validation also passed; it establishes no new physical-emulator coverage.

## Community feedback path

[The beta testing guide](BETA-TESTING.md) provides matching-checkout commands,
three short workflows and release-specific controls, including real paste/input
method and cleanup checks for human use. GitHub bug and beta-experience forms
ask for exact revision, display environment and a minimal reproduction or
concrete experience; they do not request private init files or full sessions.
The guide distinguishes installed runtime from checkout examples and beta4
from main. This prepares community testing; no human result is claimed.

Independent documentation review caught and corrected the CAPF cleanup key
(the mode has no C-c C-q binding), the all-toggle sequence, the need to actually
attempt invalid Apply, and an unobservable callback-count instruction. Both
issue forms parse as YAML with unique IDs and required-field booleans; diffcheck
passes. No runtime changes or new execution tests are part of this guide.
Next: collect concrete beta/application feedback and address reported defects;
keep fixed beta refs unchanged and preserve the native regression paths.

## Selection callback ownership

PR [#94](https://github.com/vv111y/emacs-tui/pull/94) merged at
`d38242d8476c9c9ab5020034399ffd466883de93` after independent exact-head review
5686040566 and all eight CI jobs passed in
[40725104111](https://github.com/vv111y/emacs-tui/actions/runs/40725104111).
Reviewed head `d35942fd`, tested merge `9ddd4f54` and integrated tree match
`c50bec653509e000eb596e9e57c0d888213f8c35`. This adds the community guide and
feedback forms; no human testing results are inferred.

The next focused fix extends surface-ownership validation to `emacs-tui-select`.
An explicit call with a live session could invoke its selection callback after
an ordinary window had been repurposed to display a foreign buffer. It now
rejects before the callback, preserving the foreign buffer/window. Selection
still passes only the selected object, even when hidden marks exist, and does
not close the interface. This does not change named actions or commit semantics.

The new foreign-surface regression fails on the original runtime (the callback
runs and selection returns); the positive hidden-mark case passes before and
after. All 440 ERT, strict compilation and checkdoc pass locally on Emacs 29.3
with native trampolines disabled for this extracted runtime. The actual ordinary
TTY mount/action journey passes, including 120→90→140 resize. Independent review
ran all 24 action/select tests and reproduced the original-runtime failure.
Hosted checks remain required before integration. Fixed beta refs remain
unchanged. MELPA contribution guidance was rechecked October 28; external
maintenance and human-review gates remain open.

## Beta5 preparation

PR #95 merged at `7c3cba529ba116b58c008e7c76396f3fccfe2f0b` after
review 5686639716 and all thirteen exact-head checks passed: CI 40732341777
(eight jobs), GTK 40732341788, tmux 40732341790 and movement 40732341798.
Reviewed head `7294b260`, tested merge `5c1f833e` and integrated commit share
tree `9734141d2cf3e24bccbe7f536e33c51ff7e78d3c`.

The candidate beta5 packages pinning, horizontal preview reading, action and
selection ownership fixes, native input regression coverage and feedback forms.
The package header, installation/example instructions and changelog are updated
together. Local Emacs 29.3 passes all 440 ERT, strict compilation and checkdoc;
no runtime behavior changes in this candidate. Actual recipe build and clean
installation on local 29.3 passed from `c870ba3`, including literal beta5
metadata parsing and public API smoke. Archive SHA256:
`5c177fdfcfc82af92fe3ea4c08c1c8c6fc8619fd4814d90e30898404462afadb`.
Hosted 31.1 build and 31.1/28.1 installation still gate publication.
This is preparation: no beta5
release ref has been created. Publish
only from reviewed passing integration, verify the immutable ref and actual
package installation, and then update this handoff. Fixed beta1–beta4 refs must
not move. No human usability, physical-emulator or MELPA acceptance is claimed.

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
