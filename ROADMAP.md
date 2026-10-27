# Roadmap

Every milestone requires demonstrable behavior, a small documented public API,
independent review and regression coverage. Features may be redesigned when
integration reveals a better interface. This is a capability roadmap, not a
promise to finish on an arbitrary date.

## Scope and immediate priority

The package is a general-purpose TUI toolkit inside Emacs. Persistent dashboards,
explorers, forms and embedded panels are target applications alongside ephemeral
workspaces. XOB is a consumer that should exercise the toolkit's expressiveness;
it does not define the toolkit's lifecycle or data model.

The first four PRs establish useful primitives through an ephemeral workflow.
Before adding more workflow-specific machinery:

- Separate UI mounting/updating/disposal from optional query, origin and commit
  policies; retain existing ephemeral behavior and its regression tests.
- Build a persistent buffer/process dashboard as a second application. It must
  remain usable without a query field or origin-buffer commit, support explicit
  actions without closing, and release owned resources when disposed.
- Prove embedding in application-owned buffers/windows with explicit ownership;
  disposing toolkit resources must preserve the host's unrelated state.
- Extract shared primitives from these working applications. Avoid speculative
  widget hierarchies and do not freeze new public API shapes before use proves them.

See docs/DESIGN.md for boundaries and acceptance scenarios. The following
milestones remain capability goals, not claims of completed generality.

## 1. Usable foundation

- Composable list/text views, focus, input, layout and owned resource lifetimes.
- Persistent, embedded and ephemeral presentations over shared primitives.
- Optional query input and application-defined actions; state and persistence
  remain application-owned.
- Ephemeral convenience workflow with captured origin marker, separate preview
  and commit, and cancellation that preserves application content.
- Native child-frame backend and ordinary-window fallback.
- Columns, rows and grid geometry; resize and resource cleanup.
- Executable example, API reference, ERT, byte compilation and CI.

## 2. Rich interaction

- Per-view queries, selection and scroll state; navigation history.
- Context actions, multi-selection, tables, trees, form controls, metadata and
  formatted previews, prioritized through real applications.
- Eight-position source-anchored candidate popups; extend around-point views,
  overlays and full-workspace presentation through concrete consumers.
- User-switchable layouts, maximize/restore, hidden views and narrow-screen
  collapse with keyboard access to every view.
- Session-local customization, discoverable keys and accessible non-color cues.
- Generic graph demo covering recursive forward/backlink browsing; separately
  implement XOB adapter against its actual public APIs.

## 3. Async providers and composition

- Debounced asynchronous/streaming providers with cancellation, generation
  tokens, error state and stale-response suppression.
- Large result collections, incremental updates and bounded preview work.
- Commit query, selection or composition to explicit destinations; application
  controls transactions. Inline ghost content and reversible visibility.
- Multiple simultaneous sessions/terminals; optional completion/action adapters.
  The native CAPF frontend is an opt-in source-buffer adapter; broader metadata
  grouping, documentation and async completion need concrete consumer evidence.

## 4. Stability and performance

- Interactive TTY matrix: Linux/macOS, Emacs 31.1, Ghostty/iTerm2 and multiplexers
  when available; accurately record unavailable combinations.
- Resize, scrolling, overlaps, terminal switching, source/frame deletion,
  callback failures, Unicode wide/combining glyphs, paste and input methods.
- GUI fallback verification; compatibility with ordinary Emacs packages.
- Repeated open/close stress and resource-leak assertions.
- Reproducible latency/allocation benchmarks with realistic large datasets.
- Optimize measured bottlenecks after behavior and API are established.

## 5. Release and MELPA

- Public maintenance history of at least one month; substantive use and fixes.
- Stable API documentation, migration policy, installation and working demos.
- Latest package-lint, checkdoc, clean compile, real package-build recipe test
  and clean installation of the produced artifact.
- Human review checkpoint under current MELPA guidance; disclose AI assistance.
- Release candidate, tagged release, MELPA recipe PR, address review, verify
  accepted recipe and published package installation before declaring done.

The known time gate makes submission no earlier than approximately 2026-11-23
if public maintenance starts 2026-10-23. Time elapsed alone is not maturity.
