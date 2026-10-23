# Project mandate

Build a general-purpose, terminal-first Emacs workspace package. Prioritize
expressive functionality, a clean concise API, then measured performance. The
goal is a mature stable release accepted into MELPA, not a prototype declared
finished. XOB will consume this package; core must not depend on Org or graphs.

## Working agreement

- Read ROADMAP.md, docs/STATE.md and current PRs before selecting work. Inspect
  current remote heads; never overwrite another worker's changes.
- Deliver focused implementation PRs with tests and accurate descriptions.
  Independent review and passing checks are required before integration.
- The owner delegates routine engineering and integration. Merge our own PRs
  after independent review findings are resolved and relevant CI passes, using
  the reviewed head SHA. Do not require owner approval for each development PR.
  Never waive external MELPA review or assert human review that did not occur.
- Keep state in this repository so future sessions can continue. Update
  docs/STATE.md with completed work, actual checks, risks and next work.
- No Sunday work or notifications (America/Toronto).

## Design invariants

- Browsing, typing queries, previewing and traversing do not modify application
  data. Only explicit application commit callbacks may do so.
- Use real temporary buffers for editable input, retaining native editing,
  Unicode, input methods, paste and undo.
- Model general objects and views, not completion candidates exclusively.
- Application state, input, layout, rendering and persistent actions have clear
  boundaries. Avoid a speculative framework before a second use case proves it.
- Use `emacs-tui-` symbols; `tui-` is already used by another package.
- Detect TTY child frames with `featurep`, not only Emacs version. Clamp their
  geometry. Never reuse frames across terminals. Ordinary windows remain a
  supported fallback. Do not depend on TTY `no-accept-focus` or `frame-restack`.
- Dispose owned frames, windows, buffers, hooks, timers and processes on normal
  exit and exceptions. Preserve unrelated buffers, windows and user edits.
- Async work must be cancellable and reject obsolete results after query/view
  changes or session disposal. Never block redisplay on provider work.
- No mandatory dependency on Helm, Vertico, Consult, Corfu, Embark or Posframe.
  Add optional adapters only when concrete benefit justifies them.

## Validation and publication

- Use lexical binding, GPL-3.0-or-later headers and honest Assisted-by metadata.
- Run ERT, warning-free byte compilation and checkdoc for changed Lisp. Add
  meaningful behavior/regression tests, not implementation-mirroring tests.
- Test minimum supported Emacs and 31.1. Batch ERT is insufficient evidence for
  terminal child-frame focus/composition: run actual interactive TTY tests.
- Benchmark input-to-display latency separately from provider latency; publish
  environment, workload and p50/p95/p99 without invented numbers.
- Recheck MELPA policy and name availability before submission. See
  docs/MELPA.md for known external gates. Never claim acceptance from an open PR.
