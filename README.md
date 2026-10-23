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
inserts a `demo:` link into the originating buffer.

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
| `emacs-tui-query` | Read the temporary query |
| `emacs-tui-current-item` | Read the selected object |
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
| `C-g` / `C-c C-q` | Close without committing |

The editing cursor stays in the query buffer while logical focus and selection
move between views. An asterisk marks the focused view; faces use theme-friendly
inheritance. No global keys are installed.

Without `:on-query`, whitespace-separated terms match labels literally,
case-insensitively and in any order. Supply `:on-query (lambda (session query)
...)` to own searching; publish results with `emacs-tui-update`. This initial
callback is synchronous. Avoid blocking work; cancellable async providers are
on the roadmap.

`:on-commit` receives `(session item origin-marker)` in the origin buffer at the
captured location. Successful callbacks close the workspace. An error rolls
back edits to that buffer and leaves the workspace open. Applications remain
responsible for transactions involving other buffers, files or external state.
Selection/query callbacks should only browse and update ephemeral views.

## Display backends

`:backend 'auto` uses native child frames when supported, with an ordinary
window fallback. Explicit choices are `child-frame` and `windows`. The first
backend uses one retained child frame containing split windows; the second
owns a split subtree and removes its own windows on exit. It does not restore a
stale snapshot over unrelated window changes.

The first implementation provides full-workspace columns, rows and grid. The
four-sided around-point layout, multiple floating surfaces, automatic resize
reflow, history, per-view queries, tables and async streaming are planned in
[ROADMAP.md](ROADMAP.md). The initial implementation renders full view content;
large-data performance is not yet characterized.

## Development and readiness

```sh
make check
make tty-smoke
```

ERT exercises real buffers/windows, filtering, selection, commit rollback,
cleanup and layout invariants. The terminal smoke test starts an actual Emacs
TTY in a pseudo-terminal, exercises typing/select/commit, and requires the
native child-frame backend when its capability is present. It is not a visual
quality or performance benchmark.

CI targets Emacs 28.2, 29.4, 30.2 and 31.1 with pinned actions. Read
[docs/STATE.md](docs/STATE.md) for what has actually passed and remaining gaps,
and [docs/MELPA.md](docs/MELPA.md) for external release gates.

GPL-3.0-or-later. AI assistance is disclosed in source headers. The public API
is experimental until documented release criteria are met.
