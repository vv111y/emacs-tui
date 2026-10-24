# emacs-tui

Rich, ephemeral workspaces inside Emacs. Type in a temporary query buffer,
inspect several views, explore objects, and explicitly commit a result to your
original buffer. Applications supply the data and actions.

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

## Small application API

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
| `emacs-tui-open` | Open views with layout, backend and callbacks |
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

`emacs-tui-open` returns an opaque session handle. Pass it to update/read/action
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
Selection/query callbacks should only browse and update ephemeral views.

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
native child-frame backend when its capability is present. It is not a visual
quality or performance benchmark.

CI targets Emacs 28.2, 29.4, 30.2 and 31.1 with pinned actions. Read
[docs/STATE.md](docs/STATE.md) for what has actually passed and remaining gaps,
and [docs/MELPA.md](docs/MELPA.md) for external release gates.

GPL-3.0-or-later. AI assistance is disclosed in source headers. The public API
is experimental until documented release criteria are met.
