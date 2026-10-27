# Changelog

## 0.1.0-beta2 — 2026-10-27

- Source-preserving native candidate popups with eight compass positions,
  tracked anchors, explicit application actions and a typing-driven demo.
- Optional buffer-local `emacs-tui-completion-mode` uses native completion
  providers, styles, annotations/affixes, field boundaries and exit callbacks.
  `make completion-demo` demonstrates Emacs's actual Lisp symbol provider.
- Distinct task-board, reader and snippet applications replace repetitive
  gallery entries; table fill widths preserve the rightmost terminal glyph.
- Popup clients dispose before major-mode changes discard their local state.
- Completion startup interrupted by popup closure or a new completion releases
  the old context without reviving its bindings or disposing the new popup.
- Completion acceptance revalidates buffer/window ownership after table
  callbacks and before source reads or edits, preserving external changes.
- Native terminal tests require visible popup paint before abrupt real-client
  loss, complete popup disposal and continuing input on the surviving terminal.

The new popup APIs are additive. Existing persistent, embedded and ephemeral
workspace calls keep their behavior; the completion frontend is opt-in.
Floating popups require graphical or advertised native TTY child frames and
reject unsupported displays without splitting the source window. Other toolkit
presentations retain their ordinary-window fallback on Emacs 28.1+.

The fixed beta2 branch includes the matching examples and optional runtime
adapter. Install only `emacs-tui*.el` with the documented straight.el recipe;
use a matching source checkout for demos. The beta1 branch remains unchanged.
Both betas retain an experimental API and await substantive community use.
GitHub prerelease tags and MELPA publication remain separate external steps.

## 0.1.0-beta1 — 2026-10-24

First community-testing release of the general-purpose Emacs TUI toolkit.

### Included

- Persistent multi-view applications, embedded panels and ephemeral query/
  preview/commit workspaces over shared lifecycle primitives.
- List, text, editable input, table and tree views with identity-preserving
  selection, multi-selection, queries, sorting and named actions.
- Responsive tables with one optional fill-width column that follows its live
  window across terminal resize while retaining fixed-column overflow.
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
  31.1 on macOS. It builds the actual package recipe on the newest version and
  clean-installs the resulting archive on the minimum and newest versions.
- Terminal scenarios cover real input, resize, two simultaneous PTY clients,
  explicit deletion, abrupt client loss, focus survival and final cleanup.

### Known limits

- The public API is experimental during beta. Incompatible 0.x changes follow
  the policy in `docs/API-STABILITY.md` and will include migration notes.
- Physical terminal-emulator and graphical-display coverage is narrower than
  the automated pseudo-terminal matrix.
- Embedded panels own complete Emacs windows; inline text-region widgets are
  not implemented.
- The beta is installed from the fixed release branch with straight.el while
  the matching GitHub prerelease tag awaits authenticated publication. It is
  not yet available from MELPA; public-maintenance and substantive human review
  gates remain external requirements.
