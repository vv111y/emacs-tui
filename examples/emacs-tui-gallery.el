;;; emacs-tui-gallery.el --- Launch the example collection -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6-astra-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Run make gallery from a checkout, or load this file and run
;; M-x emacs-tui-gallery.  RET shows a tour; C-c C-o launches the selected demo.
;; The gallery closes before launch, returning control to its original host.
;; Examples stay outside the runtime package and load only when selected.

;;; Code:
(require 'emacs-tui)

(defconst emacs-tui-gallery--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the gallery and its sibling examples.")

(defconst emacs-tui-gallery--entries
  '((:id catalog :label "Object catalog" :kind "Persistent"
     :feature emacs-tui-catalog-demo :command emacs-tui-catalog-demo
     :tour "Search, responsive tables, numeric sort, marks and batch actions.\n\n1. Type Note, then TAB to the table.\n2. C-c * marks all matching notes. Search Map instead.\n3. In the table, a -> Collect acts on the hidden marked notes.\n4. C-c C-u clears marks; RET inspects a map without collecting it.\n5. s chooses a sort column; C-u s sorts descending.\n\nCollection data stays in this session. Nothing is saved.")
    (:id layout :label "Layout playground" :kind "Persistent"
     :feature emacs-tui-layout-demo :command emacs-tui-layout-demo
     :tour "Layout choice, trees, native editing, Unicode and formatted previews.\n\n1. RET on Columns, Rows or Grid changes layout.\n2. C-c e focuses the editor. Type, paste or undo normally.\n3. C-c C-f maximizes; TAB visits hidden panels.\n4. Restore, expand tree branches with SPC and mark with C-c C-m.\n5. Resize your terminal; input and marks survive.\n\nScratch text is discarded on close.")
    (:id stream :label "Streaming job search" :kind "Ephemeral"
     :feature emacs-tui-stream-demo :command emacs-tui-stream-demo
     :tour "Debounced providers, streaming replacements, cancellation and errors.\n\n1. Watch 60 synthetic records arrive in batches.\n2. Type build, then quickly change to test while results arrive.\n3. RET inspects; source buffers are never changed.\n4. Enter !error to fail after 15 records; partial results remain.\n5. Clear the query to recover. Close during a stream to cancel it.\n\nNo processes or network requests; timings are demonstration delays.")
    (:id graph :label "Graph explorer (original)" :kind "Ephemeral"
     :feature emacs-tui-demo :command emacs-tui-demo
     :tour "Forward/backlinks, exploration history and explicit origin commitment.\n\n1. RET inspects a node; TAB visits preview, links and backlinks.\n2. Follow a link with RET; a offers Back and Forward.\n3. Mark nodes with C-c C-m, or mark all with C-c *.\n4. C-c C-c inserts demo links into the original buffer and closes.\n5. C-c C-q cancels without changing the original buffer.\n\nLaunch from a writable scratch buffer if testing commit. No XOB data is read.")
    (:id dashboard :label "Live buffer/process dashboard" :kind "Persistent"
     :feature emacs-tui-dashboard :command emacs-tui-dashboard
     :tour "Live snapshots, tables, preview, actions and application timer cleanup.\n\n1. RET previews a buffer or process.\n2. s sorts a table; P pauses/resumes updates; g refreshes.\n3. The Actions pane chooses layouts without restarting updates.\n4. A process action can inspect its associated buffer.\n\nUses your live Emacs objects. Does not start or kill processes or edit buffers.")
    (:id tree :label "Buffer tree" :kind "Persistent"
     :feature emacs-tui-buffer-tree :command emacs-tui-buffer-tree
     :tour "Hierarchical objects, expansion, hidden marks and context actions.\n\n1. SPC or right expands a mode group; left collapses it.\n2. C-c + expands all; C-c - collapses all.\n3. Mark children, collapse the group and use a for batch actions.\n4. RET previews; o explicitly displays a buffer; g refreshes.\n\nCopy names writes to the kill ring only when explicitly requested.")
    (:id composer :label "Text composer" :kind "Persistent"
     :feature emacs-tui-composer :command emacs-tui-composer
     :tour "Two native editable fields, multiline text and a live composition.\n\n1. Edit the prefix, then TAB to edit the body.\n2. RET inserts newlines; ordinary undo remains available.\n3. Watch the preview update.\n4. C-c C-c explicitly copies the composition to the kill ring.\n5. C-c C-q closes without saving the scratch fields.")
    (:id panel :label "Borrowed-window buffer panel" :kind "Embedded"
     :feature emacs-tui-buffer-panel :command emacs-tui-buffer-panel
     :tour "An embedded panel in an application-owned window.\n\n1. Observe the original buffer and cursor before launch.\n2. RET displays a selected buffer elsewhere.\n3. q closes the panel and restores its host buffer and position.\n\nThe host window survives. No source text is modified.")
    (:id filter :label "Search your buffers" :kind "Persistent"
     :feature emacs-tui-filter-demo :command emacs-tui-filter-demo
     :tour "Per-view local filtering composed with an input and sortable table.\n\n1. Type buffer-name or mode terms in the input.\n2. TAB to results; mark with C-c C-m and inspect with RET.\n3. Change the query, then clear it: hidden marks survive.\n4. C-c C-r refreshes snapshots while retaining the filter.\n\nReads your live buffers; preview is bounded and read-only.")
    (:id async :label "Chunked buffer search" :kind "Ephemeral"
     :feature emacs-tui-async-demo :command emacs-tui-async-demo
     :tour "A practical cancellable provider over captured buffer excerpts.\n\n1. Search a name or text from a buffer's first 1024 characters.\n2. RET previews the captured excerpt.\n3. Change the query to cancel and supersede the request.\n4. C-c C-q closes without modifying source buffers.\n\nSnapshots are captured synchronously; search processes 16 per timer tick.\nFor a visible stream in a fresh Emacs, try Streaming job search instead."))
  "Demo metadata and short interactive tours.")

(defun emacs-tui-gallery--describe (app item)
  "Display the selected demo ITEM's tour in APP."
  (emacs-tui-update app 'tour :text
                    (concat (propertize (plist-get item :label) 'face 'bold)
                            "\n\n" (plist-get item :tour)
                            "\n\nC-c C-o launches this demo; the gallery closes first.\n"
                            "Run M-x emacs-tui-gallery again to choose another.")))

(defun emacs-tui-gallery-launch ()
  "Close the gallery and launch its selected example in the restored host."
  (interactive)
  (let* ((app (emacs-tui-current-session))
         (item (emacs-tui-current-item app 'demos))
         (feature (plist-get item :feature))
         (command (plist-get item :command)))
    (unless item (user-error "Choose a demo first"))
    (require feature (expand-file-name (concat (symbol-name feature) ".el")
                                      emacs-tui-gallery--directory))
    (unless (commandp command) (user-error "Example command is unavailable"))
    (emacs-tui-close app)
    (funcall command)))

;;;###autoload
(defun emacs-tui-gallery ()
  "Browse all examples, read their tours, and explicitly launch one.
Use `emacs-tui-select' to describe an example and `emacs-tui-gallery-launch'
to launch it after closing the gallery.  Run this command again to return.
Use `emacs-tui-close' to exit without launching."
  (interactive)
  (let ((map (make-sparse-keymap)) app ready)
    (define-key map (kbd "C-c C-o") #'emacs-tui-gallery-launch)
    (unwind-protect
        (progn
          (setq app
                (emacs-tui-mount
                 :layout 'columns :keymap map
                 :views
                 (list (emacs-tui-view
                        :id 'demos :title "Demo gallery | RET tour | C-c C-o launch"
                        :items emacs-tui-gallery--entries
                        :on-select #'emacs-tui-gallery--describe)
                       (emacs-tui-view :id 'tour :title "Tour | TAB to read | C-c C-o launch"
                                       :text ""))))
          ;; Native buffer-local wrapping keeps tours readable after resize.
          (emacs-tui-focus-view app 'tour)
          (setq-local truncate-lines nil word-wrap t)
          (emacs-tui-focus-view app 'demos)
          (emacs-tui-gallery--describe app (car emacs-tui-gallery--entries))
          (setq ready t)
          app)
      (unless ready (when app (emacs-tui-close app))))))

(provide 'emacs-tui-gallery)
;;; emacs-tui-gallery.el ends here
