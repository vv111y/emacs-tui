;;; emacs-tui-reader-demo.el --- Hierarchical field guide reader -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; A self-contained document reader: chapter tree and a wrapped reading pane.
;; Search reveals ancestor paths, while clearing it restores expansion state.
;; No buffer inventory, external documents, application timers or data writes.

;;; Code:
(require 'emacs-tui)

(defconst emacs-tui-reader-demo--chapters
  '((:id welcome :label "Welcome to the field guide"
     :body "This small book is a working tree-and-text application. The left pane is a table of contents; the right pane is a document, not a buffer preview.\n\nExpand a chapter with SPC, choose a section and press RET. TAB moves to the reading pane, where ordinary Emacs scrolling works. C-c C-f maximizes a long page.\n\nPress / in the contents and search for Compass. The tree reveals the matching path without changing your saved expansion state. Press / again and accept an empty query to restore it.\n\nThere are no external documents to install and nothing is saved when this reader closes.")
    (:id navigation :label "1. Navigation"
     :body "Navigation connects a reader's current position to a larger structure. Expand this chapter to read the map and compass sections.\n\nThe contents are a finite tree with stable section identities. Expanding and collapsing changes presentation only. Selecting a section explicitly updates the document pane."
     :children
     ((:id maps :label "Maps and landmarks"
       :body "A map is useful because it omits detail. Start by locating a few landmarks, then connect them with routes you can actually follow.\n\nIn a text interface, a contents tree plays the same role. The chapter hierarchy gives context without requiring every page to be visible at once.\n\nTry C-c + to expand all chapters, then C-c - to collapse them. Return to this page: its text remains available independently of the outline's expansion.")
      (:id compass :label "Compass and bearings"
       :body "A compass supplies direction; a map supplies context. Using both makes a route easier to explain and recover.\n\nSearch the contents for Compass. Matching paths include ancestor chapters, so the result retains its context. Clear the search to return to your earlier tree expansion.\n\nThe reader's / binding belongs to the contents pane. The document pane keeps ordinary Emacs search, scrolling and help commands.")))
    (:id camp :label "2. Making camp"
     :body "A comfortable camp has a clear layout, a dry place to rest, and a plan for leaving it clean. Expand this chapter for the checklist and evening log."
     :children
     ((:id checklist :label "Camp checklist"
       :body "Before stopping\n\n[ ] Find level ground.\n[ ] Check the weather and nearby water.\n[ ] Keep the walking route clear.\n[ ] Prepare a light before sunset.\n[ ] Leave the site as you found it.\n\nThese are document text, not interactive checkbox controls. The toolkit supplies the tree, text, focus, layout and reading state; applications decide what actions a document supports.")
      (:id journal :label "Evening log — 日本語 / café"
       :body "Day 3\n\nThe trail narrowed after the ridge. We reached the lake before the rain and watched the hills disappear behind it.\n\nA small café appeared on yesterday's map; tomorrow we will see whether it is still there.\n\n日本語 and combining text é share native Emacs text buffers. Their physical appearance depends on the terminal and font. Try resizing while reading, or maximize this page and restore it.\n\nReading, searching and changing layouts do not alter the guide."))))
  "Sample book with immutable section text and nested chapter identities.")

(defun emacs-tui-reader-demo--read (app item)
  "Display section ITEM as formatted text in APP's reading pane."
  (emacs-tui-update app 'page
                    :text (concat (propertize (plist-get item :label) 'face 'bold)
                                  "\n\n" (plist-get item :body))))

(defun emacs-tui-reader-demo--search ()
  "Filter the current reader's contents using native minibuffer input."
  (interactive)
  (let* ((app (emacs-tui-current-session))
         (query (read-string "Section (empty clears): " (emacs-tui-query app 'contents))))
    (emacs-tui-set-query app 'contents query)))

;;;###autoload
(defun emacs-tui-reader-demo ()
  "Read a sample book using a chapter tree and wrapped document pane.
In the contents, SPC expands a chapter, RET reads, and / searches section
titles.  `emacs-tui-tree-expand-all' and `emacs-tui-tree-collapse-all' act on
all chapters.  TAB reaches the reading pane; ordinary scrolling and
`emacs-tui-toggle-maximize' retain reading position."
  (interactive)
  (let ((map (make-sparse-keymap)) app ready)
    (define-key map (kbd "/") #'emacs-tui-reader-demo--search)
    (unwind-protect
        (progn
          (setq app
                (emacs-tui-mount
                 :backend 'auto :layout 'columns
                 :views
                 (list (emacs-tui-tree
                        :id 'contents :title "Contents | SPC open | / find"
                        :items emacs-tui-reader-demo--chapters :keymap map
                        :on-select #'emacs-tui-reader-demo--read)
                       (emacs-tui-view :id 'page :title "Page | TAB read | C-c C-f maximize"
                                       :text ""))))
          (emacs-tui-focus-view app 'page)
          (setq-local truncate-lines nil truncate-partial-width-windows nil word-wrap t)
          (emacs-tui-focus-view app 'contents)
          (emacs-tui-reader-demo--read app (car emacs-tui-reader-demo--chapters))
          (setq ready t)
          app)
      (unless ready (when app (emacs-tui-close app))))))

(provide 'emacs-tui-reader-demo)
;;; emacs-tui-reader-demo.el ends here
