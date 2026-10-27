# Demo guide

Start with `make gallery` from a beta2 or current main checkout. The gallery itself is
a persistent TUI: RET shows the selected tour, C-c C-o launches the selected
example, and C-c C-q closes. Launching closes the gallery first. After closing
an example, M-x emacs-tui-gallery opens the chooser again. Tour text wraps to
its pane; TAB to it and use ordinary Emacs scrolling, or C-c C-f to maximize.

Every example also has a direct Make target, which starts a clean terminal
Emacs. No extra packages, sample files, network services or XOB setup are needed.
The gallery uses self-contained sample data and works immediately under Emacs -Q.

These examples live in the checkout's examples directory, outside the installed
runtime package. The fixed beta2 branch includes this gallery; the older beta1
branch remains unchanged. Do not mix new examples with an older installed toolkit.

## Choose a demo

| Make target | What to explore | Explicit effects |
| --- | --- | --- |
| gallery | Nine showcases, tours, launch and cleanup | Launches your choice |
| popup-demo | Typing in the unchanged source, floating candidates, eight compass positions, native undo | TAB explicitly replaces the current word |
| completion-demo | Emacs's actual Lisp completion provider, styles and source-preserving popup | TAB explicitly accepts a native completion |
| board-demo | Three task lanes, independent list state, batch moves and explicit application actions | Changes tasks in session memory |
| reader-demo | Chapter tree, ancestor search paths, formatted pages, wrapping and reading position | Reads self-contained sample text |
| snippet-demo | One borrowed-window palette, tracked origin point, explicit insertion and native undo | RET inserts a literal snippet in the launching buffer |
| catalog-demo | Search input, numeric sort, fill-width table, formatted details, hidden marks, batch actions | Collect/clear in session memory |
| composer | Two native editable fields, multiline composition and live preview | C-c C-c copies to kill ring |
| stream-demo | Visible batches, debounce, cancellation, partial failure and recovery | Synthetic data only |
| graph-demo (also demo) | Original graph explorer, links/backlinks, Back/Forward, multi-selection, preview/commit split | C-c C-c inserts demo links into the original buffer |
| layout-demo | Columns/rows/grid, maximize, hidden panels, tree, Unicode, editable text, live preview | Scratch edits only |

The inline popup preserves source typing instead of allocating a tiled workspace.
The board has three working lists and no search or preview. The reader is a
chapter outline beside a document. The snippet picker occupies a single borrowed
window. The composer uses stacked editable fields, the catalog is a table
application, and the graph explorer follows relationships. The streaming and
layout entries are focused capability laboratories. Their different initial
screens and actions are exercised through the actual gallery launcher.

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
Unicode and native undo; cancellable streaming providers and application timers.

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

Automated checks exercise every gallery entry and its distinct initial view,
explicit origin commitment,
session-local collection state, hidden-mark actions, native input/undo,
streaming failure/recovery and timer disposal. The terminal showcase also
launches the board, reader and snippet picker, moves a batch, searches a chapter,
inserts and undoes a snippet, edits the catalog and layout playground, resizes
120→90→140 columns, and recovers the streaming provider. Physical emulator,
font, multiplexer and graphical display coverage still needs human use.
