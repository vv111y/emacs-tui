# Demo guide

Start with `make gallery` from a beta6 or current main checkout. The gallery itself is
a persistent TUI: RET shows the selected tour, C-c C-o launches the selected
example, and C-c C-q closes. Launching closes the gallery first. After closing
an example, M-x emacs-tui-gallery opens the chooser again. Tour text wraps to
its pane; TAB to it and use ordinary Emacs scrolling, or C-c C-f to maximize.

Every example also has a direct Make target, which starts a clean terminal
Emacs. No extra packages, sample files, network services or XOB setup are needed.
The gallery uses self-contained sample data and works immediately under Emacs -Q.

These examples live in the checkout's examples directory, outside the installed
runtime package. The fixed beta6 branch includes twelve gallery entries, including
the settings form and independent floating panels. Older release branches remain
unchanged. Do not mix new examples with an older installed toolkit.

## Choose a demo

| Make target | What to explore | Explicit effects |
| --- | --- | --- |
| gallery | Twelve beta6 showcases with tours and cleanup | Launches your choice |
| popup-demo | Typing in the unchanged source, floating candidates, eight compass positions, native undo | TAB explicitly replaces the current word |
| multi-popup-demo | Three simultaneous floating child frames; individual/all toggles, selection retained while hidden | Browses sample data only; source typing remains native |
| inspector-demo | Scrollable floating equipment details, eight positions, related objects, Back/Forward, acknowledgement, source focus | Changes buffer-local demo state only |
| completion-demo | Emacs's actual Lisp completion provider, styles and source-preserving popup | TAB explicitly accepts a native completion |
| board-demo | Three task lanes, independent list state, batch moves and explicit application actions | Changes tasks in session memory |
| reader-demo | Chapter tree, ancestor search paths, formatted pages, wrapping and reading position | Reads self-contained sample text |
| snippet-demo | One borrowed-window palette, tracked origin point, explicit insertion and native undo | RET inserts a literal snippet in the launching buffer |
| catalog-demo | Search input, numeric sort, fill-width table, formatted details, hidden marks, batch actions | Collect/clear in session memory |
| form-demo | Native fields, checkbox-style options, live validation, draft versus applied settings | Apply/Revert changes session memory only |
| composer | Two native editable fields, multiline composition and live preview | C-c C-c copies to kill ring |
| stream-demo | Visible batches, debounce, cancellation, partial failure and recovery | Synthetic data only |
| graph-demo (also demo) | Original graph explorer, links/backlinks, Back/Forward, multi-selection, preview/commit split | C-c C-c inserts demo links into the original buffer |
| layout-demo | Columns/rows/grid, maximize, hidden panels, tree, Unicode, editable text, live preview | Scratch edits only |

The inline popup preserves source typing instead of allocating a tiled workspace.
The inspector uses that presentation for a general object and a scrollable
text view, with an explicit action that keeps the popup open.
The board has three working lists and no search or preview. The reader is a
chapter outline beside a document. The snippet picker occupies a single borrowed
window. The composer uses stacked editable fields, the catalog is a table
application, and the graph explorer follows relationships. The streaming and
layout entries are focused capability laboratories. Their different initial
screens and actions have application-specific checks. Batch gallery-launch
checks cover entries without a native-popup requirement. Separate native
fixtures exercise the source-anchored examples through their gallery launch
commands.

The earlier buffer-oriented examples remain runnable as development references,
but are no longer repeated in the gallery:

| Make target | Development example |
| --- | --- |
| dashboard | Live buffer/process tables, refresh timer and process-buffer actions |
| tree | Buffer hierarchy, hidden marks and explicit buffer display |
| panel | Minimal borrowed-window buffer browser |
| filter-demo | Local filtering over live buffer metadata |
| async-demo | Cancellable chunked search over captured buffer excerpts |

To use the gallery in an existing Emacs, load matching source files from the
checkout (start a fresh Emacs if another emacs-tui version is already loaded):

```elisp
(add-to-list 'load-path "/path/to/emacs-tui")
(load "/path/to/emacs-tui/examples/emacs-tui-gallery.el")
(emacs-tui-gallery)
```

## Five-minute tours

### Inline candidate popup

Run `make popup-demo` in a terminal Emacs with native child-frame support, or
choose the gallery entry to enable it in your original source buffer. The
standalone target prepares a fresh centered sample document; gallery activation
preserves your source text. Type map, then M-n to choose mapc. C-c C-p cycles
N, NE, E, SE, S, SW, W and NW. Keep typing to filter: the same popup is reused.
TAB explicitly accepts the selected word; normal undo reverses acceptance.
C-g dismisses the popup, and C-c C-q disables the local demo bindings.

The source window is never split or replaced by presentation. Candidate actions
run in the source context, and the popup has no editing focus. Width/height and
all positions are clamped to the parent viewport; near edges, positions may
coincide or overlap the word. Wrapped/partly hidden words anchor at point.
Older terminals leave the gallery open with a capability error instead of
substituting a tiled interface. A graphical display or the tty-child-frames
feature is required; the general toolkit still supports older terminals.

### Independent floating panels

Run `make multi-popup-demo` from the beta6 checkout, or choose Independent floating
panels in its gallery. A disposable note starts with three separate child frames:
an object list below point, details to the right and a key guide above-left.
The source window is never split or replaced while the panels are shown.

| Key | Effect |
| --- | --- |
| C-c 1 | Toggle Objects |
| C-c 2 | Toggle Details |
| C-c 3 | Toggle Keys |
| C-c 0 | Hide all if any are visible; show all if none are visible |
| M-n / M-p | Browse sample objects, including while panels are hidden |
| C-c [ / ] | Scroll Details three lines backward / forward without taking focus |
| C-c < / > | Pan Details eight columns backward / forward |
| C-c C-d | Pin / release the current Details object |
| C-c C-e | Expand / shrink visible Details; retain the choice while hidden |
| C-c p 1 / 2 / 3 | Move Objects / Details / Keys through eight positions independently |
| C-c C-p | Alias for moving Objects |
| C-g | Hide all, keeping the toggle bindings active |
| C-c C-q | Disable the demo and restore ordinary source bindings |

Try hiding Details, choosing another object with M-n, and reopening Details.
Read the longer sample records with C-c [ / ]. Details must be visible;
hiding and reopening resets its reading position. Moving a visible panel
preserves its reading position. C-c C-e toggles Details between requested
34×7 and 50×12 columns/rows using the same child frame. The source keeps typing
focus, and sibling panels retain their sizes and positions. Native viewport
bounds can limit the actual dimensions. Hide/show retains the size choice;
disabling/re-enabling resets it.

In beta6 and current main, C-c < / > pans Details eight columns backward / forward.
Read the wide operator notes without focusing the popup. Movement, resizing
and refresh retain the explicit horizontal position; browsing to new content
resets it. Returning past the first column stops at zero. These keys and the
`emacs-tui-scroll-view-horizontally` API are included in beta6 (absent from older fixed beta4).

In beta6 and current main, C-c C-d pins visible Details to its current object. Its
header displays [pinned]. Browse with M-n/M-p: Objects changes while Details
keeps its text and reading position. Hide/show retains the pinned object;
scrolling, movement and resizing still work. Press C-c C-d again to show the
current list selection and resume following it. Pinning requires visible
Details; re-enabling the demo clears the pin. This is local application state,
not a persistent bookmark. Beta6 includes this command; older fixed beta4 does not.

Move each panel with C-c p 1/2/3, then hide/show the group with C-c 0.
Selection and each requested position survive; hidden panels
release their frames and buffers, and reopening creates new surfaces. Type and
undo normally in the source. Closing one panel leaves its siblings live.
Moving a hidden panel asks you to show it first. Disabling/re-enabling resets
selection and placement. Leaving the source closes its panels; returning and
pressing C-c 0 reopens them with retained state. Killing the source or changing
its major mode closes every owned panel.

All panels are read-only and retain source keyboard focus. Their positions are
clamped and may overlap on narrow displays; this is not automatic collision
avoidance or a draggable window manager. Native child-frame capability is
required. Beta1–beta3 do not contain this example.

To enable the same demo over an existing source without inserting sample text,
load examples/emacs-tui-multi-popup-demo.el and run
M-x emacs-tui-multi-popup-demo-mode. Only your own typing changes source text.

### Floating equipment inspector

Use a beta6 or current main checkout and run `make inspector-demo`, or choose
Equipment inspector in its gallery. Older beta1/beta2 checkouts lack this example.
A disposable document opens with pump details floating around the reference.
M-n and M-p scroll three lines while typing focus stays in the source document.
C-c C-p cycles eight positions and retains the preview's reading position.

C-c C-l follows the related object: pump → valve → sensor → pump. C-c C-b
and C-c C-f travel Back/Forward without moving source point or replacing the
popup. Each changed preview starts at the beginning. Navigation stores up to
32 object identities in each direction; a new Follow after Back clears Forward.
Dismissal clears this trail, while acknowledgements remain attached to objects.

C-c C-a toggles acknowledgement without closing the popup or editing source
text. C-g dismisses and restores ordinary source bindings. Put point on pump
again and run M-x emacs-tui-inspector-demo-at-point: acknowledgement survives
popup dismissal. Inspect valve to see a separate object. Each source buffer owns
its acknowledgement table; changing major mode or killing that buffer discards
it. No external equipment, files, completion provider or commit destination is
involved. The displayed object remains the one explicitly inspected even if you
edit the source. A graphical display or native TTY child frames is required.

For an application-defined text popup, use `emacs-tui-scroll-view` to scroll its
visible read-only view while retaining source focus. The operation rejects hidden
or editable views; applications choose their own key bindings and action policy.

### Native completion frontend

Run `make completion-demo` on a display with native child frames. This opens a
disposable Emacs Lisp source, invokes its normal completion provider and shows
real symbols at `(map`. Type `ca` to filter, select with M-n/M-p, move with
C-c C-p and accept with TAB. C-/ undoes that insertion. C-g dismisses;
C-M-i begins another completion. No Lisp is evaluated or saved.

In an existing supported source buffer, require `emacs-tui-completion`, enable
`emacs-tui-completion-mode`, and use the buffer's usual completion command.
This optional adapter captures the native provider's table and metadata. It
does not replace your completion providers or require another completion
package. Source edits refresh an already active completion; initial activation
is manual. Disable the mode to restore the previous frontend. The gallery's
literal-word popup deliberately remains the separate automatic-typing example.

### Task board

Run `make board-demo`. Three lanes start with six sample tasks. > moves the
selected task to the next lane and follows it; < moves it back. TAB switches
lanes without changing task data. C-c C-m marks a task; C-c * marks all tasks
in the focused lane. > moves that batch. The lane counts update immediately.
The a menu exposes the same actions and disables moves beyond the end lanes.
Close and reopen to get a fresh board. No text is inserted into other buffers.

### Field guide reader

Run `make reader-demo`. SPC expands Navigation; choose Compass and RET reads
that section. TAB focuses the wrapped page. Scroll normally or use C-c C-f to
maximize it. The page remains readable independently of the contents selection.
In the contents, / searches section titles: Compass reveals its ancestor path.
Repeat / with an empty query to restore the earlier expansion. C-c + and C-c -
expand/collapse all. This is a book supplied by the application, not a live
buffer browser. Its checklist page is ordinary text, not a checkbox widget.

### Embedded snippet picker

Run `make snippet-demo`, or load it in your Emacs and launch from a writable
scratch buffer. The list borrows the selected window. RET inserts the chosen
literal snippet at the tracked original point, then restores that window's
original buffer. Normal undo reverses insertion. Launch again and q cancels
without editing. A read-only host rejects insertion and leaves the picker open.
The picker never evaluates snippet text, saves files or writes to the kill ring.

### Validated settings form

Use a matching beta6 checkout and run `make form-demo`, or select Settings form
from its gallery. Beta1–beta3 do not contain this entry. Name and Retries
are ordinary editable Emacs buffers: type, paste and undo normally. TAB cycles
Name, Retries, Options and the live validation/applied-record pane. In Options,
SPC toggles the selected checkbox; n/p selects another option.

Set Retries to 11: validation explains the 0–10 limit, and C-c C-c refuses Apply.
Change it to 10, toggle an option and press C-c C-c again. The applied record now
reflects that valid draft while the form stays open. Edit Name and use C-c C-r
to restore the last applied record. Changed fields reset undo; unchanged fields
retain it. C-c C-q closes. Reopening starts fresh session defaults.

No Emacs preferences, files, source buffers or kill-ring values are changed.
This demonstrates application-owned validation and persistence policy composed
from native input, a table of options and actions; no form framework is required.

### Object catalog

Run `make catalog-demo`. Type Note in the search field and TAB to the table.
C-c * marks all three notes. Return to the search field, replace Note with Map,
and TAB back: the marks on the now-hidden notes survive. Press a and choose
Collect marked or selected objects. The collection contains the three notes,
in source order. Invoking Collect again adds no duplicates.

Clear marks with C-c C-u. RET inspects the selected map but does not collect it.
Press s, select size, then repeat with C-u s to reverse the numeric order.
Search 日本語 to find the wide-character row. Resize the terminal and watch the
name column use the remaining space. Collection data disappears on close.

### Layout playground

Run `make layout-demo`. RET on a control selects Columns, Rows or Grid.
C-c e focuses the editor. Add text, paste multiple lines, and undo normally;
the preview updates after editing.

C-c C-f maximizes the current panel. TAB still reaches panels hidden by
maximization or a narrow terminal. C-c e jumps directly back to the editor.
Restore with C-c C-f. In the tree, SPC expands a branch; C-c C-m marks an item;
C-c + and C-c - expand/collapse all. Switch layouts and resize the terminal:
scratch input, native undo and marks remain.

The preview includes faces, wide Japanese characters and combining accents.
Their physical appearance depends on your font and terminal; inspect it on your
actual setup. No visual test can be inferred from a passing batch test.

### Streaming job search

Run `make stream-demo`. Sixty synthetic job records arrive in batches of five,
with deliberately visible timer delays. Type build and then quickly replace it
with test; the old request is cancelled and its results are replaced. RET
inspects an original record in a separate preview.

Replace the query with !error. After 15 records, the provider reports a
deliberate error and retains the partial results for inspection. Clear the query
or type deploy to start a fresh successful request. Close during a stream to
cancel pending work. There are no external jobs, network requests or benchmarks
behind this simulation. The async-demo remains the real buffer-search example.

### Original graph explorer

Run `make graph-demo` (`make demo` is unchanged). RET inspects a node, TAB moves
among nodes, preview, links and backlinks, and RET follows a selected link.
Use a in a read-only view, or C-c C-a while editing the query, for Back/Forward.
C-c [ and C-c ] also navigate history in the view buffers.

Mark nodes with C-c C-m, or use C-c * / C-c C-t for bulk mark/invert. Inspection
and browsing never insert anything. C-c C-c explicitly inserts links into the
original buffer and closes; C-c C-q cancels. Use a writable scratch buffer when
testing commit. This is a synthetic graph, not an XOB adapter.

## Shared controls

| Operation | Keys |
| --- | --- |
| Next/previous panel | TAB / S-TAB |
| Next/previous object | M-n / M-p; n / p in read-only views |
| Inspect selected object | RET in list/table/tree; newline in editable fields |
| Toggle mark / clear marks | C-c C-m / C-c C-u |
| Mark all / invert visible marks | C-c * / C-c C-t |
| Named actions | C-c C-a; a in read-only views |
| Cycle / choose layout | C-c C-l / C-u C-c C-l |
| Maximize / restore | C-c C-f |
| Close | C-c C-q; q in read-only views |
| Command help | C-h m and normal Emacs help |

Letters remain ordinary text in native inputs. Mark commands apply to item
views; sort applies to tables; expansion applies to trees. Ephemeral query
buffers retain typing while the logical focused view controls inspection.

## Coverage and limits

Together the examples cover the implemented public interaction families:
persistent mounting, borrowed windows and ephemeral commitment; lists, text,
tables, trees and editable inputs; selection/focus, marks, queries, numeric sort,
actions and application keymaps; layouts, maximize and resize; formatted text,
Unicode and native undo; cancellable streaming providers and application timers;
source-anchored read-only inspection, focus-preserving scrolling and explicit
actions that leave the popup open.

The board, reader, layout, catalog and streaming showcases request automatic
presentation: native child frames where supported, ordinary windows otherwise.
The composer and development buffer examples choose ordinary windows. Embedded
panels always borrow the selected host window. Native terminal child frames depend on the
tty-child-frames feature, not just the version number.

Multiple simultaneous sessions are supported and covered by lifecycle tests;
the gallery deliberately launches one demo at a time. To explore two, open a
demo from each of two separate application-owned windows. Source code shows
application policies, rather than claiming the toolkit has built-in databases,
network clients, lazy trees, inline text-region widgets or a full form system.
See README.md and ROADMAP.md for the implemented API and future goals.

Automated gallery-dispatch and separate native-demo checks cover distinct initial
views, explicit origin commitment,
session-local collection state, hidden-mark actions, native input/undo,
streaming failure/recovery and timer disposal. The terminal showcase also
launches the board, reader and snippet picker, moves a batch, searches a chapter,
inserts and undoes a snippet, edits the catalog and layout playground, resizes
120→90→140 columns, and recovers the streaming provider. Physical emulator,
font, multiplexer and graphical display coverage still needs human use. The
native popup fixture additionally exercises the inspector through scrolling,
eight moves, acknowledgement and dismissal without changing source text or undo.

## Automated tmux checks

With tmux and a matching native-child-frame Emacs checkout available, run:

```sh
python3 test/run-tty-smoke.py --tmux test/tty-popup-smoke.el
python3 test/run-tty-smoke.py --tmux test/tty-completion-smoke.el
python3 test/run-tty-smoke.py --tmux test/tty-input-smoke.el
```

The driver creates a private tmux server/socket with a minimal configuration,
disables its status line, and checks resize delivery and required popup paint on
the outer PTY. It terminates only that private server on exit. The separate Linux/macOS
CI workflow exercises this configuration on Emacs 31.1. This does not validate
personal tmux configurations, zellij, physical terminal emulators or GUI displays.
A missing tmux executable is an error, not a skipped success.

## Automated graphical checks

The graphical workflow installs the runner distribution's GTK Emacs and records
its version. It runs `test/gui-smoke.el` interactively under Xvfb, requires a real
graphical display, and checks child-frame input, anchored inspector scrolling and
actions, parent-relative bounds through eight positions, resizing and cleanup.
Its execution is bounded by an external timeout and requires a PASS report.
The same workflow also runs the completion fixture with `EMACS_TUI_GUI_SMOKE=1`.
It shares the terminal assertions for a real Elisp provider, typing/filtering in
the same popup, acceptance/native undo, file completion suffixes, affixation,
read-only retries and mode-change cleanup. In graphical mode, resize requests
change the parent frame directly instead of waiting for an outer PTY driver.
The graphical display is mandatory and the report distinguishes native GUI
state from terminal paint checks; this does not claim pixel-level inspection.
This verifies native graphical state and interaction; it does not inspect rendered
pixels, fonts, desktop window managers, macOS GUI Emacs or physical displays.

The graphical and native terminal popup checks also run twenty shared lifetime
cycles. Real keyboard commands close a popup, leave its source window, replace
its source buffer, or kill that buffer. Each cycle checks disposal callbacks,
frames, view buffers, anchor markers and routing-hook cleanup, and preserves
ordinary navigation choices. The native terminal cases also run through tmux;
unsupported terminals do not claim this native lifetime coverage.
