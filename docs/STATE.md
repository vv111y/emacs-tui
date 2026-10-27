# Project state

## Completion fixes integrated and paired evidence retained — 2026-10-27

PR #61 merged at 0673be3d75dc9aa25b5b024eeca393212e3b8fe1 after exact-head
review 5665586060 and all eight runtime/package jobs in CI 40488618713 plus
four comparison jobs in 40488618876 passed. Reviewed head
c5900d9ab5539a304d4ee274f2be446914c60e29 and tested merge
af2fa8d686d7f98faa078eac78c2e1d98016f7e3 share tree
dbcac547fb031ab812e2caabd2592e5c8c40c917. All 364 ERT, strict checks,
native Linux/macOS CAPF display/acceptance, lifecycle and terminal-loss tests,
benchmark protocols and clean package installs pass. Native file-completion
tests now confirm affixation-returned candidate faces reach the rendered buffer
while acceptance and undo preserve plain source text.

[The paired lifetime evidence](../bench/results/2026-10-27-completion-lifetime/README.md)
retains all 16 reports from final PR #60 run 40487652908: 6,720 records.
Original ZIP hashes, raw report bytes, all eight measured source hashes per
side, every aggregate/per-command quantile and all 32 table rows were checked
independently. The committed auditor passes and checks matching hosts/fixtures,
GC settings, stage calls, sample order and clock arithmetic. Timings are mixed,
including regressions: no uniform latency improvement is established. The
verified benefit is releasing unused raw snapshots between commands; initial
matching/copying costs and provider-owned caches remain. This publication changes
no runtime behavior. Fixed beta refs remain unchanged.

Next: return to concrete general-purpose interaction and display coverage. A
source-anchored object/documentation inspector should demonstrate non-completion
data and explicit application actions using the existing popup primitives;
prove any needed scrolling or interaction API through that application. Continue
human beta use and broader GUI/emulator/multiplexer testing. Avoid speculative
completion rewrites or global GC tuning based on these synthetic workloads.
MELPA maintenance history, substantive human review and the name advisory remain
open; no mature/stable/accepted claim is made.

## Affixation presentation preserved — 2026-10-27

The completion adapter now uses the validated candidate returned by the
affixation callback when building its display label. Previously the prefix and
suffix were retained but styling added to the candidate itself was discarded.
The returned candidate must still match the raw value; IDs, accepted source text
and exit arguments stay property-free. No API changes or provider mutation.

Local Emacs 29.3: 364 ERT, strict byte compilation and checkdoc pass. Both new
regressions fail on the old implementation; they cover replacement/in-place
candidate styling, unchanged raw projection, prefix/suffix faces and plain-text
acceptance. The native file CAPF fixture now checks the rendered candidate face
and plain accepted source alongside its existing file boundaries, undo, exit
callback and read-only retry checks. Exact-head review and fresh hosted native
checks remain required before integration; local tests model popup presentation.

PR #60 merged at db8bfd9b2d2cf5cb0d3e8d09d8921de00ff53ec4 after exact-head
review 5665491072, all eight jobs in CI 40487652957 and all four paired jobs in
40487652908 passed. Reviewed head 9f1e6611311633a07168d6e0a206c539111d339e and
tested merge c48d4f6127afec64633855f203d47a0d679cda3e share tree
d391d587a2f354410728dabb900ebae9fe8f4871. The revised GC fixture passes on both
28.1 and 28.2; initial failed CI was not waived. Native Linux/macOS behavior,
source/bytecode protocols and clean package installs pass. Paired timing results
are mixed; shorter snapshot lifetime is verified, not a uniform latency win.

Next: retain/audit the 16 paired reports, broaden application/display testing,
and collect beta feedback. Fixed beta refs and MELPA external gates are unchanged.

## Completion snapshot lifetime — 2026-10-27

After publication, the completion context retains replacement bounds and
metadata, but releases the copied full candidate snapshot. Acceptance already
recomputes candidates and validates the selected raw value and previous bounds.
The full isolated snapshot still exists through decoration and display callbacks;
provider strings, native styles, matching and display limits are unchanged.
Provider-owned caches/metadata and displayed objects can still retain data: this
is not a bound on total completion memory and does not reduce snapshot creation.

Local Emacs 29.3: all 362 ERT, strict compilation and checkdoc pass; all five
Python protocol tests pass. The weak-key regression proves an undisplayed raw
snapshot becomes collectible while its popup remains live, then accepts normally
with both absent and reversing sorters. It fails on the prior implementation.
A separate regression preserves validation against a callback that mutates both
provider storage and its decoration argument. Native 31.1 evidence and exact-head
independent review remain integration gates. No latency improvement is claimed.

Initial CI 40486893255 failed only the new GC assertion on 28.1/28.2. The
fixture now projects in a joined thread, following Emacs's own weak-table tests
to keep stale conservative stack references out of collection checks. The same
zero-key assertion remains, and still fails against the old runtime locally.
Local 29.3 full checks pass; a separately extracted Debian 28.2 aborts even on
an empty batch evaluation in this container, so it supplies no test evidence.
Fresh hosted 28.1/28.2 checks are required; no failed job is waived.

A paired workflow uses identical fixtures, normal GC defaults and the same
runner for baseline/candidate, separately for identity/absent sorters on Linux
and macOS. It measures 100/10,000-row completion filtering in source/bytecode,
200 commands after 10 warmups, with stage clocks and all existing paint, values,
ownership and cleanup checks. Keep raw reports and inspect both insertion and
deletion tails before drawing conclusions. Fixed beta refs are unchanged.
Next: audit paired evidence, broaden actual applications/display validation and
continue beta feedback. MELPA maintenance-history and human-review gates remain.

## Completion stage profiles published — 2026-10-27

PR #58 merged at ea3aca27abaacb49710f541d9359a8e133b0f9e3 after exact-head
independent review 5664519072 and all eight compatibility/package jobs in
40477529290 plus four native profile jobs in 40477529516 passed. Head
19ae46168d2232d013e56e20dc03042003b68c5d and tested merge
47313d05aaaa8e9bd7091a5efd27be6e8586568c share tree
71a2b90bbaa35b89ee8bc3394a68238866e7df48. All 360 ERT, strict compile/checkdoc,
package installations and native Linux/macOS lifecycle/CAPF/terminal-loss tests
passed. Instrumented native smoke passed in source/bytecode; all four full
profiles passed exact stage-call and candidate/paint/cleanup assertions.

Eight raw reports (15,120 records) are retained losslessly under
[completion stages](../bench/results/2026-10-27-completion-stages/README.md).
Original ZIP/report digests match; every measured input hash matches the exact
commit. The auditor recomputes every aggregate/per-command quantile and validates
record order, call counts, inclusive nesting and clock arithmetic. Local five
Python report/protocol tests and four independent extracted-wrapper ERT probes
also pass; the latter establish return/error semantics, not display evidence.

The profiles locate substantial restoration cost in projection/native matching.
For unsorted 10k bytecode deletion, projection median is 90.859 ms Linux and
80.081 ms macOS; publication medians are 0.407 and 0.358 ms respectively. These
are inclusive, independently summarized stage clocks, not additive components.
Instrumentation changes timing/allocation overhead. Sorter policies ran in
separate jobs, including different Linux CPU models: this is not a controlled
policy comparison or a before/after speedup result. Detailed tails, GC, hosts and
all fields remain available. Unsorted 10k bytecode deletion has median 11 GCs
per command on both hosts, with recorded GC-time medians 92.692/83.491 ms.
Do not subtract separately summarized medians or assign that GC time to a
particular stage; inspect allocation pressure and lifetimes before tuning GC. Package runtime/API and fixed beta refs unchanged.

PR #57 merged at 561e91e83306e2f025cb7abd47d37608341b7306 after review
5663933663, eight CI jobs in 40472111751 and two profile jobs in 40472111645
passed. Its earlier positive native gates below are satisfied.

Next: investigate projection work while preserving native completion styles,
provider-owned strings and highlighting; measure any change using matching
instrumentation/fixtures on the same runner. Do not replace native completion
semantics based on a synthetic basic-style table. Broaden actual applications
and display coverage; maintenance history and substantive human review remain
external MELPA gates. No maturity or acceptance claim is established.

## Explicit unsorted completion workload — 2026-10-27

The native benchmark now accepts --completion-sort none for filter-completion,
while preserving identity as the default. The policy is recorded in reports.
Both native smoke modes cover unsorted 100/2,500-row tables and retain the same
paint, source ownership, exact candidate order/value and cleanup assertions.
This makes the bounded-copy path testable without silently changing the existing
baseline. The six-sample smoke is protocol evidence, not a latency baseline.

Local Python protocol regressions: all four pass; driver compilation and diff
checks pass. Local Emacs 29.3 correctly rejects the unsupported native workload
with zero records and no report. Positive Linux/macOS 31.1 execution and exact
independent review remain required; no before/after unsorted speedup is claimed.
Next: run and retain a matched unsorted profile, with stage attribution, before
claiming an end-to-end improvement.

## Bounded completion preparation — 2026-10-27

The completion adapter previously copied every candidate string before applying
the display limit, even without a display sorter. That path now copies only
the displayed subset; an application sorter still receives isolated copies of
all candidates. Annotation and affixation retain their isolation from the raw
projection. No public API changes and no terminal latency improvement is claimed
without a matching native workload. Existing benchmark metadata supplies an
identity sorter, so it deliberately continues to exercise the full-sorter path.

Local Emacs 29.3: all 360 ERT pass, strict package/example byte compilation and
checkdoc pass. New regressions cover destructive annotation properties with and
without a sorter, and destructive sorter values cannot alter the projection.
PR #56 merged at 8446077518ec9f2a04bc2eb96aa050dc741c7141 after
independent review 5663896426 and all eight jobs in CI 40471477020 passed.
Native Linux/macOS 31.1 completion, lifecycle and terminal-loss checks passed;
local batch checks do not replace that evidence. Fixed beta refs are unchanged.

Next: add measured stage attribution and an explicitly unsorted completion
workload, then investigate restoration costs. Broader display/application use
and the external MELPA gates remain open.

## Popup movement shipped and measured — 2026-10-27

[PR #54](https://github.com/vv111y/emacs-tui/pull/54) merged at
0fd29554674e743f691a6664764f6d7c73f23c2a after exact-head independent review
5663282467 and all eight runtime/package jobs (40463828758) plus both paired
measurement jobs (40463828773) passed. Reviewed head 05f72bcb823c18ad4227b9e54b93772a70513ba2
and tested merge e2c990014e4ce339ead3dcb17c8743138b22d9bb share tree
69f224fdad859cf8bf12de2f03133358db0fe04c.

Position-only reflow retains rows only when cached geometry is current and the
fitted content viewport is unchanged. Public refresh and changed margins/size
still render; native fitting, ownership validation and unwind cleanup remain.
Independent review found and fixed a pre-fit margin invalidation gap. The first
native test failed its nonzero horizontal-scroll setup; setup now completes
refresh before normal scroll-left with a persistent minimum. No assertion was
removed or failing check waived. Fresh Linux/macOS 31.1 tests pass all eight
positions with retained row text, nonzero scroll, selection and marks, and
verify captured child/buffer/marker disposal after fitting failure. All 358 ERT,
strict compilation/checkdoc, package build/clean installation and compatibility,
CAPF, terminal-client loss and lifecycle checks pass. Local Emacs 29.3 also
passes 358 ERT and strict checks; local PTY proves only unsupported native mode.

Eight losslessly retained reports in
[the paired movement comparison](../bench/results/2026-10-27-popup-movement/README.md)
contain 6,720 records from identical fixtures on baseline/candidate checkouts.
The audit verifies compressed/raw hashes, every quantile, sample ordering,
clock arithmetic, paired hosts and fixture bytes. At 10k rows, bytecode PTY
movement median/p95/p99 changes from 39.940/44.695/47.523 to
2.331/11.604/13.029 ms on Linux, and 26.957/28.854/30.042 to
1.329/7.005/7.169 ms on macOS. Sequential hosted runs are not universal latency
promises: some small-list Linux tails regress. Source undo is disabled in the
disposable fixture; physical paint, creation and acceptance are not measured.
All raw fields and warmups remain available. Fixed beta refs are unchanged.

PR #53 integrated the audited initial native baseline at
e76da73b8935c6a199bedceb86f6b12f171b3736 after independent exact-head review and
all eight runtime/package plus two profile jobs passed in runs 40461793720 and
40461793763. Its raw 7,560-record evidence and audit script remain retained.

Next: attribute completion restoration costs before optimizing them; the native
baseline shows substantial framework/projection work beyond table callbacks.
Emacs 31 already hashes long delete-dups inputs, so do not presume quadratic
deduplication. Broaden real application and terminal/GUI use, collect beta API
feedback and complete release gates in docs/MELPA.md. No maturity or MELPA
acceptance is claimed; public maintenance and substantive human review remain
external gates. The paired evidence publication changes no package runtime.


## Native popup baseline — 2026-10-27

PR #51 merged at 107dfc3fdf26a1d803c970d3e5b8d8a4dd4e050b after exact-head
independent review and all eight jobs in run 40460185462 passed. Both 31.1
platforms passed native source/bytecode protocols, all 357 ERT, strict checks,
native lifecycle/CAPF/client-loss checks and retained artifact uploads. The
earlier hidden-directory artifact failure was fixed and not waived.

PR #52 merged at ae7ba28aeecfd04791ac8e17f2f519ac41972f9b with exact reviewed
tree 27bdb8642108103a4af3e574df27e43ed1a2085e. All eight runtime/package jobs in
40460835278 and both native profile jobs in 40460835255 passed after retargeting
to main and recording its ancestry with a forward merge. Raw artifacts were
retained on both platforms; review 5663038248 covers that exact head. Fixed beta
branches are unchanged. Result-only paths are excluded from future full-profile
triggers; ordinary runtime CI still checks this evidence publication.


Full profile run 40460297101 passed Linux/macOS 31.1 at 100/1,000/10,000 rows,
200 measured commands and 10 warmups. Four original raw reports are retained
losslessly under bench/results/2026-10-27-native-popup with a provenance/checksum
manifest. ZIP digests match GitHub; all report quantiles were recomputed, all
7,560 records validated and source hashes checked against the measured tree.
These are hosted-PTY observations, not physical paint or universal latency
promises. Disabled undo, the synthetic table and overlapping clocks are explicit.

At 10k, bytecode compass-move PTY medians were 42.147 ms Linux and 31.486 ms macOS;
completion restoration medians were 155.877 ms and 118.627 ms. Table callback
medians were below 0.4 ms in this fixture. Full popup reflow rebuilds the view on
movement; it is the next concrete performance target. Compare baseline/candidate
on the same runner before claiming improvement and preserve resize/selection/
ownership cleanup. Completion projection needs further attribution. Human app
use, GUI/emulator/multiplexer testing and MELPA external gates remain open.


## Full native profile collection — preparation, 2026-10-27

A separate benchmark workflow prepares reproducible Linux/macOS Emacs31.1
profiles for 100/1,000/10,000 rows, 200 measured commands and 10 warmups. Source
and freshly compiled libraries run sequentially on each runner; raw JSON plus
provenance is retained for 90 days. This supplies >=100 samples per alternating
completion command. The workflow is manually runnable and triggered by changes
to benchmark code, rather than adding full profiling cost to every runtime PR.
There is no timing threshold. Shared-host scheduling is uncontrolled; do not
infer universal platform ratios or before/after improvements from separate
machines. Native protocol smoke and ordinary package/runtime CI remain gates.
Next: inspect actual full-run artifacts, retain selected raw profiles and
publish a qualified baseline; optimize only a demonstrated bottleneck.

## Native popup measurement fixture — in progress, 2026-10-27

The next focused change adds `--presentation popup` to the real PTY benchmark:
source-preserving navigation, all eight compass positions and actual native
completion filtering. It rejects unsupported runtimes without fallback. Reports
retain source/fresh-bytecode provenance, actual terminal paint proof, host and
child identity checks, separate synchronous table callback clocks and raw
per-command samples. The provider fixture is a finite synchronous table, not
an external-provider estimate; final redisplay and command-minus-table clocks
are explicitly not pure rendering time. CI31 native smoke will retain raw
artifacts, with no performance threshold or baseline inferred from six samples.

Local Emacs 29.3 passed 357 ERT, strict package/fixture compilation and checkdoc.
The native-only run correctly failed as unsupported with no result JSON;
actual native positive evidence requires hosted Linux/macOS 31.1. Independent
preliminary review caught a repaint-proof gap for identical successive cases;
setup now forces a full redraw outside timing. Final review also required
exact displayed candidate values/order when filtered and full results both hit
the display cap; native smoke now includes 2,500 rows to exercise that boundary.
An independent real-CAPF/model-display probe confirms a stale 200-row display
passes the old checker and fails the new one. That probe is not native evidence. All five existing window workloads passed in source/bytecode modes, including
the multi-term filter cases; four Python driver regressions passed. Exact
published-head review and hosted native CI remain required before integration.
Run 40459636747 passed Linux31 native source/bytecode measurements but failed
artifact upload because upload-artifact excludes hidden directories by default.
The exact report glob now explicitly includes its `.cache` directory; a new
full check run must pass, including artifact retention. This failure is not waived. Neither fixed
beta release branch is changed. Current MELPA policy blobs were rechecked on
2026-10-27 and are unchanged; maintenance and substantive human review remain
external gates. Next after integrating the fixture: collect a full native
profile with >=100 samples per individual command, then optimize demonstrated
bottlenecks and broaden real GUI/emulator/multiplexer/application use.

## Verified release and handoff — 2026-10-27

Beta2 is available from the fixed `release/0.1.0-beta2` branch at
`c120d9f09612f29674fc0c08f90c39ecc61967da`, the merge of
[PR #49](https://github.com/vv111y/emacs-tui/pull/49). Its tree is the exact
reviewed `e85b494cfc89cd9a69bebeca0ac56cb427ffd7c6`. The branch SHA, source
version header and pinned README recipe were read back through GitHub after
creation; independent review repeated the integrity check. Never move it.
Beta1 remains unchanged at `fd976f725c2bbb111d9fe6700bcabccfab1f3774`.

Final release run
[40452784379](https://github.com/vv111y/emacs-tui/actions/runs/40452784379)
passed all eight jobs. Seven runtime jobs passed 357 ERT, strict compilation/
checkdoc, eleven terminal scenarios, reflow/client/hangup checks and benchmark
protocol smokes. Linux/macOS 31.1 each explicitly verified popup terminal paint,
eight positions, native CAPF filtering/selection/acceptance/undo, file boundaries/
exit callbacks and abrupt real-client loss with `floating-popup=painted/disposed`
plus surviving terminal input. Package CI verified canonical `0.1.0beta2`, built
the identical reviewed tree and clean-installed its archive on 31.1 and 28.1.
Local 29.3 also passed 357 tests and final recipe installation; its Unix socket
restriction remains a local limitation, covered by hosted client tests.

Recent integrated work: [PR #47](https://github.com/vv111y/emacs-tui/pull/47)
adds the optional buffer-local native completion frontend; [PR #48](https://github.com/vv111y/emacs-tui/pull/48)
proves painted floating-popup disposal after abrupt client loss; PR #49 adds
release metadata/instructions and hardens completion ownership across display,
provider and editing callbacks. `make popup-demo` shows automatic literal-word
completion; `make completion-demo` uses Emacs's actual Lisp provider. The
matching beta2 checkout includes the distinct gallery examples; straight.el
installs the runtime only. Start a fresh Emacs when changing installed versions.

This remains an experimental beta. Native floating popups require graphical or
advertised TTY child frames; ordinary workspace fallback remains available.
GUI/font/physical-terminal/multiplexer use and broader application feedback are
incomplete. The optional completion table is synchronous, with a display-only
candidate cap. Existing benchmark numbers cover ordinary windows, so native
popup/CAPF latency needs its own fixture and provider/redisplay clocks.

MELPA policy/name availability and latest package-lint were checked on
2026-10-27: the public-maintenance month, substantive human review and maintainer
acceptance remain external gates. Earliest known time eligibility is roughly
2026-11-23; elapsed time alone is not maturity. The package-name advisory remains
disclosed. GitHub tags/prereleases are unpublished because authenticated release
access is unavailable; fixed-branch straight installation is the delivery path.

Next: collect real application/API feedback, add a dedicated native-popup
latency fixture with separate provider work and raw source/bytecode provenance,
broaden actual GUI/emulator/multiplexer validation, then optimize measured
large-result rebuilding. Do not infer stable/MELPA status or native latency
from the release, hosted PTYs or protocol smoke checks.

## Beta2 preparation — historical validation record

PR #48 merged at `63faea9182421f1f68ee659aefd8c83a67845cc5` after independent
exact-head coding-agent review and all eight jobs in
[40450211855](https://github.com/vv111y/emacs-tui/actions/runs/40450211855).
Main matches reviewed tree `ef6d8471323572184e361381664f145e0b824c51`.
Linux/macOS 31.1 each passed 351 ERT and explicitly reported
`floating-popup=painted/disposed` after real client loss, followed by surviving
terminal input. Package build/clean installs and the older-runtime matrix passed.

The beta2 candidate updates the package header and CI expectation to
`0.1.0-beta2`, documents the additive popup/completion APIs and distinct demos,
and pins straight.el plus the matching example checkout to the new fixed
`release/0.1.0-beta2` ref. The optional frontend remains opt-in. A final readiness
audit also found an interrupted-popup startup could revive bindings after its
close callback had released the context. The frontend now verifies current
ownership, source validity, an unchanged source generation and a live popup
before publishing active state; six regressions cover early closure, a new
completion started during creation, source edits and callback-driven window
departure, including a table that moves to another same-buffer window during
the final acceptance refresh and a callback selecting a foreign buffer. Source
validity is checked again after invoking
the provider's context predicate and immediately before editing after table
callbacks, before any source read or edit and without another provider invocation.
The foreign-buffer regression asserts zero foreign source reads and preserves
both buffers and the callback-selected current buffer. The old code
returned handled=t with context=nil, active=t and TAB still captured. The new
guard releases only the obsolete context and preserves a replacement popup.
The initial published head's eight passing jobs did not cover this new finding;
fresh final-head review, checks and package installation are required.
Local 357 ERT, strict compilation/checkdoc and the completion PTY's honest
unsupported-native branch passed with the guard. Close/reentry regressions fail
on the old frontend; source-edit and callback-window regressions fail the first
guard. Independent review also passed update-time close/reentry probes.
No native-positive claim is inferred
from modeled presentation. Initial published-head CI passed 351 ERT before this
new coverage; it is not substituted for final-head results.
Strict native popup requirements and
ordinary workspace fallback are distinguished in the compatibility policy.

Local Emacs 29.3/Linux passed 351 ERT, strict compilation/checkdoc, literal
header/canonical package metadata (`0.1.0beta2`), actual pinned recipe build
and clean archive installation. The package build tested local source `74906b3`
before rebasing onto the identical reviewed PR #48 tree; archive SHA256 was
`f939436dc42bba40247533b4c644227250cb9e85487e4a1311070ba64c7c63cb`.
After the startup and acceptance guards, the actual pinned recipe rebuilt source
`f347c7f` and clean-installed on 29.3 with beta2 metadata; archive SHA256 was
`8293f86bec66ccedd4f79d621daf8f5114522cad74e20a30ef13bb69358df233`.
Independent preliminary release review is clean. Exact published-head review
and all eight runtime/package CI jobs remain gates before integration. After
merging, create the fixed beta2 branch at the returned merge SHA and read back
its SHA/tree before announcing availability. Never move either beta branch.
The original beta1 ref was reverified unchanged at
`fd976f725c2bbb111d9fe6700bcabccfab1f3774` on 2026-10-27.

This is a community-testing beta, not maturity or a stable API freeze. GitHub
tags/prereleases remain unpublished; the available connector cannot create
them and authenticated release UI access is unavailable. Straight installation
from a verified fixed branch is the supported delivery path. MELPA public
maintenance, substantive human review and acceptance remain external gates;
current policy blobs and recipe-name absence were checked on 2026-10-27.
Next: complete the beta2 publication sequence, then collect concrete application
feedback and expand actual GUI/emulator/multiplexer validation and measured
large-result rendering work. No new latency claim is made.

## Abrupt floating-popup client loss — integrated

PR #47 merged at `912c7709932826881bc6479c908e607af5eba5f5` after independent
exact-head coding-agent review and all eight jobs in
[40449522142](https://github.com/vv111y/emacs-tui/actions/runs/40449522142).
Main's tree matches reviewed `9656f8a0aed290003a0a35e743285759770351ca`.
Linux/macOS 31.1 each passed 351 ERT and actual native CAPF popup paint,
provider/style dispatch, same-child filtering, source focus/layout, navigation,
movement, accept/native undo, file base/suffix handling, exact-once exit,
read-only retry, resize and major-mode cleanup. Package build and clean installs
on 31.1/28.1 passed. Hosted multi-client and abrupt-loss checks also passed,
covering the local Unix-socket restriction without waiving those checks.

PR #48 extends the real abrupt-client-loss scenario to a floating
popup nested in the dying client's persistent input view. The driver requires
the popup's candidate in that client's actual terminal transcript before
SIGKILL. Disposal checks retain the concrete child frame, view buffer, tracked
markers, source/kill-hook identity and exact-once close count. Popup globals
must be released while the other terminal's persistent session and native input
survive. Older unsupported terminals retain the original scenario and report
popup support honestly. Independent preliminary review caught a proof gap where
a cleared session frame slot could masquerade as disposal; the captured native
frame handle is now checked directly.

Local 351 ERT, strict compilation/checkdoc, Python compilation, Lisp parsing
and strict fixture byte compilation passed. Actual local server startup is still blocked by `Operation not
permitted` on its Unix socket, before either client/popup is created; this is
not a positive native result. Exact-head independent review and hosted Linux/
macOS 31.1 painted-popup loss validation plus the full matrix subsequently passed
as recorded above.
No runtime implementation change or new latency claim is made in this unit.

This terminal boundary is now validated on the hosted matrix. Broader GUI/
physical terminal/multiplexer use and concrete consumer needs remain. The fixed
beta1 branch is unchanged; main remains experimental.

## Native completion adapter — integrated

PR #46 merged at `38891789aae720696fa96c17deaa01feb066326a` after independent
exact-head coding-agent review and all eight jobs in
[40446110274](https://github.com/vv111y/emacs-tui/actions/runs/40446110274).
Main's tree matches the reviewed `f5306d060a10535f0c9cf54e520c2ef74f7fbd54`.
Linux/macOS 31.1 each passed 331 ERT and the real popup PTY with a required
popup-only terminal paint marker, eight distinct central placements, native
typing/filtering/selection/acceptance/undo, Unicode, resize, modal coexistence
and cleanup. The failed first-head movement run below remains recorded.

PR #47 adds optional `emacs-tui-completion-mode`, using existing
completion-at-point providers instead of literal example candidates. Core does
not require the adapter. Initial native provider dispatch is manual; source
edits refresh the active captured table. The adapter preserves styles/category
overrides, predicates, captured metadata, base prefixes and outside suffixes,
and separates decorated rows from inserted values. Only visible popups activate
local navigation/accept/dismiss/move bindings. Disable restores the previous
frontend only while this mode still owns it; major-mode/source disposal and
late close callbacks release only the owning context. The literal-data demo
also now stops before a major-mode change clears its locals.

Native source inspection established that directory choices consume a matching
field separator from the preserved suffix and report `exact` when opening a new
field; other choices report `finished`. Exit callbacks receive the full
completed field including base prefix, once after successful insertion and
cleanup. Editing errors roll back; exit-callback errors preserve accepted text.
No common-prefix insertion or automatic acceptance is performed.

Local Emacs 29.3/Linux passed 351 ERT, strict compilation/checkdoc and the new
completion PTY's honest unsupported-display path through 120->90->140 resize.
Twenty new ERT cases exercise real completion protocols/styles and source
editing with modeled presentation. The first directory regression caught and
fixed a duplicated slash; a test closure's parallel binding and an initial
fixture parse error were corrected. Those failures are not counted as passes.
The new positive hosted path uses actual Lisp CAPF dispatch, terminal paint,
same-child filtering, native keys/undo, file boundaries/exit and major-mode
cleanup. Independent review, positive native 31.1 execution and exact-head
hosted runtime/package CI passed as recorded above. The actual
pinned package-build recipe built source `c7463d8` and its archive clean-installed
on local Emacs 29.3, proving the optional helper is packaged without eager core
loading. Build-tool sources were restored from their pinned upstream blobs
before this check; hosted 31.1/28.1 installation subsequently passed. Independent
review found acceptance-hook reentry could release old markers and skip the
accepted candidate's exit callback; completion results are now captured before
editing and old disposal preserves a new context. Other review fixes retain
captured case settings during metadata/exit calls, honor native nil category
overrides without reviving extra properties, and require a positive display
limit. Each has a behavioral regression. All eleven local PTY scenarios and
four reflow fault probes passed; the separate multi-client run could not create
its Unix server socket (`Operation not permitted`). Local abrupt-client-loss
coverage is likewise unavailable here, so hosted client/hangup CI remains
required. No failing check is waived.

Completion tables remain synchronous and must return promptly. The default
200-row cap bounds only display/decoration; all matches are computed/sorted.
Grouping, documentation panes, automatic initial CAPF dispatch and async
completion tables are outside this adapter's current scope. GUI/font variants,
physical terminal/multiplexer use and real abrupt popup-client loss remain
broader validation gaps. The beta1 branch remains fixed and these additions are
unreleased main development, not a new beta tag or MELPA publication.

On 2026-10-27, current MELPA policy blobs still match docs/MELPA.md; the
`recipes/emacs-tui` path still returns 404. Latest package-lint main remains
`1865be780a16098f972fef50a52b21ca6ee04df9`; its exact source blob was verified
and rerun. Only the existing main package-name advisory remains; the optional
completion helper is clean. Public maintenance and substantive
human review remain external gates; no eligibility or acceptance is claimed.
The adapter's initial review/native validation is complete; concrete popup
consumer needs and broader lifecycle/display validation remain before adding abstractions.

Updated 2026-10-27 (America/Toronto).

## Active implementation

The owner requested source-preserving ephemeral popups with eight positions
around the word at point. The new `emacs-tui-popup` presentation owns one native
child frame and a read-only view, leaving the source window/buffer and typing
focus intact. It shares update, selection, actions and disposal with existing
sessions. `emacs-tui-reposition-popup` chooses or cycles N/NE/E/SE/S/SW/W/NW.
Source glyph endpoints and actual child dimensions determine placement; edges
are clamped to the parent viewport. Wrapped/partly hidden ranges use point.
Strict native child-frame support is required; an unsupported terminal never
falls back to a split window. Popup frames are excluded from modal focus
routing, with a separate terminal-disposal hook and tracked source markers.

The new demo enables a buffer-local completion policy in the original source;
`make popup-demo` explicitly creates a centered disposable sample document.
Typing filters sample words in the same child, M-n/p selects, C-c C-p moves,
TAB accepts explicitly, C-g dismisses and C-c C-q disables. Undo stays native.
The gallery adds this inline entry and retains its chooser on unsupported
displays. Public API, controls, data effects and capability limits are documented.

Local Emacs 29.3/Linux passed 331 ERT, strict compilation/checkdoc, the modeled
matching/foreign-terminal disposal regression and the existing gallery showcase PTY.
The new real PTY verifies native wide/combining glyph bounds and rejects popup
creation without modifying/splitting the host on this unsupported display,
including 120->90->140 resize. It does NOT establish positive child-frame popup
behavior. Independent review caught a real wide-glyph undercount from the native
single-object accessor; exclusive range endpoints now correctly measure 日本=4
and é=1 terminal cells. The combining regression uses endpoint data, including
compiled-library execution. An early fixture parse error and the failing wide
probe are not counted as passes.

The new 31.1 PTY path requires actual terminal paint of a popup-only marker in
addition to Lisp frame state. It exercises original-source gallery activation,
native typing/focus/layout, eight distinct central placements, selection and
same-child filtering, explicit acceptance and native undo, Unicode, automatic
resize, modal/popup coexistence, read-only acceptance rejection and source/frame
cleanup. Older runtimes exercise the honest unsupported path. Source validity,
initialization failure, callback focus choices and terminal-identity cleanup have
ERT coverage. Initial head cb20ad1/run 40445584819 passed Linux/macOS31's 331 ERT and prior
PTYs, then failed the first west move because native coordinates and reported frame
parameters diverged. Upstream frame.c shows the direct position setter updates
TTY internal coordinates only; the parameter setter also stores left/top and
invalidates root composition. Popup movement now uses that native parameter
path, and the fixture checks both internal frame-position and reported values
with detailed diagnostics. The failed head is not counted as passing.
Native 31.1 results, exact-head independent review and passing hosted CI remain
integration gates; graphical window-manager/font variants and
real abrupt popup-client hangup remain broader validation gaps. Package build
needs hosted pinned dependencies unavailable in this local worktree.

PR #45 merged at `1b6b782b85de7fa80976341d29912960d9a079a4` after independent
exact-head coding-agent review and all eight jobs in
[40434283570](https://github.com/vv111y/emacs-tui/actions/runs/40434283570).
The reviewed tree matches main. Linux/macOS 31.1 each passed 320 ERT, actual table
rightmost-glyph visibility through 90/140 resize and the full gallery showcase.
The fixed beta1 branch remains unchanged at `fd976f725c2bbb111d9fe6700bcabccfab1f3774`.

Actual screen inspection during the gallery redesign exposed a pre-existing
fill-table bug: the rightmost digit of catalog sizes and streaming durations
was replaced by Emacs's terminal truncation glyph. The renderer allocated the
entire window body width even though native redisplay reserves a line-end cell.
The focused fix uses `window-max-chars-per-line`, which accounts for native
indicator space and font width, before subtracting any selection-mark prefix.
Fixed-width columns and their minimum-width overflow policy are unchanged.
See the native [window size API](https://www.gnu.org/software/emacs/manual/html_node/elisp/Window-Sizes.html).

The updated regression checks header/data rows with and without mark prefixes
against usable display width and preserves numeric payloads. The actual-terminal
table fixture checks the final numeric glyph's coordinates and zero horizontal
scroll after 90/140-column resize. The old core fails the revised ERT at
80 <= 79, and the old core also fails the revised actual-terminal width check
after resize. The fixed core passes both. Independent review also bypassed only the width
assertion in a temporary negative fixture; the old core then failed the final
glyph coordinate bound, confirming actual redisplay loss. Local Emacs 29.3/Linux passed 320 ERT, strict compilation and checkdoc,
the updated real table PTY, and the complete gallery showcase PTY. Actual catalog screens at 80/120 columns and
the streaming screen at 120 now show complete numeric values. Graphical/fringe
variants and physical terminal emulators remain external validation gaps.
Independent review and exact-head CI remain integration gates for this fix.

PR #44 merged at `11041dc60def1a3d57786fb1daafb731dc36c052` after independent
coding-agent review and all eight exact-head jobs in
[40433265058](https://github.com/vv111y/emacs-tui/actions/runs/40433265058).
The owner had reported repetitive gallery demos. Three new applications replace
five overlapping live-buffer examples: a three-lane task board with batch moves,
a chapter reader with a wrapped page and ancestor-path search, and a single
borrowed-window snippet picker with explicit insertion and native undo. The
gallery has eight entries; earlier buffer examples remain direct development
targets. The original graph demo and fixed beta1 ref are preserved.

Each gallery launch now asserts its distinct initial view. Four new behavior
tests cover board session isolation and batch moves; reader search, selection
and expansion; snippet insertion/cancel/native undo; and read-only rejection
followed by tracked host edits. Review strengthened undo coverage to send the
actual C-/ key without a manufactured trailing boundary. All runtime jobs passed
320 ERT. Linux/macOS 31.1 each passed the child-frame terminal showcase with
board batch moves, reader search, snippet insertion/undo, catalog actions,
native editing, 120->90->140 resize, streaming failure/recovery and cleanup.
80/120-column screen inspections confirm the new applications' distinct
presentation. Physical emulator/font and graphical display QA still need use.

PR #43 merged at `625b1ebfdb5356d79cd613a7842fb5fcb9c121c0` after independent
review and all eight jobs in
[40121665128](https://github.com/vv111y/emacs-tui/actions/runs/40121665128).
It added the catalog, streaming and layout examples plus the initial gallery.
The final head passed 316 ERT and actual terminal scenarios, including
Linux/macOS 31.1 child frames. The owner feedback now supersedes the original
ten-entry gallery presentation; passing mechanics alone did not establish
sufficient demonstration variety.

PR #42 merged at `fd976f725c2bbb111d9fe6700bcabccfab1f3774` after independent
review and all eight jobs in run 40105488355. The public fixed branch
`release/0.1.0-beta1` was created at that exact commit and read back through the
GitHub API with its README recipe and five runtime libraries. It is installable
with straight.el. Never move that branch; a future matching tag must use the
same commit. The GitHub tag/prerelease authentication blocker remains.

PR #41 merged at `46436af08bdd26fd02f43b5e0861aae79427cc7f` after independent
exact-head review and all eight jobs in
[40104813509](https://github.com/vv111y/emacs-tui/actions/runs/40104813509).
Every runtime passed 310 ERT, strict compilation/checkdoc, ten terminal
scenarios and benchmark protocol smokes. Linux/macOS 31.1 and fallback runtimes
passed actual PTY table resize with the fill column matching live width at both
sizes. The package snapshot built and clean-installed on 31.1/28.1.

PR #40 merged at `e761ac8ff3f72e652b278b13df2e4109f2289000` after independent
exact-head review and all eight jobs in
[40098931357](https://github.com/vv111y/emacs-tui/actions/runs/40098931357).
Every runtime passed 308 ERT, strict compilation/checkdoc, ten terminal
scenarios and benchmark protocol smokes. The package job proved literal header
`0.1.0-beta1` and canonical package version `0.1.0beta1`, built the disclosed
dated recipe snapshot and clean-installed the identical archive on 31.1/28.1.
Latest package-lint retained only the disclosed package-name advisory. The beta
tag and GitHub prerelease are not yet published: the available GitHub connector
cannot create releases, and the release UI requires an authenticated browser
session. Do not claim the tag or prerelease exists until that external step is
complete.

The 0.1.0-beta1 release candidate packages the reviewed public surface for
community testing. The main package metadata uses the prerelease version,
README installation instructions pin `release/0.1.0-beta1` with a file-filtered
straight.el recipe, and CHANGELOG.md records scope, compatibility and known
limits.
The beta is explicitly experimental: it is neither a stable API promise nor a
MELPA publication. Tagging and a GitHub prerelease require exact-head review,
all eight CI jobs and a clean install of the built package artifact.
Exact-head release review found that Emacs 29 package-vc recursively compiles
the repository's tests and benchmarks, producing build-only failures and an
overbroad installation. That path is intentionally omitted; the documented
straight.el recipe selects only `emacs-tui*.el` from the pinned release ref.
The unsubmitted package-build recipe still creates a dated MELPA-style snapshot
archive for clean-install testing. Release CI now separately parses the source
with package.el and asserts header `0.1.0-beta1` and canonical package version
`0.1.0beta1`; the snapshot filename is not presented as the GitHub beta artifact.

The beta retains the `emacs-tui` package name to match the repository and
established API prefix while avoiding the existing `tui-*` namespace. The one
latest-package-lint redundant-`emacs` warning remains disclosed rather than
suppressed. An eventual MELPA recipe will explain that decision and follow a
maintainer-requested rename if required.

PR #39 merged at `cf922d8ed8407bfcf39e7710de522de649d8e888` after independent
exact-head review and all eight jobs in
[40097927533](https://github.com/vv111y/emacs-tui/actions/runs/40097927533).
Every runtime passed 308 ERT, strict compilation/checkdoc, ten terminal
scenarios, four reflow fault checks, three Python regressions and original plus
multi-term source/bytecode benchmark smokes. The actual recipe archive built and
clean-installed on 31.1/28.1. Linux/macOS 31.1 each passed real abrupt
emacsclient SIGKILL with exactly-once disposal, stale-publication rejection,
survivor native input and final cleanup. The lifecycle restores a remembered
live owned child after delayed native fallback while preserving explicit parent
focus, background focus, close-callback choices, foreign surfaces and graphical
frames. Failed runs 40097033208 and 40097308643 exposed respectively a fixture
hook-scope mistake and the real delayed macOS ordering; neither is counted as
passing.

PR #38 merged at `c6cd5755cfdfbd635a99180c5d87102d21a889ed` after independent
exact-head review and all eight jobs in
[40096001194](https://github.com/vv111y/emacs-tui/actions/runs/40096001194).
Every runtime passed 307 ERT, strict compilation/checkdoc, nine terminal
scenarios, four reflow fault checks, three Python regressions and original plus
multi-term source/bytecode benchmark smokes. The actual recipe archive built and
clean-installed on 31.1/28.1. Linux/macOS 31.1 each passed native direct layout
selection in the persistent fixture; no failed or superseded run is counted.

PR #37 merged at `0645f8f22b1b4d4e24dc04438f18a9c54932b15c` after independent
exact-head review and all eight jobs in
[40095526862](https://github.com/vv111y/emacs-tui/actions/runs/40095526862).
Every runtime passed 299 ERT, strict compilation/checkdoc, nine terminal
scenarios, four reflow fault checks, three Python regressions and original plus
multi-term source/bytecode benchmark smokes. Linux/macOS 31.1 each explicitly
passed the complete two-real-terminals native-child-frame scenario, including
survivor typing and final owned-buffer/frame/hook cleanup. The actual recipe
archive built and clean-installed on 31.1/28.1. Earlier failed heads are not
counted as passing. Abrupt hangup and physical emulator/GUI QA remain unverified.

Direct layout selection adds emacs-tui-set-layout with columns/rows/grid and
an interactive name chooser. A prefix on existing C-c C-l chooses by name;
ordinary cycling remains unchanged. Invalid values or repurposed surfaces are
rejected before state changes. An unchanged choice does not reflow/render;
a choice while maximized records the restoration layout without replacing the
pane. Focus, input/undo/narrowing, reading positions, queries and marks survive.
The dashboard's Actions view selects a layout without refreshing source snapshots
or restarting the application timer, including while updates are paused.

Local 307 ERT and strict compilation/checkdoc passed on Emacs 29.3/Linux.
Eight new regressions cover state preservation, no-op/maximized rendering,
invalid/foreign surfaces, cancellation and post-prompt revalidation, ephemeral
query/origin independence and paused dashboard choices. The updated persistent
PTY fixture passed its actual native minibuffer chooser, maximize/choose/restore
and original automatic resize/action assertions. Original and multi-term source/
fresh-bytecode benchmark smokes plus three Python regressions also passed;
these are functional smokes, not new latency evidence.

The installed client now selects layouts during native input undo and maximized
view use. Real pinned recipe build/fresh 29.3 installation passed from a minimal
committed packaging snapshot, not a complete checkout or public feature head.
Synthetic commit: 425e4f4401078593e79df508c142ae1fd01ed811; artifact SHA256:
12e40db61276dc15b40bcbec54e7b280f871dcc307ece7ec662f620d8534402a.
Independent review reproduced the identical archive/install and verified its
library/client identity. Additional probes cover embedded host restoration and
failed-reflow disposal; no API effect or performance guarantee was added.
Next: community beta feedback, actual XOB adapter work and broader display QA.
Stable/MELPA status has not been reached; substantive usage, external
maintenance history and MELPA's human-review checkpoint remain.

PR #36 merged at `59795f276f61a866f8104459b5f354fb6f5c82f7` after independent
exact-head review and all eight jobs in
[40088634179](https://github.com/vv111y/emacs-tui/actions/runs/40088634179).
Runtime validation passed 286 ERT, strict compilation/checkdoc, eight terminal
scenarios, four reflow fault checks, three Python regressions and original plus
multi-term source/bytecode benchmark smokes. The expanded installed-client
checks passed against the same real recipe archive on 31.1 and 28.1.

Two-terminal validation now starts a private server in an interactive Emacs on
one PTY and attaches a second actual PTY with emacsclient. Both clients mount
independent input/list interfaces, selecting native child frames when supported.
The driver sends real terminal keys, updates A while B owns native focus, resizes
each terminal independently, deletes B's parent frame, then continues editing A.
Assertions cover terminal/surface identity, input, selection, marks, background
focus preservation, automatic reflow, cancellation, stale publication, buffers,
close callbacks, host edits and final hook/frame cleanup. The driver has one
45-second deadline and always reaps its dedicated process groups and PTYs.
This is an additional required tty-smoke scenario; EMACSCLIENT selects the
client executable when it is not on PATH.

Local 286 ERT, strict package/example compilation and checkdoc passed on
Emacs 29.3/Linux; the new fixture also passed strict compilation/checkdoc and
Python syntax validation. Its real
local execution could not start the private server: this host rejects the Unix
socket with make-network-process "Operation not permitted". This is not a
passing two-client test. Initial CI 40092353647 caught a fixture state bug:
adding absent plist keys detached the association's recorded state. Mutable keys
are now preinitialized. Review also required waiting for both providers and
checking both resize dimensions. Revised run 40092491823 passed the complete
flow on Linux 28.1/28.2/29.4/30.2 and macOS 30.2, but native-child-frame 31.1
stalled after switching to terminal A. Diagnostic run 40092856451 confirmed that focus-in events alone do not fix
31.1: incoming A keys dispatch to its parent host buffer instead of its child.
The driver retains a bounded native command trace. These failed runs are not
counted as passing.

Native terminal input routing now remembers the last owned interface frame on
each terminal and filters incoming cross-terminal switch-frame events to that
live child, including nested children. Same-terminal explicit frame selection,
GUI frames, unrelated roots and invalidated surfaces keep normal Emacs routing.
No redirect-frame-focus is installed: Emacs retargets those redirects on frame
selection and could send one terminal's input to another. The observer/advice
exist only while native TTY child sessions remain; nested close restores an
owned ancestor's remembered focus without selecting a background frame.

The first routing fix passed native terminal returns and numeric prefixes, but
run 40093402855 exposed a second case: deleting B implicitly selects A's parent.
Scoped before/after frame-deletion hooks now restore A's remembered owned child
only if deletion removed the selected frame and changed native selection.
The late tracker honors application delete hooks and close-callback focus effects;
a captured late hook cannot recreate pending records after the last interface closes. Background deletion, explicit parent
focus and repurposed surfaces do not capture focus. Pending deletion records and
all routing hooks are released with the last native terminal interface.
Run 40094038742 still reached the survivor-input failure. Close-callback focus
recording now distinguishes an actual application selection change from an
unchanged callback observing Emacs's implicit fallback. Bounded diagnostics now
include routing/deletion-hook ordering and remembered focus flags. Native proof
is still required; no unsuccessful iteration is treated as passing.
The resulting native trace confirms server disposal defers frame hooks until
frames are dead. A late synchronous delete-terminal hook now records live-frame
selection before that server path. Completed records are consumed once before
post-command focus tracking can classify Emacs's fallback parent as deliberate.
Both observer-before-frame-hook and deferred-after-before orderings have modeled
coverage; a handled deletion cannot recapture later explicit parent focus.
Abrupt client hangup/force-noelisp terminal disconnection remains untested and is
separate from this explicit native parent-frame deletion scenario.
Run 40094695876 now completes native returns, resizes, prefix commands, client
deletion and survivor editing on Linux31.1, then fails the final owned-buffer
cleanup assertion. It is not a passing run. Diagnostics report the specific live
buffer and kill result. Explicit focus recording is now separate from automatic
post-command deletion consumption so pending cleanup cannot override an actual
application selection; the reviewed pending-callback regression is covered.
Run 40095035338 identified a B input buffer with no kill attempt: native frame
hook disposal aborted in window cleanup before reaching buffer release. The
frame-deletion hook now drops its window/frame claims before closing, leaving
physical subtree destruction to Emacs while releasing buffers and providers.
A new persistent/ephemeral regression injects a dying-window error: the old hook
fails, the revised hook avoids the invalid window mutation and releases buffers,
origin markers, requests and callbacks. The terminal assertion remains intact.
No buffer query is bypassed and no failed run is counted as passing.

Local 299 ERT, strict compilation/checkdoc passed on Emacs 29.3/Linux. Thirteen new
modeled routing tests cover event identity, prefix preservation, explicit parent
selection, background memory, dead/foreign/GUI roots, terminal mismatch, nested
close, immediate application focus changes, implicit deletion fallback versus
background/explicit/foreign selection and final observer/advice cleanup with unrelated advice retained. These
are unit boundaries, not positive native display evidence. The actual two-PTY
fixture now also checks a numeric prefix across terminal return, continued
survivor editing and final routing-hook cleanup. Independent exact-head review
and all eight fresh CI jobs, including positive native 31.1 Linux/macOS evidence,
are required before integration. No new
performance, physical emulator, GUI or long-term maturity claim is made.

PR #35 merged at `e4be92a9a941526ab1e4081e0a1f8f106de8ae68` after independent
exact-head review and all eight jobs in
[40088239840](https://github.com/vv111y/emacs-tui/actions/runs/40088239840).
Runtime jobs passed 286 ERT, strict compilation/checkdoc, eight terminal
scenarios, four reflow fault checks, three Python regressions and original plus
multi-term source/bytecode benchmark smokes. Linux/macOS 31.1 explicitly passed
the updated tree fixture with native child frames. The archive built and
clean-installed on 31.1/28.1.

API readiness now documents the supported application surface, opaque handles,
experimental 0.x migration/versioning rules and future stable 1.x requirements
in docs/API-STABILITY.md. This is a policy, not a compatibility freeze or a
stable/MELPA claim. Effects remain application-owned, projection callbacks pure,
and cross-view updates are not declared transactional. The naming warning,
public maintenance, substantive usage and human-review gates remain unresolved.

The clean installed-client script now exercises named selection, first/last,
bulk marking/inversion, live input titles with native undo, whole-tree controls
and hidden-view focus using public APIs. Local real recipe build and fresh
installation passed on Emacs 29.3 using the pinned build tools and a minimal
committed packaging snapshot (five libraries, LICENSE and packaging fixtures),
not a complete checkout or public PR commit. Its local synthetic commit was
1718d277de94f82c973e951b0d1cdfd17900e338; artifact SHA256 was
25c8d1cd22d7328385da1ceb0004010ef76f3c3011aad8f543f81855717222cb.
Independent review verified snapshot/file identity and reproduced the same
archive hash and clean install. The edited client also passed strict compilation
with the library loaded for compiler declarations, and checkdoc. No production
Lisp changed in this unit; full exact-head recipe/install coverage on 31.1/28.1
and all eight current-head CI jobs remain integration gates.
Next: concrete consumer controls/layouts, broader actual display validation,
substantive usage and release readiness. No new latency or maturity claim.

PR #34 merged at `ef0c0043204c91a6cedcb4c534dbf0bd3928b76f` after exact-head
independent review and all eight jobs in
[40084992407](https://github.com/vv111y/emacs-tui/actions/runs/40084992407).
Runtime jobs passed 281 ERT, strict compilation/checkdoc, eight terminal
scenarios, four reflow fault checks, three Python regressions and original plus
multi-term source/bytecode benchmark smokes. Linux/macOS 31.1 passed the native
persistent fixture's literal-percent caption checks; archive build and clean
identical-artifact installs passed on 31.1/28.1.

Whole-forest tree controls add expand-all/collapse-all commands with optional
session/view ID and tree-buffer C-c + / C-c - bindings. Operations stage a new
expansion table and render before committing; failed edits retain expansion,
selection, marks and display. They use the existing child index, preserve hidden
marks and named hidden-panel focus, invoke no application actions, and reject
local search or invalidated surfaces. Collapse selects the selected node's root
ancestor rather than arbitrarily jumping to the first root. Source replacement
retains surviving expanded identities; new branches still start collapsed.

Local 286 ERT and strict compilation/checkdoc passed on Emacs 29.3/Linux.
Five new cases cover nested/multiple roots, hidden marks and panels, search,
native keys, editing failure/retry, cached accessors, action boundaries and empty
forests. The existing real tree fixture now exercises full expand/collapse keys
before its selection, marks, source replacement, maximize, resize and action
sequence. Independent review and all fresh CI jobs remain integration gates. Local eight
terminal scenarios and four reflow fault checks passed, including the new tree
keys. Three Python regressions and original/multi-term source/bytecode benchmark
smokes passed. Independent probes also verified fresh marked objects after
source replacement, new branch expansion, hidden preview point/narrowing and
foreign-window cursor preservation. MELPA policy hashes were rechecked on
2026-10-24 and remain unchanged. No new performance claim or stable/MELPA acceptance claim.
Next work includes consumer-driven layouts/controls, installed-client coverage,
API stability/migration policy, broader display testing and substantive usage.

PR #33 merged at `190b5e62fd635baedc5877e95b988ef0c201eeff` after independent
exact-head review and all eight jobs in
[40082652440](https://github.com/vv111y/emacs-tui/actions/runs/40082652440).
All runtime jobs passed 274 ERT, strict compilation/checkdoc, eight terminal
scenarios, four reflow fault checks, three Python regressions and original plus
multi-term source/fresh-bytecode benchmark smokes. Linux/macOS 31.1 logs confirm
native child frames and delayed-success/specific-disabled-rejection input/tree
checks. Archive build and identical-artifact installs passed on 31.1/28.1.

Live view metadata adds string :title updates to emacs-tui-update. Title-only
changes update the header without filtering, cell projection or content edits;
native undo/narrowing/cursor/scroll, selection, marks, queries and hidden views
are preserved. Combined data/title changes use existing staged rendering and
commit the title only after success. Empty string clears a title; omitted title
retains it and nonstrings are rejected. No new public function is needed.
The dashboard displays snapshot buffer/process counts and paused/running status.

Local 281 ERT, strict compilation/checkdoc passed on Emacs 29.3/Linux. The prior
full eight-scenario/four-fault terminal suite passed, then the modified persistent
scenario was rerun with a live title checked across both resize steps. Seven new
ERT cases cover nonprojecting table updates, editable undo/narrowing, combined
failure/retry, hidden preview reveal/maximize, validation/clearing/omission and
actual dashboard refresh/pause behavior. A native terminal probe also caught
existing percent-format expansion in view titles. Headers now escape percent
constructs while retaining face/help properties and stored literal text; the persistent fixture checks
actual formatted header output for Live 50%busy across both resizes. The old
probe failed before this fix. Independent exact-head review and all
eight current-head CI jobs remain integration gates. Three Python regressions and
all original/multi-term source/fresh-bytecode benchmark smokes also passed.
MELPA policy hashes were rechecked on 2026-10-24 and are unchanged.
No new performance claim.
Remaining work includes concrete richer controls/layouts, broad actual display
validation and long-term use; MELPA maintenance-history/human review and the
main-name lint question remain unresolved external/readiness gates.

PR #32 merged at `e2cb99115807bfce5cf63bea2bbf7d681077102e` after independent
exact-head review and all eight jobs in
[40082067979](https://github.com/vv111y/emacs-tui/actions/runs/40082067979).
Every runtime job passed 274 ERT, strict compilation/checkdoc, eight terminal
scripts, three Python regressions and original plus multi-term source/fresh-
bytecode benchmark smokes. Linux/macOS 31.1 logs confirm native child frames;
the archive built and clean-installed on 31.1/28.1. Independent review verified
all 880 raw profile records, summaries, source/artifact hashes and limitations.

The four remaining resize fixtures (ephemeral, embedded, input and tree) now
wait for automatic cached-geometry convergence within their existing 100-poll
bounds. No refresh is forced and previous assertions remain. This complements
the already corrected persistent, table and graph fixtures. Local 274 ERT,
strict compilation/checkdoc and all eight ordinary PTY scenarios passed on
Emacs 29.3/Linux. A 16-case old/new fault matrix shows old ephemeral/embedded
assert too early with a delayed hook; all revisions tolerate the delay. Old
input/tree also pass with automatic reflow disabled, revealing missing coverage.
All revisions instead fail at their original deadline when reflow is disabled.
Independent review reproduced all eight representative old/new probes.

The reproducible test/tty-reflow-probe.el accepts a selected resize fixture and
an explicit delay/disabled fault. It observes the origin frame even when a
child frame is selected, prefers newer source before loading the library, and
preserves normal native input/action/resize assertions. Local strict compile
and checkdoc passed the helper. Its 14-case matrix covers delayed success and
bounded missing-hook failure in all seven live-resize scenarios. The repeated-
lifetime fixture creates sessions after each resize and has a different purpose.
The default tty-smoke target now also verifies four representative input/tree
fault cases. The driver requires the specific bounded failure output and exit
status; unrelated failures cannot satisfy its negative check. All four local
driver cases passed. Independent final review and all eight fresh CI jobs remain
integration gates.
These diagnostics do not establish emulator paint, physical macOS, GUI or
multiple-terminal correctness. Runtime code and published performance sources
are unchanged by this validation work.

PR #31 merged at `1a0616c87f717a6ee14d02a7d238f1a33cf19712` after independent
exact-head review and all eight jobs in
[40081401204](https://github.com/vv111y/emacs-tui/actions/runs/40081401204).
All runtime jobs passed 270 ERT, strict compilation/checkdoc, eight PTY scripts,
three Python regressions and both benchmark smoke modes; the archive built and
clean-installed on 31.1/28.1. Linux/macOS 31.1 confirm native child frames for
the new graph-history fixture as well as earlier owned-surface scenarios. The
previous failed run described below was corrected and is not waived.

Multi-term list/table filtering now quotes literal patterns once per query and
prepares each item's searchable label/full column values once per search,
instead of repeating column projections for every term. There is no persistent
search cache; every filter/source replacement reads current values. Empty-term,
application-owned query and tree paths retain their existing behavior.

Local 274 ERT, strict compilation/checkdoc and eight PTY scripts passed on
Emacs 29.3/Linux. The projection-work regression fails on the prior code
(18 calls instead of eight for three rows/two columns/three terms, including
the surviving row's render). Other new cases retain literal-regexp characters,
Unicode/combining glyphs, repeated terms, descending sort, hidden marks,
original objects, fresh replacement values and propertized plain strings.
Independent differential checks compare old/new matching and selection over
a query matrix, both list/table representations and both sort directions; a real
projection-error probe preserves query, visible snapshot, marks, text/properties
and modification tick, then recovers on retry.

Expanded benchmark smoke checks passed the original five workloads and new
multi-term list/table cases in both source and freshly compiled modes, plus
three Python process regressions. The opt-in --filter-prefix preloads actual
native input before measured edits, requires an all-row initial match, and
records its value. Repeated sequential bytecode profiles retain 440 raw records
per run at bench/results/2026-10-24-multiterm, with identical fixture hashes and
verified before/after source provenance. On this Emacs 29.3/Linux configuration,
10,000-row table native x insertion p50/p95/p99 changed from
508.011/624.640/628.287ms to 199.834/251.801/261.690ms; DEL retaining two terms
changed from 600.395/698.465/779.584ms to 449.426/528.104/549.279ms. Median
immediate-command cons cells changed from 205,328 to 85,308 for x and 270,320
to 210,310 for DEL. Each operation has only 50 measured samples; p99 is the
maximum. Some list tails did not improve. These are one-host PTY-output results,
not emulator paint or a cross-platform guarantee. Large-table full rebuilds
remain costly. Pilot data is excluded from the published pair. Independent
exact-head review and all eight fresh CI jobs passed as recorded above.

PR #30 merged at `dc086fb71117f82803c13ce3d42ec0b5ee3ba9c7` after independent
exact-head review and all eight jobs in
[40077079927](https://github.com/vv111y/emacs-tui/actions/runs/40077079927).
Runtime jobs passed 263 ERT, strict compilation/checkdoc, seven PTY scripts,
three Python regressions and both benchmark smoke modes. Linux/macOS 31.1 logs
confirm native terminal child frames, including the persistent endpoint keys;
the package archive built and clean-installed on 31.1/28.1.

The graph application now records inspected node identities in private
per-session Back/Forward stacks. Named actions are available in all four views
and from native query input; application bindings C-c [ / C-c ] are available
in view buffers. Reinspection does not duplicate visits, new branches discard
the old forward route, and history is recorded only after successful inspection.
History restores preview/links without taking over queries, focus or node marks.
Link replacements retain ordinary identity-based selection/mark pruning. Explicit
commit still uses the focused selection/marks, not a hidden history destination.
No core history framework, Org dependency or universal navigation policy is added.

Local 270 ERT, strict compilation/checkdoc, eight PTY scripts, three Python
regressions and both benchmark modes passed on Emacs 29.3/Linux. Seven new ERT
cases cover links/backlinks, repeats/branches, native menus/keys, query/focus/
marks, noninspection navigation, failure/retry, independent simultaneous sessions
and explicit commitment. The new real-PTY graph fixture exercises native history
keys, retained query/marks, maximize/restore, automatic reflow at both existing
resize sizes and final explicit commitment. Review caught an initial fixture
assertion reading a timer callback's current-buffer point; it now explicitly
reads the query buffer. That failed run is not counted as a pass. Independent
review also passed a 300-operation traversal oracle. Exact published-head review
and all eight final CI jobs passed as recorded above. Multi-view application updates
are sequential, not a new cross-view transaction: a failed inspection can leave
partially updated panes, but history stacks remain retryable and unchanged.

Initial graph-history CI run
[40081143920](https://github.com/vv111y/emacs-tui/actions/runs/40081143920)
passed seven jobs; macOS 31.1 passed all 270 ERT then failed the existing table
PTY fixture's geometry equality assertion. The table fixture now also waits
for automatic cached-geometry convergence before its unchanged assertions,
within the original 100-poll bound. No refresh is forced. A delayed-handler
probe fails the old fixture and passes the revised fixture at both sizes;
disabling the handler still produces a bounded failure. Independent review
repeated all three probes. The failed CI run is not counted as passing;
fresh exact-head review and all eight jobs subsequently passed as recorded above.

PR #29 merged at `caffcd7a998a7c424702e022e0787e4eada84a16` after independent
review and all eight jobs in
[40075028893](https://github.com/vv111y/emacs-tui/actions/runs/40075028893).
Layout is a bundled helper with authoritative metadata in the main library;
executable forms are unchanged. Only the main-name lint warning remains.
MELPA policy blobs were rechecked on 2026-10-24 and match docs/MELPA.md. Public
maintenance and human review remain external gates. Next: concrete consumer
controls, measured large-table rendering work and broader actual GUI/emulator/
multiplexer/multiple-terminal validation. No new performance baseline is claimed.

PR #28 merged at `32b558f360b5c83d6c0579b36a5c8644069e6c0f` after exact-head
independent review and all eight final-head CI jobs in
[40074519434](https://github.com/vv111y/emacs-tui/actions/runs/40074519434).
Runtime jobs passed 257 ERT, strict compilation/checkdoc, seven PTY scripts,
three Python regressions and all five source/fresh-bytecode benchmark smoke
workloads. The actual recipe built and the resulting archive clean-installed
on 31.1/28.1. Linux/macOS 31.1 logs explicitly confirm native child frames for
ephemeral/persistent/input/tree and repeated-lifetime fixtures, including new
bulk keys in the ephemeral fixture. Agent review additionally verified native
bulk bindings and insertion-hook rollback with properties/highlight retained.

Packaging cleanup makes the layout file an explicit helper of emacs-tui, like
the table/tree/action modules, instead of repeating standalone version/dependency
metadata. `package-lint-main-file` now points to the actual main library, and
the header describes general text interfaces. All executable Lisp forms are
unchanged. Latest upstream package-lint reports only the remaining main package
name warning; the layout warning is resolved through correct package ownership,
not suppression. Local 257 ERT, strict compilation and checkdoc passed on Emacs
29.3/Linux. Independent review and fresh current-head recipe/installation and
runtime CI remain integration gates. Preliminary independent review confirmed
all executable forms match, metadata ownership is appropriate and only the
main-name lint warning remains. The remaining naming warning and external
MELPA gates are not waived.

PR #27 merged at `b532d7bcd73fbaa342bde5271e1ce94a054ed75e` after exact-head
independent review and all eight CI jobs in
[40074067095](https://github.com/vv111y/emacs-tui/actions/runs/40074067095).
Runtime jobs passed 249 ERT, strict compilation/checkdoc, seven PTY scripts,
three Python regressions and all five source/fresh-bytecode benchmark smoke
workloads; package build and clean installs passed on 31.1/28.1. This closes the
focus-cycling ownership hole described below.

Bulk marking adds `emacs-tui-mark-all` and `emacs-tui-invert-marks`, accepting
optional session/view ID. They operate on the current list/table/tree projection,
including off-screen rows while preserving marks on filtered items/collapsed
descendants. Operations on named hidden panels preserve current focus. Each
command stages a copied identity table and renders once; empty projections are unchanged. Native keys
are C-c * and C-c C-t; ordinary query characters remain editable. No exploration,
context-action or commit callback runs implicitly. The graph example documents
the keys and tests bulk selection followed by explicit ordered commitment.

Local 257 ERT, strict compilation/checkdoc, seven PTY scripts, three Python
regressions and both benchmark modes passed on Emacs 29.3/Linux. Eight new ERT
cases cover hidden marks/panels, tree collapse, source order with descending
sort, unchanged selection, 200 projected cells once per bulk operation, failure
rollback/retry, invalid targets, native editing/keys and explicit graph commit.
The real ephemeral PTY fixture now exercises both bulk bindings before its
original selection/resize/commit sequence. Exact-head independent review and
all eight final-head CI jobs passed as recorded above. Independent review
passed 257 ERT and the updated real-PTY bulk bindings, plus an insertion-hook
failure probe preserving marks, properties, highlight bounds and recovery.
Next: consumer-driven controls, actual GUI/emulator/multiplexer and multiple-terminal validation, real usage
and measured remaining rendering bottlenecks. No new latency claim is made.

PR #26 merged at `c9871bc591295b2c640c63d9e606f7f7099a9cec` after independent
implementation/fixture review and all eight final-head CI jobs in
[40073781778](https://github.com/vv111y/emacs-tui/actions/runs/40073781778).
Runtime jobs passed 247 ERT, strict compilation/checkdoc, seven PTY scripts,
three Python regressions and all five source/fresh-bytecode benchmark smoke
workloads; package build and clean installs passed on 31.1/28.1.

PR #27 makes focus cycling reject invalidated surfaces before logical focus changes or
hidden-panel reuse. The named focus API already had this guard. Without it, a
maximized session whose visible pane was repurposed could replace an unrelated
buffer when cycling to a hidden panel; a visible foreign pane could also acquire
native focus. Two regressions fail on prior code and pass with this guard. They
cover ephemeral/persistent maximized cases and visible foreign panes, both
cycling directions, logical/native focus, pane mapping, buffer content/cursor/
scroll and normal disposal. Local 249 ERT, strict compilation/checkdoc, seven
PTY scripts, three Python regressions and both benchmark modes passed on Emacs
29.3/Linux. Independent review also confirmed valid deleted-window
reveal and preservation of unrelated windows outside the owned subtree. Its final-head CI run is linked above.

Recent integrated behavior:

- PR #23 exposes named view focus/selection and hidden-panel reads without
  implicit actions; the dashboard explicitly inspects a process's buffer.
- PR #24 adds 75 batch and 45 real-PTY lifetimes at three sizes, preserving a
  second session and checking timers/processes/buffers/markers/windows/frames,
  stale callbacks, host edits and hook cleanup. Fault probes detect skipped
  cancellation and invalid stale acknowledgements. Linux/macOS 31.1 uses native
  child frames; other tested runtimes use ordinary windows.
- PR #25 stages mark changes until successful rendering. Projection and native
  after-change-hook failures preserve marks, hidden targets, indicators and
  highlight; retries work. Independent review verified old-code failures,
  table isolation, hidden-panel clearing and property/overlay rollback.
- PR #26 prevents late renders from moving unrelated window cursors before
  ownership invalidation. Tests cover list updates/marks/navigation and provider
  preview replacement, then normal refresh/cancellation and stale rejection.

Initial PR #26 CI run 40073514199 failed Linux 29.4's persistent resize assertion:
terminal dimensions matched while cached geometry differed. All 247 ERT passed
there. The fixture now waits for terminal dimensions and automatic cached
geometry convergence within its original 100-poll bound, retaining assertions
and forcing no refresh. A delayed-hook probe fails the old fixture and passes
the revised one; disabling automatic reflow still fails at the bound. Independent
review repeated these probes. The failed run was not counted as a pass; the
fresh final-head run linked above passed all eight jobs. This identifies an
ordering-sensitive assertion, not a proven cause of every resize race.

Published source pairs and the full bytecode profile retain raw samples,
environment, source/artifact hashes and percentiles under bench/results. The
compiled profile has 1,100 records and separate controlled-provider stages.
On that Emacs 29.3/Linux configuration, 10,000-row table navigation p50/p95/p99
was 0.546/0.789/0.849ms; full table query clearing was 272.447/320.990/333.227ms.
These are historical measurements with interpreted fixture callbacks and native
JIT off, not new measurements of this ownership change. Full table rebuilds and
nonempty matching remain measured bottlenecks for later work.

Latest upstream package-lint now reports the one documented main-name warning.
The package remains experimental. GUI/emulator/multiplexer, physical macOS and
multi-terminal validation and substantive real usage remain incomplete. Repeated
bounded stress and hosted PTYs do not establish all display combinations or
long-term stability. Public-maintenance and human-review MELPA gates remain.

## Implementation and handoff

This is an experimental development release, not a stable or MELPA package.

Scope clarification from the owner, 2026-10-23: build a general-purpose TUI
toolkit for Emacs. The ephemeral XOB-style workflow is one supported application
pattern. Persistent applications and embedded panels must not require query
input, an origin marker, or commit-then-close. See docs/DESIGN.md and the new
immediate priorities in ROADMAP.md. PR #6 merged the persistent lifecycle and
dashboard. PR #7 added borrowed-window embedding over the same primitives.

- [PR #1](https://github.com/vv111y/emacs-tui/pull/1): merged foundation with
  editable temporary queries, independent list/text views, explicit selection
  and atomic origin-buffer commit, columns/rows/grid, native child frames and
  an ordinary-window fallback.
- [PR #2](https://github.com/vv111y/emacs-tui/pull/2): merged automatic resize
  reflow, state preservation, owned-subtree invalidation and real TTY resizing.
- [PR #3](https://github.com/vv111y/emacs-tui/pull/3): merged debounced async
  providers with cancellation, streaming replacement updates, obsolete callback
  rejection, failure recovery and a chunked buffer-search example.
- [PR #4](https://github.com/vv111y/emacs-tui/pull/4): merged opt-in
  multi-selection, stable identity marks, non-color indicators and explicit
  batch commits. Final-head CI also passed on all four supported test versions.
- [PR #5](https://github.com/vv111y/emacs-tui/pull/5): merged by the owner;
  general-purpose toolkit scope and lifecycle priorities are now on main.
- [PR #6](https://github.com/vv111y/emacs-tui/pull/6): persistent lifecycle,
  dashboard, explicit actions and application cleanup.
- [PR #7](https://github.com/vv111y/emacs-tui/pull/7): borrowed-window embedding
  and host restoration without changing host buffer contents.
- [PR #8](https://github.com/vv111y/emacs-tui/pull/8): composed application/view
  keymaps and a public current-session accessor.
- [PR #9](https://github.com/vv111y/emacs-tui/pull/9): sortable table columns,
  structured dashboard rows and failure-safe updates.
- [PR #10](https://github.com/vv111y/emacs-tui/pull/10): preview reading position
  survives focus changes and unchanged updates.
- [PR #11](https://github.com/vv111y/emacs-tui/pull/11): native editable inputs,
  application change callbacks and a persistent composer with explicit copying.
- [PR #12](https://github.com/vv111y/emacs-tui/pull/12): finite tree views, stable
  expansion/hidden marks, ancestor search context and a buffer-tree application.
- [PR #13](https://github.com/vv111y/emacs-tui/pull/13): maximize/restore and
  per-view hidden reading state, including native background input edits.
- [PR #14](https://github.com/vv111y/emacs-tui/pull/14): required ARM64 macOS
  30.2/31.1 validation alongside the four-version Linux matrix.
- [PR #15](https://github.com/vv111y/emacs-tui/pull/15): independent per-view
  queries and native persistent search composition without replacing sources.
- [PR #16](https://github.com/vv111y/emacs-tui/pull/16): explicit named context
  actions over marks/current objects with native-menu target revalidation.
- [PR #17](https://github.com/vv111y/emacs-tui/pull/17): real candidate-recipe
  builds, clean archive installations and declared-floor Emacs 28.1 CI.
- [PR #18](https://github.com/vv111y/emacs-tui/pull/18): real native-key/PTY
  benchmark with separate command/render/provider stages and source provenance.
- [PR #19](https://github.com/vv111y/emacs-tui/pull/19): cached selection
  navigation with raw measured latency/allocation evidence and edge-case fixes.
- [PR #21](https://github.com/vv111y/emacs-tui/pull/21): bounded benchmark
  lifecycle, PTY exit drainage, diagnostics and descendant cleanup.
- [PR #20](https://github.com/vv111y/emacs-tui/pull/20): empty-term predicate
  fast path and reviewed native query-clear latency/allocation evidence.
- [PR #22](https://github.com/vv111y/emacs-tui/pull/22): isolated source/bytecode
  benchmark modes and a reviewed full compiled-library workload profile.
- [PR #23](https://github.com/vv111y/emacs-tui/pull/23): named view focus and
  projected selection APIs, with dashboard process-buffer inspection.
- [PR #24](https://github.com/vv111y/emacs-tui/pull/24): repeated batch/native
  terminal ownership stress, cancellation and live-session isolation.
- [PR #25](https://github.com/vv111y/emacs-tui/pull/25): mark targets and
  indicators remain consistent after projection or native editing failures.
- [PR #26](https://github.com/vv111y/emacs-tui/pull/26): late view updates
  preserve repurposed-window cursors; bounded automatic resize synchronization.
- [PR #27](https://github.com/vv111y/emacs-tui/pull/27): view cycling validates
  ownership before changing focus or revealing hidden panels.
- [PR #28](https://github.com/vv111y/emacs-tui/pull/28): bulk projection marking
  and inversion, hidden-mark retention and explicit graph batch commitment.

API and runnable examples are in README.md. `make demo` explores an in-memory
sample graph; `make async-demo` searches buffer snapshots. Marks are per view
and preserve local filtered-hidden selections. Source replacement prunes absent
identities; async query supersession clears provider-owned results and marks.
The graph demo deliberately filters only nodes so forward/backlinks remain
navigable. Query edits there may prune marks as its source results change.

## Validation

Current evidence is recorded above. Runtime CI covers Linux Emacs 28.1,
28.2, 29.4, 30.2 and 31.1, plus ARM64 macOS 30.2 and 31.1. Each job runs ERT,
strict compilation, checkdoc and ten real terminal scenarios. Emacs 31.1 uses
native TTY child frames for ephemeral/persistent/input/tree interfaces on both
platforms; earlier versions use windows. Embedded/table scripts borrow a
window. Resize coverage is 120x40 -> 90x30 -> 140x45, including maximize/restore, graph history
and explicit action-menu invocation. A real `cat` subprocess test covers
streaming and disposal. The separate package job builds the candidate archive
and clean-installs the same tar on 31.1 and the declared 28.1 floor.

Package-lint at upstream commit `1865be780a16098f972fef50a52b21ca6ee04df9`
was confirmed as the latest upstream main and rerun on 2026-10-24. With the
layout helper metadata corrected, its only finding is that `emacs` is redundant
in the main package name. All four helper modules are clean. The remaining name
question prevents an overall clean lint claim; no warning is suppressed.
The extracted local runtime disables native compiler trampoline generation
because it has no configured native compiler toolchain.

## Remaining work

1. Extend application controls
   through concrete consumers. Preserve ephemeral behavior. Extend layouts, history, per-view
   input, maximize/restore and tree/form controls as real consumers require them. Avoid treating every preview as navigation.
2. Broaden actual display validation: GUI child frames, macOS terminal emulators,
   multiplexers, narrow screens, multiple clients/terminals and visual behavior.
   Linux PTY smoke is not complete UI QA.
3. Measure large-result rendering, input-to-display latency and allocations.
   Source/filter/sort/mark/tree updates replace full view contents; selection
   navigation reuses rendered rows and unchanged text previews avoid replacement. Async providers remain
   cooperative and must return promptly; cancellation must stop their own
   processes/timers. Snapshot acquisition in the async demo is synchronous.
4. Resolve the package-name lint question, document API/migration stability and accumulate
   real usage. Continue through ROADMAP.md; only the limited navigation baseline is established; maturity has not
   been established.

## External gates and continuity

MELPA guidance was rechecked on 2026-10-24: public maintenance of at least one
month and human review expectations remain. Earliest known time eligibility is
approximately 2026-11-23, not a promised completion date. The upstream recipe
path `recipes/emacs-tui` was absent on this check; recheck availability before
submission. docs/MELPA.md records the exact policy file hashes. Autonomous reviews do
not satisfy the human-review expectation. See docs/MELPA.md for source links;
never claim acceptance from a submission alone.

Work continues hourly Monday through Saturday. No Sunday work or notifications
(America/Toronto). Scheduled sessions are discrete, not an uninterrupted daemon.
The owner expects to check in Saturday 2026-10-24 around 09:00; that is not a stop
time. Treat recently updated active drafts as claimed scope, use expected-head
leases, and leave actual test evidence and remaining work in this file.
