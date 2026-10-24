# Demo guide

Start with `make gallery` from a checkout of current main. The gallery itself is
a persistent TUI: RET shows the selected tour, C-c C-o launches the selected
example, and C-c C-q closes. Launching closes the gallery first. After closing
an example, M-x emacs-tui-gallery opens the chooser again.

Every example also has a direct Make target, which starts a clean terminal
Emacs. No extra packages, sample files, network services or XOB setup are needed.
Examples using live buffers/processes are richer when loaded into your normal
Emacs; the three new sample-data showcases work immediately under Emacs -Q.

These examples live in the checkout's examples directory, outside the installed
runtime package. The fixed beta1 branch remains unchanged; use current main to
try this gallery. Do not mix new examples with an older installed toolkit.

## Choose a demo

| Make target | What to explore | Explicit effects |
| --- | --- | --- |
| gallery | Ten examples, tours, launch and cleanup | Launches your choice |
| catalog-demo | Search input, numeric sort, fill-width table, formatted details, hidden marks, batch actions | Collect/clear in session memory |
| layout-demo | Columns/rows/grid, maximize, hidden panels, tree, Unicode, editable text, live preview | Scratch edits only |
| stream-demo | Visible batches, debounce, cancellation, partial failure and recovery | Synthetic data only |
| graph-demo (also demo) | Original graph explorer, links/backlinks, Back/Forward, multi-selection, preview/commit split | C-c C-c inserts demo links into the original buffer |
| dashboard | Live buffer/process tables, periodic refresh, pause/resume, context actions, layouts | Preview and refresh only |
| tree | Buffer hierarchy, expand/collapse all, marks on hidden children, context actions | Display buffer or copy names when requested |
| composer | Two native editable fields, multiline composition and live preview | C-c C-c copies to kill ring |
| panel | Borrowed-window embedding and host restoration | RET displays another buffer elsewhere |
| filter-demo | Independent local filtering over live buffer metadata | Refresh/preview only |
| async-demo | Cancellable chunked search over captured buffer excerpts | Reads snapshots only |

To use the gallery in an existing Emacs, load matching source files from the
checkout (start a fresh Emacs if another emacs-tui version is already loaded):

```elisp
(add-to-list 'load-path "/path/to/emacs-tui")
(load "/path/to/emacs-tui/examples/emacs-tui-gallery.el")
(emacs-tui-gallery)
```

## Five-minute tours

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

The layout, catalog and streaming showcases request automatic presentation:
native child frames where supported, ordinary windows otherwise. Existing
persistent examples generally choose ordinary windows. Embedded panels always
borrow the selected host window. Native terminal child frames depend on the
tty-child-frames feature, not just the version number.

Multiple simultaneous sessions are supported and covered by lifecycle tests;
the gallery deliberately launches one demo at a time. To explore two, open a
demo from each of two separate application-owned windows. Source code shows
application policies, rather than claiming the toolkit has built-in databases,
network clients, lazy trees, inline text-region widgets or a full form system.
See README.md and ROADMAP.md for the implemented API and future goals.

Automated checks exercise every gallery entry, explicit origin commitment,
session-local collection state, hidden-mark actions, native input/undo,
streaming failure/recovery and timer disposal. The terminal showcase also
launches from the gallery, edits the catalog and layout playground, resizes
120→90→140 columns, and recovers the streaming provider. Physical emulator,
font, multiplexer and graphical display coverage still needs human use.
