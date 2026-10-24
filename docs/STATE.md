# Project state

Updated 2026-10-24 (America/Toronto).

## Active implementation

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

Local strict compilation passed for the fixture on Emacs 29.3/Linux. Its real
local execution could not start the private server: this host rejects the Unix
socket with make-network-process "Operation not permitted". This is not a
passing two-client test. Positive runtime coverage, independent exact-head
review and all eight fresh CI jobs are required before integration. No new
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
strict compilation, checkdoc and eight real terminal scripts. Emacs 31.1 uses
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
