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

Shared capabilities include list/text/table/tree views and editable inputs;
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

`emacs-tui-mount` shares construction, layout, selection, updates and disposal with `emacs-tui-open`. Mounted interfaces do not
allocate a query buffer or capture an origin marker. They use native view focus
and explicit application actions; the dashboard supplies an example with a
periodic timer released through its close callback.

`emacs-tui-open` retains its query/origin/commit convenience policy.
`emacs-tui-embed` borrows a host window for one owned view buffer and restores
the previous buffer and tracked positions on disposal. It never deletes the
host window or overwrites a repurposed window. Region-level embedding and
multiple views inside one borrowed surface remain future work.

`emacs-tui-popup` mounts one read-only view in a native child frame around a
source word while preserving the source window, buffer and typing focus. It
requires graphical child frames or advertised TTY child-frame capability;
unsupported displays reject it instead of splitting the source window.
Repositioning and resizing retain the same owned frame. Read-only previews can
scroll on both axes without taking source focus. Multiple popups are separate
sessions: the multi-popup example supplies collective visibility, linked object
selection and optional Details pinning as application policies. It does not
introduce a mandatory popup group, collision avoidance or new data model.

Application and per-view keymaps compose with native defaults, while ephemeral
query input retains ordinary editing. Editable text views use native editing,
input methods and undo in persistent and embedded interfaces, with
application-owned change callbacks and explicit actions. The composer
combines two fields and a preview without a query provider or origin-buffer
commit. The settings form composes native fields with list-based checkbox
options, live validation and explicit Apply/Revert. Its saved record is
session-local application state; there is no generic form transaction or
persistence service. These examples prove composition without making their
private helpers part of the public API. No stable API claim is made.

Table columns project existing items for display and sorting; they do not
introduce a separate row identity or action model. The buffer/process dashboard
exercises numeric sort, string metadata and stable updates. Columns use fixed
display widths with horizontal scrolling; editing and adaptive widths remain
future work.

Tree views index a finite forest and reuse original objects, identities, marks,
actions and async source replacement. Expansion changes display state only.
Local queries reveal matching paths without committing expansion changes.
The mode-grouped buffer browser exercises refresh, preview and explicit buffer
display. Child projection is eager per snapshot; lazy loading and graph
occurrence identity remain future work rather than implicit assumptions.

Named actions are optional view configuration, separate from single-item
exploration and ephemeral origin-buffer commitment. Applications own effects
and validation. Menus use native completion, target marked/current source
objects and recheck live state after prompting. Availability is evaluated only
on explicit action requests, never as a rendering effect.

The optional CAPF frontend adapts Emacs completion-at-point providers to a
source-preserving popup. Provider matching styles, metadata, exit callbacks and
explicit acceptance and native undo stay at that adapter boundary. Completion candidates do
not define general view objects or session lifetimes.

## Evidence and remaining boundaries

The [demo guide](DEMOS.md) identifies distinct applications and which fixed
release contains each capability. [STATE.md](STATE.md) records current reviewed
integration and exact validation evidence; its history preserves older
checkpoints. The [API policy](API-STABILITY.md) defines the supported public
surface and experimental compatibility rules. These documents, not the early
milestone wording above, determine what can be used today.

An XOB adapter still needs a concrete snapshot/action contract from its public
interfaces; the generic graph examples are not a live XOB integration. Region
embedding, lazy tree loading, adaptive table widths and automatic popup overlap
management remain outside the current implementation. Physical terminal and
human application use, as well as MELPA's independent review and public
maintenance gates, remain separate from passing automated checks.
