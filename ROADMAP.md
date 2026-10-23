# Roadmap

Every milestone requires demonstrable behavior, a small documented public API,
independent review and regression coverage. Features may be redesigned when
integration reveals a better interface. This is a capability roadmap, not a
promise to finish on an arbitrary date.

## 1. Usable foundation

- Ephemeral sessions with editable query and independent list/text views.
- Separate selection, exploration and explicit application commit.
- Captured origin marker; cancellation preserves application content.
- Native child-frame backend and ordinary-window fallback.
- Columns, rows and grid geometry; resize and resource cleanup.
- Executable example, API reference, ERT, byte compilation and CI.

## 2. Rich interaction

- Per-view queries, selection and scroll state; navigation history.
- Context actions, multi-selection, tables, metadata and formatted previews.
- Around-point north/east/south/west layout, overlays and full-workspace mode.
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
