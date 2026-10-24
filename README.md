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

**Experimental foundation; not a stable release or a MELPA package yet.**

## Try it

Clone this repository, then run:

```sh
make demo
```

The demo explores a small in-memory graph, showing nodes, content, forward links
and backlinks. It does not access your knowledge base. Explicit commitment
inserts a `demo:` link into the originating buffer, or one link per marked item
in the focused view.

Requires Emacs 28.1 or later. Native terminal child frames require an Emacs build
advertising `tty-child-frames` (introduced in 31.1). Older terminal builds use
ordinary windows. Graphical builds can also use native child frames. There are
no third-party runtime dependencies.

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
preserved. Deleting the host window disposes the panel. If the original buffer
was killed, closing displays another live buffer in the surviving window.

Each embedded session contains one view. Use independent sessions for separate
application-owned panels; multi-view owned layouts remain available via
`emacs-tui-mount`. Embedding within a text region of an existing buffer is not
implemented.

## Persistent applications

Run `make dashboard` for a live buffer/process dashboard. It updates once per
second, previews selected objects, and offers Refresh and Pause/Resume actions.
Use TAB to change views, n/p to move through items, RET to act, and q to close.
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
| `emacs-tui-view` | Describe a list or text preview |
| `emacs-tui-open` | Open an ephemeral query workspace |
| `emacs-tui-embed` | Borrow an application window for one panel; restore it on close |
| `emacs-tui-mount` | Open a persistent interface without query or origin policy |
| `emacs-tui-live-p` | Check whether an interface handle is active |
| `emacs-tui-update` | Replace a view's items or preview, reusing its buffer |
| `emacs-tui-refresh` | Reflow the workspace while preserving its input and selection |
| `emacs-tui-query` | Read the temporary query |
| `emacs-tui-current-item` | Read the selected object |
| `emacs-tui-toggle-mark` | Toggle the current item in a multi-select view |
| `emacs-tui-marked-items` | Read marked objects in source order |
| `emacs-tui-clear-marks` | Clear the focused or named view's marks |
| `emacs-tui-select` | Invoke the selected view's exploration action |
| `emacs-tui-commit` | Invoke the application's explicit commit callback |
| `emacs-tui-close` | Dispose the session without committing |

Both openers return an opaque session handle. Pass it to update/read/action
functions; interactive commands infer it from the workspace buffer. Internal
`emacs-tui--*` structures are not an application API.

## Interaction

| Key in query buffer | Action |
| --- | --- |
| Ordinary editing keys | Edit temporary query using normal Emacs commands |
| `TAB` / `S-TAB` | Focus next / previous view |
| `M-n` / `M-p` | Select next / previous item |
| `RET` | Invoke selection action without closing |
| `C-c C-c` | Commit selected item and close after success |
| `C-c C-l` | Cycle columns, rows and grid |
| `C-c C-m` | Toggle the current item's mark in a multi-select view |
| `C-c C-u` | Clear marks in the focused view |
| `C-g` / `C-c C-q` | Close without committing |

The editing cursor stays in the query buffer while logical focus and selection
move between views. An asterisk marks the focused view; faces use theme-friendly
inheritance. No global keys are installed.

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
marks visible without relying on color. `C-c C-u` clears the focused view.

Marks belong to individual views. `emacs-tui-marked-items` accepts optional
session and view ID arguments; by default it reads the focused view. It returns
the latest source objects in source order, including marked items hidden by
local filtering. `emacs-tui-clear-marks` accepts the same arguments.

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

The four-sided around-point layout, multiple floating surfaces,
history, per-view queries and tables are planned in
[ROADMAP.md](ROADMAP.md). The initial implementation renders full view content;
large-data performance is not yet characterized.

## Development and readiness

```sh
make check
make tty-smoke
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
These checks are not a visual
quality or performance benchmark.

CI targets Emacs 28.2, 29.4, 30.2 and 31.1 with pinned actions. Read
[docs/STATE.md](docs/STATE.md) for what has actually passed and remaining gaps,
and [docs/MELPA.md](docs/MELPA.md) for external release gates.

GPL-3.0-or-later. AI assistance is disclosed in source headers. The public API
is experimental until documented release criteria are met.
