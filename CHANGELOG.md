# Changelog

## 0.1.0-beta1 — 2026-10-24

First community-testing release of the general-purpose Emacs TUI toolkit.

### Included

- Persistent multi-view applications, embedded panels and ephemeral query/
  preview/commit workspaces over shared lifecycle primitives.
- List, text, editable input, table and tree views with identity-preserving
  selection, multi-selection, queries, sorting and named actions.
- Columns, rows and grid layouts; direct layout selection, maximization,
  automatic terminal resize reflow and application keymaps.
- Cancellable asynchronous providers with generation-safe publication and
  deterministic cleanup of owned frames, windows, buffers, timers and hooks.
- Native terminal child frames when the Emacs build advertises
  `tty-child-frames`, with an ordinary-window fallback.
- Concrete persistent dashboard, embedded buffer panel and ephemeral graph
  explorer examples.

### Compatibility and validation

- Requires Emacs 28.1 or later and has no third-party runtime dependencies.
- CI exercises Emacs 28.1, 28.2, 29.4, 30.2 and 31.1 on Linux, plus 30.2 and
  31.1 on macOS. It builds and clean-installs the actual package recipe on the
  minimum and newest supported versions.
- Terminal scenarios cover real input, resize, two simultaneous PTY clients,
  explicit deletion, abrupt client loss, focus survival and final cleanup.

### Known limits

- The public API is experimental during beta. Incompatible 0.x changes follow
  the policy in `docs/API-STABILITY.md` and will include migration notes.
- Physical terminal-emulator and graphical-display coverage is narrower than
  the automated pseudo-terminal matrix.
- Embedded panels own complete Emacs windows; inline text-region widgets are
  not implemented.
- The beta is installed from the Git tag with `package-vc` or straight.el. It
  is not yet available from MELPA; public-maintenance and substantive human
  review gates remain external requirements.
