;;; emacs-tui-gallery.el --- Launch the example collection -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6-astra-wm
;; Assisted-by: Codex:gpt-6.1-sol-wm
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
  '((:id popup :label "Inline candidate popup (8 positions)" :kind "Inline"
     :available emacs-tui-popup-supported-p
     :feature emacs-tui-popup-demo :command emacs-tui-popup-demo
     :tour "Candidates float around the word being typed. The source stays in place.\n\n1. Launch to enable the demo in your original buffer. Type map.\n2. M-n / M-p selects; TAB explicitly replaces the word.\n3. C-c C-p cycles N, NE, E, SE, S, SW, W and NW.\n4. Keep typing to filter candidates; normal undo still works.\n5. C-g dismisses; C-c C-q disables the demo and restores bindings.\n\nNative TTY child frames (feature tty-child-frames) or a graphical display are required. Near edges placement is clamped. make popup-demo opens a centered sample document instead.")
    (:id inspector :label "Equipment inspector (floating text)" :kind "Inline"
     :available emacs-tui-popup-supported-p
     :feature emacs-tui-inspector-demo :command emacs-tui-inspector-demo
     :tour "Inspect application objects referenced by an editable document. No completion table.\n\n1. Launch a disposable equipment note with the pump inspector open.\n2. M-n / M-p scroll its details while source typing focus stays put.\n3. C-c C-p moves the preview around the reference.\n4. C-c C-a toggles acknowledgement without closing or editing the source.\n5. C-g dismisses. Place point on valve and run M-x emacs-tui-inspector-demo-at-point.\n\nAcknowledgements are private to this source buffer, survive popup dismissal and disappear when it is killed. No external equipment or files are touched. Native child frames are required.")
    (:id board :label "Task board" :kind "Persistent"
     :feature emacs-tui-board-demo :command emacs-tui-board-demo
     :tour "Three independent task lanes. No search field or preview pane.\n\n1. > moves the selected task forward and follows it to the next lane.\n2. < moves it back. TAB switches lanes without changing tasks.\n3. C-c C-m marks several tasks; > or a moves the marked batch.\n4. Inspect the counts in each lane; completed tasks stay visible.\n5. Close and reopen: each board has its own fresh task state.\n\nSession memory only. No project files or Emacs buffers are changed.")
    (:id catalog :label "Object catalog" :kind "Persistent"
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
    (:id composer :label "Text composer" :kind "Persistent"
     :feature emacs-tui-composer :command emacs-tui-composer
     :tour "Two native editable fields, multiline text and a live composition.\n\n1. Edit the prefix, then TAB to edit the body.\n2. RET inserts newlines; ordinary undo remains available.\n3. Watch the preview update.\n4. C-c C-c explicitly copies the composition to the kill ring.\n5. C-c C-q closes without saving the scratch fields.")
    (:id reader :label "Field guide reader" :kind "Persistent"
     :feature emacs-tui-reader-demo :command emacs-tui-reader-demo
     :tour "A book, with a chapter tree and a wrapped reading pane. No buffer inventory.\n\n1. SPC expands Navigation; select Compass and press RET to read.\n2. / searches section titles and reveals ancestor paths.\n3. / with an empty query restores the previous expansion.\n4. TAB reaches the page: scroll, maximize and resize while reading.\n5. C-c + and C-c - expand/collapse all chapters.\n\nSelf-contained sample text. Nothing is edited or saved.")
    (:id snippet :label "Embedded snippet picker" :kind "Embedded"
     :feature emacs-tui-snippet-demo :command emacs-tui-snippet-demo
     :tour "A single borrowed-window palette with explicit text insertion.\n\n1. Launch from a writable scratch buffer at the insertion point.\n2. The palette replaces that window's display; the host buffer survives.\n3. RET inserts the chosen literal snippet and restores the host.\n4. Undo normally in the host to reverse insertion.\n5. Launch again and q cancels with no edit.\n\nNo clipboard or file writes. A read-only host rejects insertion."))
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
    (when (and (plist-get item :available)
               (not (funcall (plist-get item :available))))
      (user-error "This demo requires graphical or native TTY child frames"))
    (require feature (expand-file-name (concat (symbol-name feature) ".el")
                                      emacs-tui-gallery--directory))
    (unless (commandp command) (user-error "Example command is unavailable"))
    (emacs-tui-close app)
    (funcall command)))

;;;###autoload
(defun emacs-tui-gallery ()
  "Browse distinct showcase applications and explicitly launch one.
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
                        :id 'demos :title "Demos | RET tour | C-c C-o launch"
                        :items emacs-tui-gallery--entries
                        :on-select #'emacs-tui-gallery--describe)
                       (emacs-tui-view :id 'tour :title "Tour | TAB to read | C-c C-o launch"
                                       :text ""))))
          ;; Native buffer-local wrapping keeps tours readable after resize.
          (emacs-tui-focus-view app 'tour)
          (setq-local truncate-lines nil truncate-partial-width-windows nil word-wrap t)
          (emacs-tui-focus-view app 'demos)
          (emacs-tui-gallery--describe app (car emacs-tui-gallery--entries))
          (setq ready t)
          app)
      (unless ready (when app (emacs-tui-close app))))))

(provide 'emacs-tui-gallery)
;;; emacs-tui-gallery.el ends here
