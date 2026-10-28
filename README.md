# emacs-tui

A general-purpose text user interface toolkit for Emacs, designed primarily
for terminal use. Compose views, layouts, input and actions into persistent
applications, embedded panels or ephemeral workspaces. Applications supply the
data, behavior and persistence policies.

The implementation now provides both long-lived mounted interfaces and ephemeral
query workspaces. Mounted interfaces stay open across actions and do not require
a query field or origin-buffer commit. Single panels can also borrow existing
application windows and restore their original buffer when closed.
XOB is an intended consumer; the toolkit is not specific to XOB, Org or graphs.

**0.1.0 beta4: ready for community testing.** The API remains experimental,
and the package is not on MELPA yet. The reviewed beta is available from its
versioned release branch while the matching GitHub prerelease tag awaits an
authenticated publication step.

## Install the beta

The beta release ref is `release/0.1.0-beta4`. It is fixed to the reviewed beta
contents and will not track later development. With
[straight.el](https://github.com/radian-software/straight.el) on Emacs 28.1 or
later, evaluate:

```elisp
(straight-use-package
 '(emacs-tui :type git
             :repo "https://github.com/vv111y/emacs-tui.git"
             :branch "release/0.1.0-beta4"
             :files ("emacs-tui*.el")))
```

Then load the toolkit with `(require 'emacs-tui)`. Report beta issues with the
Emacs version, operating system, terminal or emulator, whether
`(featurep 'tty-child-frames)` is non-nil, and a minimal reproduction. CI covers
Emacs 28.1 through 31.1 on Linux and 30.2/31.1 on macOS. Physical terminal
emulators and graphical display variants still need broader community use.

## Demo gallery

Beta4 includes twelve applications and capability showcases with guided tours,
including a validated settings form (`make form-demo`) and three independent
floating panels (`make multi-popup-demo`). In the latter, C-c 1/2/3 toggles
Objects/Details/Keys; C-c [ / ] scrolls visible Details without moving typing
focus. C-c p 1/2/3 moves each independently through eight positions; C-c C-e
expands/shrinks Details. Placement and size choices survive hiding/reopening.
C-c 0 hides all if any are visible, or shows all if none are visible. Native
typing stays in the source window. Use the matching beta4 checkout:

```sh
git clone --branch release/0.1.0-beta4 https://github.com/vv111y/emacs-tui.git
cd emacs-tui
make gallery
```

In the gallery, `RET` shows a tour and `C-c C-o` launches the selected demo.
Close it with `C-c C-q`, then `M-x emacs-tui-gallery` to choose another.
See [the demo guide](docs/DEMOS.md) for individual commands, feature coverage,
and step-by-step tours. Try the inline candidate popup, three-lane task board, chapter reader, embedded
snippet picker, object catalog, text composer, streaming search, original graph
explorer, or layout playground. Each works in a fresh Emacs.

The floating equipment inspector explores related objects without moving the
source point or editing its document. From the matching beta checkout, run
`make inspector-demo`: `C-c C-l` follows a related object, `C-c C-b` goes Back,
`C-c C-f` goes Forward, and `C-g` dismisses. Actions such as acknowledging an
object are explicit and separate from browsing. The native completion example
is separately available through `make completion-demo`.

Floating popups require graphical child frames or a build advertising
`tty-child-frames` (normally Emacs 31.1+). Unsupported terminals reject these
popups without replacing the source window. Other presentations retain their
ordinary-window fallback on Emacs 28.1+.

For development after this beta, use a separate checkout of `main`. The older
`release/0.1.0-beta1`, `release/0.1.0-beta2` and `release/0.1.0-beta3` branches
remain unchanged. The straight.el runtime recipe excludes examples. Use the matching source checkout
for the gallery so examples and toolkit come from the same revision.

## Graph explorer (original demo)

From the checkout, run:

```sh
make demo
```

The demo explores a small in-memory graph, showing nodes, content, forward links
and backlinks. It does not access your knowledge base. Explicit commitment
inserts a `demo:` link into the originating buffer, or one link per marked item
in the focused view.

RET inspects nodes and follows forward/backlinks. Back and Forward are explicit
named actions (`C-c C-a`, also available while editing the query); in view
buffers, `C-c [` / `C-c ]` invoke them directly. Reinspecting the same node does
not add a duplicate visit. Following a new branch after Back discards the old
forward route. Histories belong to individual demo sessions. They restore the
inspected node's preview and links, not query text, focus or snapshots of marks.
Normal source replacement rules still prune marks for links that disappear.
Commit continues to use the focused view's current selection or marks, rather
than the inspected node. Browsing never writes to the origin buffer.

The example implements history with private application state and the existing
selection/actions API. Other applications can define different traversal or
transaction policies without adopting graph history or ephemeral workspaces.

Requires Emacs 28.1 or later. Native terminal child frames require an Emacs build
advertising `tty-child-frames` (introduced in 31.1). Older terminal builds use
ordinary windows. Graphical builds can also use native child frames. There are
no third-party runtime dependencies.

## Anchored candidate popups

`make popup-demo` opens a disposable sample document with point near the center.
Type `map`, `buffer`, `window`, `café` or `日本語`. The popup floats above the
source; the original window remains the typing target and is never split.
`C-c C-p` cycles clockwise through north, northeast, east, southeast, south,
southwest, west and northwest around the word. `M-n`/`M-p` select candidates,
`TAB` explicitly replaces the word, `C-g` dismisses, and `C-c C-q` disables the
demo. Undo and ordinary source editing remain native.

From the gallery, this entry enables the demo in your original buffer without
inserting sample text. It requires graphical child frames or native terminal
child frames (`tty-child-frames`, available in supporting Emacs 31.1 builds).
Older terminal Emacs signals a capability error and leaves the host intact;
there is no window-splitting fallback for this presentation.

The general API reuses ordinary view descriptions and explicit session APIs:

```elisp
(setq my-popup
      (emacs-tui-popup
       :begin (car (bounds-of-thing-at-point 'symbol)) :end (point)
       :position 'south-west :width 30 :height 8
       :view (emacs-tui-view :id 'candidates :items '("mapcar" "mapconcat")
                             :on-select (lambda (_app item)
                                          (message "Chosen: %s" item)))))
(emacs-tui-update my-popup 'candidates :items '("mapcar" "mapcan"))
(emacs-tui-next-item my-popup)
(emacs-tui-reposition-popup my-popup 'north-east) ; omit position to cycle
(emacs-tui-select my-popup)                       ; application action only
(emacs-tui-close my-popup)
```

The popup owns one child frame and one read-only view buffer. It borrows no host
windows and installs no host keymap or completion policy. Applications supply
their own data, typing hooks and explicit actions; the example minor mode owns
its completion transaction. Always pass the popup handle while typing in the
source, since that buffer retains its own application context. Editable popup
views are rejected. View-focus/layout commands retain source input focus and a
single popup view. Closing, killing or repurposing the source releases the popup;
leaving its input window dismisses it after the command.

Anchors use native glyph coordinates, including wide text. A range on one visual
line surrounds the entire word; wrapped or partly hidden ranges anchor at the
visible point glyph. Placement is clamped to the parent frame, so positions can
coincide or overlap the anchor near an edge. Use a central word to inspect all
eight placements. Graphical window-manager/font variants still need community
validation; native terminal behavior has a separate interactive CI scenario.

## Floating object inspector

`make inspector-demo` opens an equipment note with a read-only object preview
anchored to `pump`. `M-n`/`M-p` scroll details without taking source focus;
`C-c C-p` moves the popup and `C-c C-a` explicitly toggles acknowledgement.
The popup stays open and the document is unchanged by that action.
`C-c C-l` follows related equipment (pump → valve → sensor → pump); `C-c C-b`
and `C-c C-f` go back and forward within the same popup. Source point stays put.
`C-g` dismisses, clears navigation history and restores source bindings.
Put point on `valve` and run
`M-x emacs-tui-inspector-demo-at-point` to inspect another object.

This application supplies objects and actions directly, with no completion
provider, query field or source insertion. Acknowledgements belong to the source
buffer, survive popup dismissal and disappear on major-mode change or buffer death.
The chosen object remains fixed while ordinary source edits continue. The
gallery launches the same self-contained demonstration; native child frames
are required.

An existing floating panel can be resized without replacing its child frame:

```elisp
(emacs-tui-resize-popup my-popup 50 12) ; requested columns/rows, including header
```

Both dimensions must be integers of at least two. Native viewport bounds clamp
actual dimensions; source focus, requested placement, selection and marks are
retained. A failed native fit closes the popup through its normal cleanup policy.
The multi-popup demo uses `C-c C-e` to expand/shrink Details independently and
remembers its size choice across hide/show. Ordinary tiled sessions are rejected.

Long read-only previews can also be scrolled in any visible owned pane:

```elisp
(emacs-tui-scroll-view my-popup 'details 3)  ; forward three lines
(emacs-tui-scroll-view my-popup 'details -3) ; backward
(emacs-tui-scroll-view my-popup 'details)    ; nearly one window
```

Scrolling preserves selected source window/buffer and logical view focus. It
does not run actions, alter selection or reveal hidden panes. Hidden, list and
editable input views are rejected. Native beginning/end-of-buffer errors are
preserved. Use ordinary navigation for lists and native editing in input views.

## Native completion providers

The optional adapter uses your buffer's existing
`completion-at-point-functions` and Emacs completion styles:

```elisp
(require 'emacs-tui-completion)
(emacs-tui-completion-mode 1) ; buffer-local; requires native child frames
```

Invoke `completion-at-point` normally (`C-M-i` in Emacs Lisp mode). While the
popup is visible, type to filter, use `M-n`/`M-p` to select, `C-c C-p` to cycle
positions, `TAB` to accept, and `C-g` to dismiss. Other source bindings apply
when it is closed. `make completion-demo` opens a disposable Lisp document
using Emacs's actual symbol provider. The literal-data popup demo remains a
separate example of automatic activation while typing.

Display honors predicates, category style overrides, display sorting,
affixation and annotations. Affixation takes precedence over annotation.
Faces and other display properties returned on the affixed candidate, prefix
and suffix are retained in the popup. Acceptance inserts only the raw candidate
text, without decoration or text properties.
Acceptance preserves completion base prefixes and text beyond the field's
suffix boundary, strips candidate display properties, and uses native undo.
It rechecks the candidate and source immediately before editing. A successful
acceptance closes the popup and calls the provider's captured exit function
once with the completed field, including its base prefix. Status is `exact`
when the candidate opens a new field (such as a directory), otherwise `finished`.
An exit-callback error leaves the accepted text in place; an editing error
rolls back the edit and retains the popup. Browsing and dismissal never call
the exit function or insert a common prefix, even with a sole candidate.

Initial provider dispatch is explicit. Once active, native source edits update
the captured table until its context expires. Completion tables run
synchronously and must return promptly.
Tables and metadata callbacks compute candidates without editing the source or
switching its current buffer/window; effects belong in explicit exit callbacks.
Stale source or ownership changes reject display/acceptance and preserve user
edits and focus choices. `emacs-tui-completion-limit` defaults
to 200 displayed rows; all matches are computed and sorted, then only the
displayed subset is decorated. This limits display work, not provider work.
Grouping, documentation panes, automatic initial CAPF dispatch and asynchronous
completion tables are not implemented by this adapter. The general toolkit's
async provider API remains separate.

Disable `emacs-tui-completion-mode` to restore the previous buffer-local
frontend, or the current global default when none was local. A frontend
installed afterward is preserved. Changing major mode or killing the source
disposes the active completion. The core library does not load this adapter.

## Embedded panels

Run `make panel` to browse buffers in the selected window. RET displays a buffer
elsewhere; q restores the original buffer and position without deleting the
host window. The application continues to own its buffers and windows.

```elisp
(emacs-tui-embed
 :window (selected-window)
 :view (emacs-tui-view :id 'status :title "Status" :text "Ready"))
```

`emacs-tui-embed` accepts one list or text view, an optional `:window` (selected
window by default), and the same `:provider`, `:debounce` and `:on-close` options
as `emacs-tui-mount`. It selects the host window and owns only its new view
buffer and session resources. Dedicated, minibuffer and already claimed windows
are rejected. Closing restores the host buffer, point and scroll position;
positions track edits made to that buffer elsewhere. A repurposed window is
preserved, including its cursor when a late update arrives before ownership
invalidation. The next refresh/window-state check disposes an invalid panel.
Deleting the host window disposes the panel. If the original buffer
was killed, closing displays another live buffer in the surviving window.

Each embedded session contains one view. Use independent sessions for separate
application-owned panels; multi-view owned layouts remain available via
`emacs-tui-mount`. Embedding within a text region of an existing buffer is not
implemented.

## Tables

Give a view `:columns` to display its existing items as table rows:

```elisp
(emacs-tui-embed
 :view (emacs-tui-view
        :id 'jobs
        :items '((:id a :label "Build" :seconds 12)
                 (:id b :label "Test" :seconds 3))
        :columns (list (emacs-tui-column :id 'name :title "Job"
                                         :width 24 :value :label)
                       (emacs-tui-column :id 'time :title "Seconds"
                                         :width 10 :value :seconds :align 'right))))
```

Column `:value` is a plist keyword or a pure function receiving the original
item. Widths count display columns; one column may use `:width 'fill` to consume
the live window's remaining width without mutating its description. It shrinks
to one column when fixed columns already overflow. Wide characters are clipped
at cell boundaries, and tabs/newlines display as spaces. Fixed overflow can be
scrolled horizontally with ordinary Emacs commands. Headers occupy the first
buffer line; they are not sticky while scrolling. Table rows use their columns
instead of the list annotation. Actions still receive the original item.

Press s to choose a column; C-u s sorts descending. An empty answer restores
source order. Applications can call `(emacs-tui-sort app 'jobs 'time t)` directly.
Sorting is stable, preserves the selected identity and marks, and survives
streaming replacement updates without mutating source order. Marked items are
still returned in source order. The default comparator orders numbers
numerically before other values, then compares their displayed strings;
`:lessp` can supply a comparator over raw projected values.

Local ephemeral queries search full column values and item labels, including
text clipped from display. Provider-driven filtering stays application-owned.
Multi-term matching prepares the full search text once per item per filter
operation. New queries and source replacements read current projected values;
there is no persistent search cache.
The dashboard demonstrates sortable buffer sizes, modes and process metadata.
A failed cell projection or comparator leaves the previous source, selection,
marks and rendered content intact. Failed provider publications terminate that
request while retaining its last valid results.
Column editing, multiple weighted fill columns and sticky headers are future work.

Text previews retain their cursor, scroll and narrowing when focus changes or
updates repeat identical text and properties. Changed text or properties render
from the beginning. Unchanged previews do not trigger buffer-change hooks.

## Trees

```elisp
(emacs-tui-mount
 :views
 (list (emacs-tui-tree
        :id 'objects :title "Objects" :multi-select t
        :items '((:id project :label "Project"
                  :children ((:id readme :label "README" :value "README.md")
                             (:id sources :label "Sources"))))
        :on-select (lambda (_app item) (message "%S" (plist-get item :value))))))
```

`emacs-tui-tree` uses the same original item objects, selection, marks and
explicit actions as lists. In tree buffers, `SPC` toggles a branch, right opens
it or enters its first child, and left closes it or selects its parent. These
commands do not invoke selection actions. `+`/`-` cues and indentation work
without color. `RET` invokes the application's action as usual.

In tree buffers, `C-c +` expands every indexed branch and `C-c -` collapses
all branches. Applications can call `(emacs-tui-tree-expand-all app 'objects)`
or `(emacs-tui-tree-collapse-all app 'objects)` for a named panel, including a
hidden one, without changing focus. Expansion preserves the selected identity;
collapse selects its root ancestor. Both preserve marks on hidden descendants
and invoke no selection actions or child accessors. Clear local search first.
These operations apply to the current finite snapshot; source replacement
retains expansion by identity, while newly introduced branches start collapsed.

`:children` defaults to the plist keyword `:children`; it can also be a pure
function returning child items. The toolkit indexes the entire finite forest
once on construction or `emacs-tui-update :items ROOTS`, including collapsed
nodes. Children functions must return promptly; applications can load data
asynchronously and publish snapshots through the existing provider API.
Plist nodes require explicit non-nil `:id` values; strings identify themselves.
IDs must be globally unique. Cycles and repeated nodes are rejected before
source replacement. Lazy loading and shared graph occurrences are future work.

Roots start collapsed. Updates retain expansion, visible selection and marks
by surviving ID, and marked items include collapsed descendants in depth-first
source order. Local query matching temporarily reveals matches and their
ancestor paths. Clear the local query before changing expansion; clearing it
restores the prior expansion state. Application/provider-owned search retains
control over filtering. Tree buffers have no table sorting or text-preview
transition: update their root items and use a separate preview view.

Run `make tree` for the mode-grouped buffer browser with a preview. `g` refreshes
its snapshot, `RET` previews, and `o` explicitly displays a selected buffer
elsewhere. It supports persistent mounting and the shared lifecycle; tree views
also work in embedded panels and the ephemeral query workflow.

## Editable inputs

Use native Emacs editing in persistent applications and embedded panels:

```elisp
(emacs-tui-mount
 :views
 (list (emacs-tui-input
        :id 'body :title "Draft" :value "Edit me"
        :on-change (lambda (app _id value)
                     (emacs-tui-update app 'preview :text (upcase value))))
       (emacs-tui-view :id 'preview :text "EDIT ME")))
```

`emacs-tui-input-value` reads the full current string by session and view ID,
ignoring narrowing and stripping text properties. Inputs support multiline
text, Unicode, ordinary editing and undo. `TAB`/`S-TAB` switch views;
`C-c C-q` closes. Ordinary letters and `RET` retain their editing meanings.
Application/view keymaps can add explicit validation, submit or reset commands.

`:on-change` receives `(session id value)` after edits, including undo. It is
not called on initialization, focus/reflow or programmatic updates. Errors are
reported while retaining the edit and live interface. Update an input with
`emacs-tui-update :text STRING`: changed content starts at the beginning and
clears undo; identical text/properties preserve edit state. Inputs reject item
updates and nil text. Rendering does not submit or save application data.

Run `make composer` for two editable fields and a live composition preview.
`C-c C-c` explicitly copies the composition to the kill ring, keeping the
application open. Closing discards scratch inputs. This initial control is
available through `emacs-tui-mount` and `emacs-tui-embed`; the dedicated-query
`emacs-tui-open` workflow currently rejects editable views. Field validation,
completion and application persistence remain application policies.

## Per-view filters

Each list, table or tree can have its own local query without changing source
items. Connect a native input to a result view:

```elisp
(emacs-tui-mount
 :views (list (emacs-tui-input
               :id 'search :on-change
               (lambda (app _id value) (emacs-tui-set-query app 'results value)))
              (emacs-tui-view :id 'results :items '("alpha beta" "gamma")
                              :multi-select t)))
```

`emacs-tui-set-query SESSION ID STRING` applies literal, case-insensitive terms
to that view's labels and table values. Trees reveal matching ancestor paths.
It preserves the source objects, hidden marks, sorting and surviving visible
selection. Later source updates keep the query. `emacs-tui-query SESSION ID`
reads the effective view query; omitting ID still reads the workspace query.

An empty string disables query filtering; tree expansion still applies.
Nil removes the override
and inherits the workspace query policy. Explicit local filters also narrow
application/provider-owned results, without invoking callbacks or restarting
providers. Text previews and editable inputs are not filter targets.

Run `make filter-demo` for a persistent search field, sortable buffer table and
preview. Mark a buffer, hide it with a query, then clear the field: its mark
survives. `C-c C-r` refreshes the source snapshot while retaining the filter.

## Named context actions

Describe application operations and attach them to a view:

```elisp
(emacs-tui-view
 :id 'objects :items '("alpha" "beta") :multi-select t
 :actions
 (list (emacs-tui-action
        :id 'copy :title "Copy names"
        :enabled (lambda (_app items) (consp items))
        :run (lambda (_app items) (kill-new (mapconcat #'identity items "\n"))))))
```

Press `a` in a read-only view or `C-c C-a` in any interface buffer to choose an
available action. Ordinary input letters remain editable. Call
`emacs-tui-act SESSION ID` to invoke a named action from an application command.

`:run` receives `(session items)`. Marked objects take precedence, including
hidden marks in source order; otherwise `items` contains the selected object,
or nil when there is no target. This allows target-free actions such as
Refresh. Optional `:enabled` accepts t (the default), nil to disable, or a pure
availability function receiving the same arguments; it must return promptly. Rendering/navigation never evaluate action callbacks
or predicates. Menus re-read targets and recheck availability after selection;
closing the interface or changing its focused view aborts stale menu dispatch.
Accepted case-insensitive names resolve to their action; exact spelling wins,
and ambiguous folded names require an exact candidate.

Action IDs are unique within each view. Descriptions are shared configuration;
do not mutate them after use. The toolkit does not automatically close, commit,
or roll back action effects. Applications own validation and persistence.
Legacy `RET` selection remains a separate, current-item exploration action.

`make tree` now offers Preview, Display buffer, Copy names and Refresh. Preview
and Display require one suitable target; Copy names supports marked batches,
and Refresh works with an empty tree. Existing `g` and `o` shortcuts still work.

## Application commands

Pass an ordinary Emacs keymap as `:keymap` to any entry point, or to an
individual `emacs-tui-view`. Bindings resolve in this order: view, application,
then toolkit defaults. These maps affect view buffers only; the ephemeral
query keeps native text editing. Maps are referenced without changing their
bindings or parents, so application changes to a supplied map remain live.

```elisp
(let ((map (make-sparse-keymap)))
  (define-key map (kbd "r")
    (lambda () (interactive)
      (emacs-tui-update (emacs-tui-current-session) 'status :text "Updated")))
  (emacs-tui-embed :keymap map
                   :view (emacs-tui-view :id 'status :text "Ready")))
```

Commands run in the active view buffer. `emacs-tui-current-session` supplies
its live handle for explicit update APIs; it signals a user error outside a
live interface. Native prefix maps, command remapping and help lookup remain
available. Existing n/p, TAB and q bindings remain unless overridden.

Applications can navigate directly using configured view and item identities:

```elisp
(emacs-tui-set-selection app 'results 'item-id)
(emacs-tui-focus-view app 'results)
(emacs-tui-current-view app)             ; => results
(emacs-tui-current-item app 'results)    ; => original source object
```

Selection updates UI state without invoking exploration, commit or context
actions. It retains queries, sort and marks. The identity must be in the current
projection; filtered, collapsed or absent items signal a user error. Ordinary
views with duplicate identities select the first match. Text/input views have
no item selection. Setting a hidden panel's row retains its state until explicit
focus reveals it. A named item read also works for hidden panels; the existing
focused read and action behavior is unchanged. Focus uses the current layout and
maximize policy, including keeping ephemeral query editing in place. Named
focus and next/previous-view cycling reject an invalidated surface before
changing focus or reusing a window for a hidden panel.

## Persistent applications

Run `make dashboard` for a live buffer/process dashboard. It updates once per
second, previews selected objects, and offers Refresh and Pause/Resume actions.
Use TAB to change views, n/p to move through items, RET to act, and q to close.
The g key refreshes and P pauses/resumes updates from any dashboard view.
The process table's actions menu (`a`) can inspect an associated named live
buffer: it explicitly clears the buffer list's local filter, selects that row
and previews it inside the dashboard.
The dashboard does not edit buffers or start/terminate processes.

Use `emacs-tui-mount` to build an application without query or origin-buffer
policies. For example, in a file with `lexical-binding: t`:

```elisp
(let ((count 0))
  (emacs-tui-mount
   :views
   (list
    (emacs-tui-view
     :id 'actions :items '("Increment")
     :on-select (lambda (app _item)
                  (setq count (1+ count))
                  (emacs-tui-update app 'status :text (number-to-string count))))
    (emacs-tui-view :id 'status :text "0"))))
```

Mounted applications share views, layouts, marks and update APIs with ephemeral
workspaces. They own their split windows or child frame and view buffers. The
launching buffer/window may disappear without ending the application. Native
window focus and keyboard navigation select the active view. Application
callbacks own data mutations; rendering and layout do not perform them.

All entry points accept `:on-close (lambda (app) ...)` for application cleanup. It is
called once after the handle becomes inactive, including startup failures after
allocation. Use it to cancel application-owned timers or processes. The toolkit
still cancels its own provider work. `emacs-tui-live-p` checks a retained handle;
`emacs-tui-close` explicitly disposes it. Persistent here means long-lived in the
running Emacs session, not automatic storage across restarts.

A mounted provider uses the existing async contract with an empty query string.
It starts once; applications can publish updates until disposal. Mounted views
have no origin commit action; use explicit application actions for persistence.
Use `emacs-tui-embed` for a single panel in an application-owned window.

## Ephemeral workspaces

```elisp
(require 'emacs-tui)

(emacs-tui-open
 :views (list (emacs-tui-view :id 'results :title "Results"
                             :items '("Alpha" "Beta" "Gamma")))
 :on-commit (lambda (_session item origin)
              (goto-char origin)
              (insert item)))
```

Strings work for simple lists. Structured items carry identity and application
data without forcing applications to represent everything as display text:

```elisp
(emacs-tui-view
 :id 'nodes :title "Nodes"
 :items '((:id "n1" :label "Knowledge graphs" :annotation "3 links"
           :value (:node-id "n1")))
 :on-select (lambda (session item)
              (emacs-tui-update session 'preview
                                :text (plist-get item :label))))
```

Include a view with ID `preview` in that session. Selection can update any view
and continue exploration; commitment is a separate command.

| Function | Purpose |
| --- | --- |
| `emacs-tui-view` | Describe a list, table or text preview |
| `emacs-tui-tree` | Describe a finite hierarchy of original item objects |
| `emacs-tui-tree-toggle` | Toggle the selected branch |
| `emacs-tui-tree-expand` / `emacs-tui-tree-collapse` | Open/enter or close/visit parent |
| `emacs-tui-input` | Describe an editable input view |
| `emacs-tui-input-value` | Read the full input string |
| `emacs-tui-open` | Open an ephemeral query workspace |
| `emacs-tui-popup` | Show a read-only view around a source word while retaining typing focus |
| `emacs-tui-popup-supported-p` | Check native popup capability without allocating a surface |
| `emacs-tui-reposition-popup` | Choose or cycle eight compass positions |
| `emacs-tui-resize-popup` | Resize an existing popup within native viewport bounds |
| `emacs-tui-layout-popup` | Compute a clamped anchor-relative rectangle without display effects |
| `emacs-tui-completion-mode` | Optional buffer-local frontend for existing completion-at-point providers |
| `emacs-tui-scroll-view` | Scroll a visible read-only preview without taking input focus |
| `emacs-tui-completion-next` / `emacs-tui-completion-previous` | Browse candidates while retaining source input focus |
| `emacs-tui-completion-accept` / `emacs-tui-completion-dismiss` | Explicitly insert the selected completion or close unchanged |
| `emacs-tui-completion-move` | Cycle the active completion popup's compass position |
| `emacs-tui-embed` | Borrow an application window for one panel; restore it on close |
| `emacs-tui-column` | Describe a table column and its item projection |
| `emacs-tui-sort` | Sort table rows without changing source order or item identity |
| `emacs-tui-action` | Describe a named application action and availability predicate |
| `emacs-tui-act` | Choose or invoke an action on marks or the current item |
| `emacs-tui-current-session` | Return the current live interface handle for application commands |
| `emacs-tui-current-view` | Read the logically focused view ID |
| `emacs-tui-focus-view` | Focus and reveal a named panel using the current presentation policy |
| `emacs-tui-set-selection` | Choose a projected row by identity, retaining focus and application data |
| `emacs-tui-mount` | Open a persistent interface without query or origin policy |
| `emacs-tui-live-p` | Check whether an interface handle is active |
| `emacs-tui-update` | Update items, preview or title, reusing its buffer |
| `emacs-tui-set-layout` | Choose columns, rows or grid directly; retain view state |
| `emacs-tui-toggle-maximize` | Enlarge the focused panel or restore the layout |
| `emacs-tui-refresh` | Reflow the workspace while preserving its input and selection |
| `emacs-tui-query` | Read the workspace query or a view’s effective query |
| `emacs-tui-set-query` | Set or clear a local list/table/tree filter |
| `emacs-tui-current-item` | Read the focused or named view's selected source object |
| `emacs-tui-first-item` / `emacs-tui-last-item` | Select a projection endpoint without application actions |
| `emacs-tui-toggle-mark` | Toggle the current item in a multi-select view |
| `emacs-tui-mark-all` | Mark the focused or named view’s projected rows |
| `emacs-tui-invert-marks` | Invert marks in that projection, preserving hidden marks |
| `emacs-tui-marked-items` | Read marked objects in source order |
| `emacs-tui-clear-marks` | Clear the focused or named view's marks |
| `emacs-tui-select` | Invoke the selected view's exploration action |
| `emacs-tui-commit` | Invoke the application's explicit commit callback |
| `emacs-tui-close` | Dispose the session without committing |

The creation functions return an opaque session handle. Pass it to update/read/
action functions; interactive commands infer it from a TUI buffer. Popup callers
pass it explicitly while typing in their unchanged source buffer. Internal
`emacs-tui--*` structures are not an application API.

## Interaction

| Key in query buffer | Action |
| --- | --- |
| Ordinary editing keys | Edit temporary query using normal Emacs commands |
| `TAB` / `S-TAB` | Focus next / previous view |
| `M-n` / `M-p` | Select next / previous item; numeric prefixes repeat, with wrapping |
| `C-c <` / `C-c >` | Select first / last projected item |
| `RET` | Invoke selection action without closing |
| `C-c C-c` | Commit selected item and close after success |
| `C-c C-l` | Cycle columns, rows and grid; a prefix argument chooses by name |
| `C-c C-f` | Maximize the focused view / restore layout |
| `C-c C-a` | Choose a named context action |
| `C-c C-m` | Toggle the current item's mark in a multi-select view |
| `C-c *` | Mark every projected row in the focused multi-select view |
| `C-c C-t` | Invert marks on those rows |
| `C-c C-u` | Clear marks in the focused view |
| `C-g` / `C-c C-q` | Close without committing |

The editing cursor stays in the query buffer while logical focus and selection
move between views. An asterisk marks the focused view; faces use theme-friendly
inheritance. No global keys are installed.

Use numeric prefixes with item movement, for example `C-u M-n` moves four
items and `M-3 M-p` moves three backward. Negative counts reverse direction;
zero leaves selection in place. `C-c <` / `C-c >` select the first/last row of
the current filtered/sorted/tree projection, including off-screen rows. Empty
projections are unchanged; text/input views reject endpoint selection. Queries,
marks and application actions remain untouched. Query editing still uses native
`M-<` / `M->`. Programmatic previous-item accepts an optional backward count.

Without a query callback, whitespace-separated terms match labels literally,
case-insensitively and in any order. Supply `:on-query (lambda (session query)
...)` for synchronous searching; publish results with `emacs-tui-update`.

`:on-commit` receives `(session item origin-marker)` in the origin buffer at the
captured location. Successful callbacks close the workspace. An error rolls
back edits to that buffer and leaves the workspace open. Applications remain
responsible for transactions involving other buffers, files or external state.
In the ephemeral workflow, selection/query callbacks should browse and update
views; commit is the explicit persistence boundary. Mounted applications choose
their own action and persistence semantics.

## Maximize and restore

Press `C-c C-f` or call `emacs-tui-toggle-maximize` to give the focused view the
whole TUI panel. The ephemeral query stays visible, and unrelated application
windows keep their space. `TAB`/`S-TAB` still visit every view within the enlarged
panel. Toggle again to restore the selected layout; cycling layouts while
maximized chooses the layout used on restore. Applications can select a layout
directly with `(emacs-tui-set-layout app 'rows)`. An unchanged choice performs
no reflow or rendering; a choice while maximized records the layout for restore
without replacing the visible pane. Input/undo, local queries, selection, marks,
reading state and focus are retained. Invalid layout names and repurposed
surfaces are rejected before layout state changes. The dashboard's Actions
view demonstrates explicit layout choices without restarting its update timer.

Inputs retain edits, undo and narrowing. Text views retain their individual
cursor and scroll when hidden, and lists/trees retain selection, marks and
expansion. Native edits made to hidden inputs retain their updated buffer point
and undo history. Changed preview content still starts at the beginning. Maximizing
does not invoke application actions or restart providers. A single-view panel
already fills its surface, so toggling it has no effect.

## Multi-selection and batch actions

Add `:multi-select t` to a list view to enable independent marks:

```elisp
(emacs-tui-open
 :views (list (emacs-tui-view :id 'results :multi-select t
                             :items '("Alpha" "Beta" "Gamma")))
 :on-commit
 (lambda (session item origin)
   (let ((items (or (emacs-tui-marked-items session) (list item))))
     (goto-char origin)
     (insert (mapconcat #'identity items "\n")))))
```

`C-c C-m` toggles a mark without changing the query or invoking selection or
commit callbacks. `[x]` / `[ ]` indicators and a count in the view title make
marks visible without relying on color. `C-c *` marks every row in the current
projection; `C-c C-t` inverts those marks. Include off-screen rows but exclude
filtered items and collapsed descendants, retaining their existing marks.
`C-c C-u` clears all marks in the focused view, including hidden ones.

`emacs-tui-mark-all` and `emacs-tui-invert-marks` accept optional session and
view ID arguments. A named hidden panel uses its current projection without
revealing it or taking focus. Both operations preserve selection and queries,
perform one staged render and invoke no application action. An empty projection
is unchanged. The graph demo can bulk-mark filtered node results and commit
them explicitly in source order.

Marks belong to individual views. `emacs-tui-marked-items` accepts optional
session and view ID arguments; by default it reads the focused view. It returns
the latest source objects in source order, including marked items hidden by
local filtering. `emacs-tui-clear-marks` accepts the same arguments. If an
application projection or buffer hook fails during a toggle or clear, the prior
marks and display remain available; fixing the cause allows a normal retry.

Use stable `:id` values for structured items. Multi-select views require unique
identities, including unique strings when using string items. Reordering or
updating an item's payload retains its mark; removing it from source items
removes the mark. A text preview replaces the list and clears its marks.
Async query changes clear provider-owned results and their marks immediately.

The commit callback still receives `(session item origin-marker)`. In a
multi-select view, `item` can be nil when all marked items are hidden by local
filtering; read `emacs-tui-marked-items` to perform the batch action. Unmarked
ordinary views retain single-item behavior. Commit errors roll back edits to
the origin buffer and leave the workspace and marks available for retry.

## Asynchronous providers

Use `:provider` for asynchronous searches and streaming results. It receives
`(session query publish fail)` and returns either nil or a zero-argument
cancellation function. For example, this small provider defers a result using
an Emacs timer:

```elisp
(emacs-tui-open
 :views (list (emacs-tui-view :id 'results))
 :debounce 0.08
 :provider
 (lambda (_session query publish fail)
   (let ((timer
          (run-at-time
           0.2 nil
           (lambda ()
             (condition-case err
                 (funcall publish 'results :items (list (concat "Result: " query)))
               (error (funcall fail err)))))))
     (lambda () (cancel-timer timer)))))
```

Put asynchronous callbacks in a file with `lexical-binding: t`, as the bundled
examples do. `make async-demo` opens a buffer explorer that searches snapshots
in bounded chunks, streams results and previews the selected excerpt.

`publish` takes a view ID followed by the same `:items` and `:text` keywords as
`emacs-tui-update`. Each call replaces those fields; accumulate items in your
provider to stream a growing list. It returns t when accepted and nil when
obsolete. Provider results are not filtered again by the workspace.

The default debounce is 0.08 seconds. Even zero schedules startup through the
event loop. Query changes invalidate previous callbacks immediately, cancel
pending timers and invoke the previous cancellation function. Views previously
published by the provider are cleared immediately so old results cannot be
selected or committed for a new query; untouched static views remain. Closing
the workspace also invalidates callbacks and cancels outstanding work.

Call `fail` with a message string or an Emacs error condition to end the current
request and report an error. The workspace remains editable and later queries
can recover. Providers must start asynchronous work and return promptly: a
timer does not make blocking computation or I/O concurrent. Return a
cancellation function that stops your timers/processes and releases resources.
It may be called after a search has completed, so completed work should be a
safe no-op. Provider and cancellation errors are reported without disabling
query editing.
Publish through the supplied callback to get stale-result protection;
`emacs-tui-update` itself is an immediate update API. `:provider` and `:on-query`
are mutually exclusive.

A live view title can be updated with the same API:

```elisp
(emacs-tui-update app 'jobs :title "Jobs (12)")
(emacs-tui-update app 'jobs :title "Jobs ready" :items results)
```

`:title` must be a string; `""` clears it and omission keeps it unchanged.
Percent signs are literal title text, not Emacs mode-line format constructs.
Title-only updates change the header without filtering, projecting cells or
editing the view buffer. Selection, marks, query, native undo, narrowing and
scroll remain intact, including hidden panels. Combined data/title updates
commit the title only after successful rendering. The dashboard uses titles
for current snapshot counts and running/paused status. Provider publications
accept the same keyword and retain the existing provider-owned view lifecycle.

## Display backends

`:backend 'auto` uses native child frames when supported, with an ordinary
window fallback. Explicit choices are `child-frame` and `windows`. The first
backend uses one retained child frame containing split windows; the second
owns a split subtree and removes its own windows on exit. It does not restore a
stale snapshot over unrelated window changes.

Columns, rows and grid reflow automatically after window or frame dimensions
change. Query text, cursor position, logical selection and preview scroll state
are preserved. Reflow does not rerun search providers. A modified or unusable
workspace surface closes safely; unrelated windows and application buffers are
preserved. `emacs-tui-refresh` is also available for an explicit reflow.

Multi-panel floating workspaces, broader application history, per-view
asynchronous providers and richer form controls are planned in
[ROADMAP.md](ROADMAP.md). Source/filter updates render full view content;
selection movement reuses rendered rows. The first interpreted-source
[navigation baseline](bench/results/2026-10-24-navigation/README.md) records
latency and allocations on 1,000/10,000-row lists and tables. Broader application
and display performance remains to be measured.

## Development and readiness

`make clean benchmark` measures real command-loop/PTY latency, allocations and
controlled provider stages, retaining raw samples and p50/p95/p99. See
[docs/PERFORMANCE.md](docs/PERFORMANCE.md) for workloads, clocks and limitations.
Use `BENCH_ARGS='--load-mode bytecode'` for fresh isolated compilation with the
selected Emacs. Reports verify actual loaded definitions and record the mode.

```sh
make check
make tty-smoke
# With pinned build tools prepared as documented:
make package-check
```

ERT exercises real buffers/windows, filtering, selection, commit rollback,
cleanup, layout invariants and provider lifecycle races. A real-process test
also streams results through a pipe and checks process disposal (requires
`cat`; skipped when unavailable). The terminal smoke test starts an actual Emacs
TTY in a pseudo-terminal, waits for asynchronous results, exercises
typing/select/commit, shrinks and expands
the terminal using real resize signals, and requires the
native child-frame backend when its capability is present. A second PTY smoke
checks queryless view navigation, actions, resize and launcher-buffer disposal.
Additional scripts check embedded host restoration, table sorting and marks,
multiline editable views with undo, and tree expansion/marks/source updates
across focus changes and resizes. A shared ownership stress test runs 75
batch lifetimes and 45 additional lifetimes in a real TTY at three sizes. It
rotates ephemeral, persistent and embedded interfaces, keeps another session
live, dispatches actual provider timers, and checks cancellation, stale replies,
owned buffers/processes/timers/markers, display resources and host edits.
The graph demo's eighth terminal script exercises Back/Forward keys, retained
query/marks, maximize/restore, both resizes and explicit selection commitment.
A ninth scenario attaches two distinct PTYs to one private Emacs server using
`emacsclient`. It sends native input to each, updates a background interface
without taking the other client's focus, resizes the terminals independently,
deletes one client frame and continues using the survivor before checking final
resource cleanup. Set `EMACSCLIENT` if the matching executable is not on PATH.
A tenth scenario kills the attached client's process group without asking Emacs
to delete its frame. It requires asynchronous session disposal, provider
cancellation, stale-publication rejection and continued native input on the
surviving terminal before checking final hook and resource cleanup.
These checks are not a visual quality or performance benchmark.

To diagnose asynchronous resize ordering, run an opt-in fault probe:

```sh
EMACS_TUI_REFLOW_FIXTURE=test/tty-input-smoke.el EMACS_TUI_REFLOW_FAULT=delay \
  python3 test/run-tty-smoke.py test/tty-reflow-probe.el
```

The delayed automatic hook must still pass both resizes. Changing the fault to
`disabled` must exit unsuccessfully at the fixture's original polling deadline;
it is a diagnostic failure, not a passing smoke scenario. Both modes preserve
the fixture's assertions and never force a refresh. Use the same entry point
with the ephemeral, embedded, persistent, table, input, tree or graph fixture.
`make tty-smoke` also checks delayed success and the specific bounded failure
for input and tree scenarios. An unrelated error or a broken fixture is rejected,
so a generic unsuccessful exit cannot pass the negative check.

CI targets Emacs 28.1, 28.2, 29.4, 30.2 and 31.1 on Linux, plus 30.2 and 31.1
on hosted macOS, with pinned actions. Every runtime-matrix job runs the complete checks and
real terminal scripts; runtime identity and backend results are logged.
A separate package job builds the candidate archive and tests clean installation
on Emacs 31.1 and the declared 28.1 floor. Read
[docs/STATE.md](docs/STATE.md) for what has actually passed and remaining gaps,
[docs/PACKAGING.md](docs/PACKAGING.md) for archive/clean-install validation,
and [docs/MELPA.md](docs/MELPA.md) for external release gates.

GPL-3.0-or-later. AI assistance is disclosed in source headers. The public API
is experimental until documented release criteria are met. See
[API stability and migration policy](docs/API-STABILITY.md) for the supported
application surface, experimental changes and the future stable-release gate.
