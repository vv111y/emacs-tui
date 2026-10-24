# General TUI toolkit direction

The owner clarified on 2026-10-23 that emacs-tui should be a general-purpose
TUI package for Emacs. The XOB interface idea is an important intended consumer,
including its ephemeral exploration and composition workflow.

## Boundaries

The toolkit runs inside Emacs and builds on buffers, windows, keymaps, faces,
native editing and asynchronous processes. It should make composing useful
text interfaces pleasant without requiring applications to implement window,
focus, selection, refresh and resource-cleanup plumbing repeatedly.

General-purpose describes reusable UI capabilities and configurable policies.
It does not require implementing every possible widget before applications can
use the package. Add controls and abstractions through concrete use cases.

## Separate primitives from policies

Shared capabilities include list/text views and later tables, trees and forms;
layout and resize; focus and input routing; selection and marks; updates and
async lifecycle management; and discoverable application-defined actions.

Applications own their data model, action semantics, persistence and navigation
meaning. Query input, search providers, an origin marker, explicit result
insertion, and closing after commit are useful optional policies. They must not
be prerequisites for mounting a UI.

Presentation should accommodate persistent application buffers, embedded panels
and temporary windows or child frames. Resource ownership must be explicit:
closing a toolkit-owned surface and unmounting from a host-owned surface can
require different cleanup, while both release owned timers and processes.

The existing ephemeral workflow remains a supported convenience path. Its
preview-before-commit behavior and origin-buffer rollback must retain coverage
during refactoring. Ordinary application actions may update application state
and keep a persistent UI open; rendering must not implicitly perform those actions.

## Prove generality with applications

1. Preserve the existing ephemeral graph explorer and explicit batch insertion.
   The eventual XOB adapter uses XOB's actual public interfaces and stays outside
   the core package's domain model.
2. Add a persistent buffer/process dashboard with independent views, refreshing
   data and explicit actions that do not close the interface. It must not need
   a query field or a meaningful origin-buffer commit destination.
3. Demonstrate an embedded panel that respects application-owned buffers and
   windows, and releases only toolkit-owned resources on unmount.

Use these examples to determine the public lifecycle and composition API.
Do not commit to a large widget inheritance framework or replace the current
implementation wholesale. Reuse the working layout, selection, async and
cleanup mechanisms, extracting their policies incrementally.

## Current implementation and limitations

The persistent lifecycle PR adds `emacs-tui-mount`, sharing construction, layout,
selection, updates and disposal with `emacs-tui-open`. Mounted interfaces do not
allocate a query buffer or capture an origin marker. They use native view focus
and explicit application actions; the dashboard supplies an example with a
periodic timer released through the new close callback.

`emacs-tui-open` retains its query/origin/commit convenience policy. `emacs-tui-embed` borrows a host window for one owned view buffer and restores
the previous buffer and tracked positions on disposal. It never deletes the
host window or overwrites a repurposed window. Region-level embedding and
multiple views inside one borrowed surface remain future work. Forms, trees, general
application keybinding configuration and persistent input widgets remain work
for subsequent application-driven increments. No stable API claim is made.
