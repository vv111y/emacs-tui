;;; emacs-tui.el --- Ephemeral interactive workspaces -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; URL: https://github.com/vv111y/emacs-tui
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: convenience, terminals

;; This file is part of emacs-tui.
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Open an ephemeral workspace with `emacs-tui-open'.  Ordinary editing
;; commands edit its private query buffer.  Applications provide views
;; and callbacks; browsing never writes to the originating buffer.
;; `emacs-tui-commit' is the explicit persistence boundary.
;; Native child frames are used when supported, with owned windows as a
;; fallback.  The initial API is experimental.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'emacs-tui-layout)

(defgroup emacs-tui nil
  "Ephemeral interactive workspaces."
  :group 'convenience
  :prefix "emacs-tui-")

(defface emacs-tui-selection
  '((t :inherit highlight))
  "Face for the selected item."
  :group 'emacs-tui)

(defface emacs-tui-annotation
  '((t :inherit shadow))
  "Face for item annotations."
  :group 'emacs-tui)

(cl-defstruct (emacs-tui--view (:constructor emacs-tui--make-view))
  id title items visible-items (selected 0) text on-select buffer window)

(cl-defstruct (emacs-tui--workspace (:constructor emacs-tui--make-workspace))
  views (focus 0) layout backend on-query on-commit origin origin-window
  origin-frame frame query-buffer root windows active origin-kill-hook geometry)

(defvar-local emacs-tui--session nil
  "Workspace associated with the current ephemeral buffer.")

(defvar emacs-tui--sessions nil
  "Live workspaces, used to release resources when a frame is deleted.")

(defvar emacs-tui--refreshing nil
  "Non-nil while workspace geometry is being changed.")

(defvar emacs-tui-input-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'emacs-tui-next-view)
    (define-key map (kbd "<backtab>") #'emacs-tui-previous-view)
    (define-key map (kbd "M-n") #'emacs-tui-next-item)
    (define-key map (kbd "M-p") #'emacs-tui-previous-item)
    (define-key map (kbd "RET") #'emacs-tui-select)
    (define-key map (kbd "C-c C-c") #'emacs-tui-commit)
    (define-key map (kbd "C-c C-l") #'emacs-tui-cycle-layout)
    (define-key map (kbd "C-g") #'emacs-tui-close)
    (define-key map (kbd "C-c C-q") #'emacs-tui-close)
    map)
  "Keymap for query input; normal Emacs editing remains available.")

(define-derived-mode emacs-tui-input-mode text-mode "TUI-Query"
  "Edit the private query of an ephemeral workspace."
  (setq-local header-line-format
              " Query | TAB view | M-n/p item | RET select | C-c C-c commit | C-g close")
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t))

(define-derived-mode emacs-tui-view-mode special-mode "TUI-View"
  "Display an ephemeral workspace view."
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t)
  (setq-local cursor-type nil))

(defun emacs-tui--item-label (item)
  "Return the display label of ITEM."
  (if (stringp item) item (or (plist-get item :label) "")))

(defun emacs-tui--item-id (item)
  "Return the stable identity of ITEM."
  (if (stringp item) item (or (plist-get item :id) item)))

(defun emacs-tui--validate-items (items)
  "Validate ITEMS and return them."
  (unless (proper-list-p items)
    (error "Items must be a proper list"))
  (dolist (item items)
    (unless (or (stringp item)
                (and (proper-list-p item)
                     (stringp (plist-get item :label))))
      (error "Each item must be a string or a plist with a string :label")))
  items)

(cl-defun emacs-tui-view (&key id title items text on-select)
  "Describe an ephemeral view.
ID is a unique symbol or string.  TITLE defaults to ID.  ITEMS is a list
of strings or plists with :label, optional :id, :value and :annotation.
TEXT is a preview string and takes precedence over ITEMS when non-nil.
ON-SELECT is called with the workspace and selected item; it need not
close the workspace.  View descriptions are copied when opened."
  (unless (and id (or (symbolp id) (stringp id)))
    (error "View ID must be a non-nil symbol or string"))
  (unless (or (null text) (stringp text)) (error "TEXT must be a string"))
  (unless (or (null on-select) (functionp on-select))
    (error "ON-SELECT must be a function"))
  (emacs-tui--make-view :id id :title (or title (format "%s" id))
                        :items (emacs-tui--validate-items items)
                        :visible-items items :text text :on-select on-select))

(defun emacs-tui--require-session (session)
  "Return live SESSION, defaulting to the current buffer's workspace."
  (setq session (or session emacs-tui--session))
  (unless (and (emacs-tui--workspace-p session)
               (emacs-tui--workspace-active session))
    (user-error "No active emacs-tui workspace"))
  session)

(defun emacs-tui--focused-view (session)
  "Return the logically focused view of SESSION."
  (nth (emacs-tui--workspace-focus session)
       (emacs-tui--workspace-views session)))

(defun emacs-tui-current-item (&optional session)
  "Return the selected item in SESSION's focused view, or nil."
  (let ((view (emacs-tui--focused-view
               (emacs-tui--require-session session))))
    (when (and (not (emacs-tui--view-text view))
               (window-live-p (emacs-tui--view-window view)))
      (nth (emacs-tui--view-selected view)
           (emacs-tui--view-visible-items view)))))

(defun emacs-tui-query (&optional session)
  "Return the private query string of SESSION."
  (with-current-buffer
      (emacs-tui--workspace-query-buffer
       (emacs-tui--require-session session))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun emacs-tui--filter (session view)
  "Update VIEW's visible items for SESSION, preserving stable selection."
  (let* ((old (nth (emacs-tui--view-selected view)
                   (emacs-tui--view-visible-items view)))
         (terms (split-string (emacs-tui-query session) nil t))
         (case-fold-search t)
         (items
          (if (emacs-tui--workspace-on-query session)
              (emacs-tui--view-items view)
            (cl-remove-if-not
             (lambda (item)
               (cl-every
                (lambda (term)
                  (string-match-p (regexp-quote term)
                                  (emacs-tui--item-label item)))
                terms))
             (emacs-tui--view-items view)))))
    (setf (emacs-tui--view-visible-items view) items
          (emacs-tui--view-selected view)
          (or (and old (cl-position (emacs-tui--item-id old) items
                                   :key #'emacs-tui--item-id :test #'equal))
              0))))

(defun emacs-tui--render-view (session view)
  "Render VIEW in SESSION without replacing its buffer or window."
  (let ((buffer (emacs-tui--view-buffer view)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let ((inhibit-read-only t)
              (selected-position 1))
          (erase-buffer)
          (setq header-line-format
                (concat (if (eq view (emacs-tui--focused-view session))
                            "* " "  ")
                        (emacs-tui--view-title view)))
          (if (emacs-tui--view-text view)
              (insert (emacs-tui--view-text view))
            (cl-loop for item in (emacs-tui--view-visible-items view)
                     for index from 0 do
                     (let ((start (point))
                           (annotation (and (listp item)
                                            (plist-get item :annotation))))
                       (insert (emacs-tui--item-label item))
                       (when annotation
                         (insert "  " (propertize (format "%s" annotation)
                                                 'face 'emacs-tui-annotation)))
                       (insert "\n")
                       (when (= index (emacs-tui--view-selected view))
                         (setq selected-position start)
                         (add-face-text-property start (1- (point))
                                                 'emacs-tui-selection t)))))
          (goto-char selected-position)
          (set-buffer-modified-p nil)
          (when (window-live-p (emacs-tui--view-window view))
            (set-window-point (emacs-tui--view-window view) (point))))))))

(defun emacs-tui--query-changed (&rest arguments)
  "Refresh the workspace after a query edit.
ARGUMENTS come from `after-change-functions', or start with `initial'
to propagate initialization failures to the workspace opener."
  (let ((session emacs-tui--session))
    (when (and session (emacs-tui--workspace-active session))
      (when (emacs-tui--workspace-on-query session)
        (let ((query (emacs-tui-query session)))
          (if (eq (car arguments) 'initial)
              (funcall (emacs-tui--workspace-on-query session) session query)
            (condition-case err
                (funcall (emacs-tui--workspace-on-query session) session query)
              (error (message "emacs-tui query provider: %s"
                              (error-message-string err)))
              (quit (emacs-tui-close session))))))
      (when (emacs-tui--workspace-active session)
        (dolist (view (emacs-tui--workspace-views session))
          (emacs-tui--filter session view)
          (emacs-tui--render-view session view))))))

(cl-defun emacs-tui-update (session id &key (items nil items-p)
                                  (text nil text-p))
  "Update SESSION's view ID, reusing its display resources.
Supplying ITEMS, including nil, replaces its source items.  Supplying
TEXT, including nil, replaces or clears the preview.  Omitted fields
are unchanged.  Return SESSION."
  (emacs-tui--require-session session)
  (let ((view (cl-find id (emacs-tui--workspace-views session)
                       :key #'emacs-tui--view-id :test #'equal)))
    (unless view (error "Unknown view: %S" id))
    (when items-p (emacs-tui--validate-items items))
    (when (and text-p (not (or (null text) (stringp text))))
      (error "TEXT must be a string or nil"))
    (when items-p (setf (emacs-tui--view-items view) items))
    (when text-p (setf (emacs-tui--view-text view) text))
    (emacs-tui--filter session view)
    (emacs-tui--render-view session view))
  session)

(defun emacs-tui--child-frames-supported-p ()
  "Whether this display advertises native child-frame support."
  (and (not noninteractive)
       (or (display-graphic-p) (featurep 'tty-child-frames))))

(defun emacs-tui--fit-child (session)
  "Fit SESSION's existing child frame inside its live parent.
Dimensions are converted from parent inner pixels to child character
cells.  Actual dimensions are checked because a display may impose a
larger minimum frame size than the requested size."
  (let* ((parent (emacs-tui--workspace-origin-frame session))
         (child (emacs-tui--workspace-frame session))
         (width (frame-inner-width parent))
         (height (frame-inner-height parent))
         (cell-width (frame-char-width child))
         (cell-height (frame-char-height child))
         (left cell-width) (top cell-height)
         (columns (/ (- width (* 2 left)) cell-width))
         (rows (/ (- height (* 2 top)) cell-height)))
    (when (or (< columns 2) (< rows 3))
      (error "Parent frame is too small for the workspace"))
    (unless (and (= columns (frame-width child)) (= rows (frame-height child)))
      (let ((frame-resize-pixelwise t))
        (set-frame-size child columns rows)))
    (unless (and (equal left (frame-parameter child 'left))
                 (equal top (frame-parameter child 'top)))
      (set-frame-position child left top))
    (when (or (> (+ left (frame-pixel-width child)) width)
              (> (+ top (frame-pixel-height child)) height))
      (error "Display minimum child-frame size exceeds the parent viewport"))))

(defun emacs-tui--make-surface (session requested)
  "Create SESSION's owned display surface using REQUESTED backend."
  (unless (memq requested '(auto windows child-frame))
    (error "Unknown backend: %S" requested))
  (when (and (eq requested 'child-frame)
             (not (emacs-tui--child-frames-supported-p)))
    (user-error "Native child frames are unavailable on this display"))
  (when (and (not (eq requested 'windows))
             (emacs-tui--child-frames-supported-p))
    (condition-case err
        (let* ((parent (emacs-tui--workspace-origin-frame session))
               (width (max 1 (- (frame-width parent) 4)))
               (height (max 1 (- (frame-height parent) 4)))
               (frame
                (make-frame
                 `((parent-frame . ,parent)
                   (minibuffer . ,(minibuffer-window parent))
                   (left . 1) (top . 1) (width . ,width) (height . ,height)
                   (undecorated . t) (visibility . nil)
                   (menu-bar-lines . 0) (tool-bar-lines . 0)
                   (tab-bar-lines . 0) (internal-border-width . 0)
                   (left-fringe . 0) (right-fringe . 0)
                   (vertical-scroll-bars . nil) (horizontal-scroll-bars . nil)))))
          (setf (emacs-tui--workspace-frame session) frame
                (emacs-tui--workspace-root session) (frame-root-window frame)
                (emacs-tui--workspace-backend session) 'child-frame)
          (make-frame-visible frame)
          (emacs-tui--fit-child session))
      ((error quit)
       (let ((frame (emacs-tui--workspace-frame session)))
         (setf (emacs-tui--workspace-frame session) nil
               (emacs-tui--workspace-root session) nil
               (emacs-tui--workspace-backend session) nil)
         (when (frame-live-p frame) (delete-frame frame t)))
       (when (or (eq requested 'child-frame) (eq (car err) 'quit))
         (signal (car err) (cdr err))))))
  (unless (emacs-tui--workspace-root session)
    (let* ((origin (emacs-tui--workspace-origin-window session))
           (window-min-height 3)
           (height (window-total-height origin)))
      (when (< height 8)
        (user-error "Need at least eight window rows for an emacs-tui workspace"))
      (setf (emacs-tui--workspace-root session)
            (split-window origin (- (max 4 (/ height 2))) 'below)
            (emacs-tui--workspace-backend session) 'windows))))

(defun emacs-tui--split-rectangles (session root rectangles)
  "Display SESSION views in ROOT according to RECTANGLES."
  (let ((rows nil) (window-min-height 1) (window-min-width 2))
    (dolist (entry rectangles)
      (let* ((y (nth 1 (cdr entry))) (row (assoc y rows)))
        (if row (setcdr row (append (cdr row) (list entry)))
          (setq rows (append rows (list (list y entry)))))))
    (let ((remaining root))
      (cl-loop for row on rows do
               (let* ((entries (cdar row))
                      (row-window remaining))
                 (when (cdr row)
                   (setq remaining
                         (split-window row-window
                                       (nth 3 (cdar entries)) 'below))
                   (emacs-tui--own-window session remaining))
                 (cl-loop for cells on entries do
                          (let* ((entry (car cells))
                                 (view (cl-find (car entry)
                                                (emacs-tui--workspace-views session)
                                                :key #'emacs-tui--view-id
                                                :test #'equal))
                                 (cell row-window))
                            (when (cdr cells)
                              (setq row-window
                                    (split-window cell (nth 2 (cdr entry)) 'right))
                              (emacs-tui--own-window session row-window))
                            (setf (emacs-tui--view-window view) cell)
                            (set-window-buffer cell (emacs-tui--view-buffer view))
                            (emacs-tui--own-window session cell))))))))

(defun emacs-tui--own-window (session window)
  "Record WINDOW as an owned resource of SESSION."
  (set-window-parameter window 'emacs-tui-session session)
  (cl-pushnew window (emacs-tui--workspace-windows session)))

(defun emacs-tui--owned-window-p (session window)
  "Return non-nil if WINDOW belongs to SESSION with its content intact."
  (and (window-live-p window)
       (memq window (emacs-tui--workspace-windows session))
       (eq (window-parameter window 'emacs-tui-session) session)
       (eq (buffer-local-value 'emacs-tui--session (window-buffer window))
           session)))

(defun emacs-tui--window-descendant-p (window ancestor)
  "Whether WINDOW belongs to the subtree rooted at ANCESTOR."
  (while (and window (not (eq window ancestor)))
    (setq window (window-parent window)))
  (eq window ancestor))

(defun emacs-tui--subtree (session)
  "Return SESSION's complete owned subtree, or nil if invalidated.
A foreign window inside the subtree makes it unsuitable for reflow."
  (let* ((root (emacs-tui--workspace-root session))
         (windows (cl-remove-if-not #'window-live-p
                                    (emacs-tui--workspace-windows session)))
         (ancestor root))
    (when (and (window-live-p root)
               (window-live-p (emacs-tui--workspace-origin-window session))
               (frame-live-p (emacs-tui--workspace-origin-frame session))
               (buffer-live-p (marker-buffer (emacs-tui--workspace-origin session)))
               (eq (window-buffer root) (emacs-tui--workspace-query-buffer session))
               windows
               (cl-every (lambda (window) (emacs-tui--owned-window-p session window))
                         windows))
      (while (and ancestor
                  (not (cl-every
                        (lambda (window)
                          (emacs-tui--window-descendant-p window ancestor))
                        windows)))
        (setq ancestor (window-parent ancestor)))
      (when ancestor
        (let ((complete t))
          (walk-window-subtree
           (lambda (window)
             (unless (memq window windows) (setq complete nil))) ancestor)
          (and complete ancestor))))))

(defun emacs-tui--geometry (session)
  "Return SESSION's geometry signature, or nil for an invalid surface."
  (when-let ((subtree (emacs-tui--subtree session)))
    (list (window-edges subtree)
          (mapcar (lambda (window) (list window (window-edges window)))
                  (cl-remove-if-not #'window-live-p
                                    (emacs-tui--workspace-windows session)))
          (when-let ((child (emacs-tui--workspace-frame session)))
            (let ((parent (emacs-tui--workspace-origin-frame session)))
              (and (frame-live-p child)
                   (list (frame-inner-width parent) (frame-inner-height parent)
                         (frame-pixel-width child) (frame-pixel-height child)
                         (frame-char-width child) (frame-char-height child)
                         (frame-parameter child 'left) (frame-parameter child 'top))))))))

(defun emacs-tui--reveal-focus (session)
  "Ensure SESSION's logically focused view is visible when a panel exists."
  (let ((focused (emacs-tui--focused-view session)))
    (unless (window-live-p (emacs-tui--view-window focused))
      (let ((visible (cl-find-if
                      (lambda (view)
                        (window-live-p (emacs-tui--view-window view)))
                      (emacs-tui--workspace-views session))))
        (when visible
          (let ((window (emacs-tui--view-window visible)))
            (setf (emacs-tui--view-window visible) nil
                  (emacs-tui--view-window focused) window)
            (set-window-buffer window (emacs-tui--view-buffer focused))))))))

(defun emacs-tui--arrange (session)
  "Arrange SESSION's views inside its owned window subtree."
  (let ((root (emacs-tui--workspace-root session))
        (window-combination-limit t))
    (dolist (window (emacs-tui--workspace-windows session))
      (when (and (not (eq root window)) (window-live-p window)
                 (eq (window-parameter window 'emacs-tui-session) session))
        (delete-window window)))
    (dolist (view (emacs-tui--workspace-views session))
      (setf (emacs-tui--view-window view) nil))
    (setf (emacs-tui--workspace-windows session) (list root))
    (set-window-buffer root (emacs-tui--workspace-query-buffer session))
    (emacs-tui--own-window session root)
    (when (> (window-total-height root) 2)
      (let* ((window-min-height 1)
             (panel (split-window root 2 'below))
             (rectangles
              (emacs-tui-layout-compute
               (mapcar #'emacs-tui--view-id (emacs-tui--workspace-views session))
               (window-total-width panel) (window-total-height panel)
               (emacs-tui--workspace-layout session))))
        (emacs-tui--own-window session panel)
        (condition-case err
            (emacs-tui--split-rectangles session panel rectangles)
          (error
           (dolist (window (emacs-tui--workspace-windows session))
             (when (and (not (memq window (list root panel)))
                        (window-live-p window))
               (delete-window window)))
           (dolist (view (emacs-tui--workspace-views session))
             (setf (emacs-tui--view-window view) nil))
           (setf (emacs-tui--workspace-windows session) (list root panel))
           (when (window-live-p panel)
             (set-window-buffer panel (emacs-tui--view-buffer
                                       (car (emacs-tui--workspace-views session))))
             (setf (emacs-tui--view-window
                    (car (emacs-tui--workspace-views session))) panel)
             (cl-pushnew panel (emacs-tui--workspace-windows session)))
           (message "emacs-tui compact layout: %s" (error-message-string err))))))
    (emacs-tui--reveal-focus session)
    (dolist (view (emacs-tui--workspace-views session))
      (emacs-tui--render-view session view))))

(defun emacs-tui-refresh (&optional session)
  "Reflow SESSION safely, preserving its query and logical selection.
This is normally automatic after window or frame geometry changes.
Return SESSION on success, or nil after closing an invalidated surface.
No application provider or commit callback is invoked."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (unless emacs-tui--refreshing
    (let ((emacs-tui--refreshing t) complete)
      (unwind-protect
          (condition-case err
              (progn
                (unless (emacs-tui--subtree session)
                  (error "Workspace window subtree is no longer available"))
                (let* ((query (emacs-tui--workspace-query-buffer session))
                       (root (emacs-tui--workspace-root session))
                       (point (with-current-buffer query (point)))
                       (window-point (window-point root))
                       (scroll
                        (mapcar
                         (lambda (view)
                           (let ((window (emacs-tui--view-window view)))
                             (when (window-live-p window)
                               (list view (window-start window) (window-point window)
                                     (window-hscroll window)))))
                         (emacs-tui--workspace-views session))))
                  (save-selected-window
                    (when (emacs-tui--workspace-frame session)
                      (emacs-tui--fit-child session))
                    (emacs-tui--arrange session)
                    (with-current-buffer query (goto-char point))
                    (set-window-point root window-point)
                    (dolist (entry scroll)
                      (when entry
                        (let* ((view (car entry))
                               (window (emacs-tui--view-window view)))
                          (when (window-live-p window)
                            (set-window-start window (nth 1 entry) t)
                            (when (emacs-tui--view-text view)
                              (set-window-point window (nth 2 entry)))
                            (set-window-hscroll window (nth 3 entry))))))))
                (setf (emacs-tui--workspace-geometry session)
                      (emacs-tui--geometry session))
                (unless (emacs-tui--workspace-geometry session)
                  (error "Workspace window subtree was invalidated during reflow"))
                (setq complete t)
                session)
            (error (message "emacs-tui closed during reflow: %s"
                            (error-message-string err)) nil))
        (unless complete (emacs-tui-close session))))))

(defun emacs-tui--window-state-changed ()
  "Reflow live workspaces only when their cached geometry has changed."
  (unless emacs-tui--refreshing
    (dolist (session (copy-sequence emacs-tui--sessions))
      (when (emacs-tui--workspace-active session)
        (condition-case err
            (when (not (equal (emacs-tui--workspace-geometry session)
                              (emacs-tui--geometry session)))
              (emacs-tui-refresh session))
          (error
           (message "emacs-tui closed after window change: %s"
                    (error-message-string err))
           (emacs-tui-close session)))))))

(cl-defun emacs-tui-open (&key views (layout 'columns) (backend 'auto)
                              on-query on-commit)
  "Open an ephemeral workspace and return its session handle.
VIEWS is a nonempty list of `emacs-tui-view' descriptions.  LAYOUT is
`columns', `rows' or `grid'.  BACKEND is `auto', `windows' or
`child-frame'.  Auto uses native child frames when advertised and
falls back to owned ordinary windows if creation fails.

ON-QUERY, when non-nil, receives (SESSION QUERY) initially and after
query edits; it replaces built-in case-insensitive substring matching.
It can publish results with `emacs-tui-update'.  ON-COMMIT receives
 (SESSION ITEM ORIGIN-MARKER) in the live origin buffer in an atomic
change group.  Only a successful commit closes the workspace.

The query is editable scratch text; the source buffer and its point
are not modified by opening, filtering, selecting or cancelling."
  (unless (and (proper-list-p views) views
               (cl-every #'emacs-tui--view-p views))
    (error "VIEWS must be a nonempty list of emacs-tui-view descriptions"))
  (unless (memq layout '(columns rows grid)) (error "Unknown layout: %S" layout))
  (dolist (callback (list on-query on-commit))
    (unless (or (null callback) (functionp callback))
      (error "Callbacks must be functions or nil")))
  (let ((ids (mapcar #'emacs-tui--view-id views)))
    (unless (= (length ids) (length (delete-dups (copy-sequence ids))))
      (error "View IDs must be unique")))
  (let* ((session
          (emacs-tui--make-workspace
           :views (mapcar #'copy-emacs-tui--view views) :layout layout
           :on-query on-query :on-commit on-commit
           :origin (copy-marker (point)) :origin-window (selected-window)
           :origin-frame (selected-frame) :active t))
         (query (generate-new-buffer " *emacs-tui query*"))
         initialized)
    (setf (emacs-tui--workspace-query-buffer session) query)
    (unwind-protect
        (progn
          (with-current-buffer query
            (emacs-tui-input-mode)
            (setq-local emacs-tui--session session)
            (add-hook 'after-change-functions #'emacs-tui--query-changed nil t)
            (add-hook 'kill-buffer-hook #'emacs-tui--buffer-killed nil t))
          (dolist (view (emacs-tui--workspace-views session))
            (setf (emacs-tui--view-buffer view)
                  (generate-new-buffer (format " *emacs-tui %s*"
                                               (emacs-tui--view-id view)))
                  (emacs-tui--view-window view) nil)
            (with-current-buffer (emacs-tui--view-buffer view)
              (emacs-tui-view-mode)
              (setq-local emacs-tui--session session)
              (add-hook 'kill-buffer-hook #'emacs-tui--buffer-killed nil t)))
          (emacs-tui--make-surface session backend)
          (emacs-tui--arrange session)
          (setf (emacs-tui--workspace-geometry session) (emacs-tui--geometry session))
          (push session emacs-tui--sessions)
          (add-hook 'delete-frame-functions #'emacs-tui--frame-deleted)
          (add-hook 'window-state-change-hook #'emacs-tui--window-state-changed)
          (let ((hook (lambda () (emacs-tui-close session))))
            (setf (emacs-tui--workspace-origin-kill-hook session) hook)
            (with-current-buffer (marker-buffer (emacs-tui--workspace-origin session))
              (add-hook 'kill-buffer-hook hook nil t)))
          (select-window (emacs-tui--workspace-root session))
          (with-current-buffer query (emacs-tui--query-changed 'initial))
          (setq initialized t)
          session)
      (unless initialized (emacs-tui-close session)))))

(defun emacs-tui--buffer-killed ()
  "Close the workspace when an owned buffer is killed."
  (when (and emacs-tui--session
             (emacs-tui--workspace-active emacs-tui--session))
    (emacs-tui-close emacs-tui--session)))

(defun emacs-tui--frame-deleted (frame)
  "Release workspaces owned by deleted FRAME."
  (dolist (session (copy-sequence emacs-tui--sessions))
    (when (or (eq frame (emacs-tui--workspace-frame session))
              (eq frame (emacs-tui--workspace-origin-frame session)))
      (setf (emacs-tui--workspace-frame session) nil)
      (emacs-tui-close session))))

(defun emacs-tui-close (&optional session)
  "Close SESSION, discarding ephemeral state and releasing owned resources.
It is safe to close an already-closed session.  Source text and other
windows are preserved."
  (interactive)
  (setq session (or session emacs-tui--session))
  (when (and (emacs-tui--workspace-p session)
             (emacs-tui--workspace-active session))
    (setf (emacs-tui--workspace-active session) nil)
    (setq emacs-tui--sessions (delq session emacs-tui--sessions))
    (let* ((origin (emacs-tui--workspace-origin session))
           (origin-window (emacs-tui--workspace-origin-window session))
           (frame (emacs-tui--workspace-frame session))
           (owned-selection (emacs-tui--owned-window-p session (selected-window))))
      (when (buffer-live-p (marker-buffer origin))
        (with-current-buffer (marker-buffer origin)
          (remove-hook 'kill-buffer-hook
                       (emacs-tui--workspace-origin-kill-hook session) t)))
      (when (and owned-selection (window-live-p origin-window))
        (select-window origin-window))
      (if (and (frame-live-p frame)
               (or (null (emacs-tui--workspace-windows session))
                   (cl-every (lambda (window)
                               (emacs-tui--owned-window-p session window))
                             (window-list frame 'no-minibuffer))))
          (delete-frame frame t)
        (dolist (window (emacs-tui--workspace-windows session))
          (when (and (window-live-p window)
                     (eq (window-parameter window 'emacs-tui-session) session))
            (let ((owned (emacs-tui--owned-window-p session window)))
              (set-window-parameter window 'emacs-tui-session nil)
              (when owned
                (if (not (one-window-p t (window-frame window)))
                    (delete-window window)
                  (when (buffer-live-p (marker-buffer origin))
                    (set-window-buffer window (marker-buffer origin))
                    (set-window-point window origin))))))))
      (dolist (buffer (cons (emacs-tui--workspace-query-buffer session)
                           (mapcar #'emacs-tui--view-buffer
                                   (emacs-tui--workspace-views session))))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer)))
      (set-marker origin nil))
    (unless emacs-tui--sessions
      (remove-hook 'delete-frame-functions #'emacs-tui--frame-deleted)
      (remove-hook 'window-state-change-hook #'emacs-tui--window-state-changed)))
  nil)

(defun emacs-tui-next-view (&optional session delta)
  "Move SESSION's logical view focus by DELTA, defaulting to one."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (setf (emacs-tui--workspace-focus session)
        (mod (+ (emacs-tui--workspace-focus session) (or delta 1))
             (length (emacs-tui--workspace-views session))))
  (emacs-tui--reveal-focus session)
  (dolist (view (emacs-tui--workspace-views session))
    (emacs-tui--render-view session view)))

(defun emacs-tui-previous-view (&optional session)
  "Move SESSION's logical view focus backward."
  (interactive)
  (emacs-tui-next-view session -1))

(defun emacs-tui-next-item (&optional session delta)
  "Move SESSION's focused selection by DELTA, defaulting to one."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (count (length (emacs-tui--view-visible-items view))))
    (when (> count 0)
      (setf (emacs-tui--view-selected view)
            (mod (+ (emacs-tui--view-selected view) (or delta 1)) count))
      (emacs-tui--render-view session view))))

(defun emacs-tui-previous-item (&optional session)
  "Move SESSION's focused selection backward."
  (interactive)
  (emacs-tui-next-item session -1))

(defun emacs-tui-select (&optional session)
  "Invoke the focused view's selection action in SESSION.
Selection is separate from commitment and does not close the workspace."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (item (emacs-tui-current-item session))
         (action (emacs-tui--view-on-select view)))
    (unless item (user-error "No selected item"))
    (when action (funcall action session item))
    item))

(defun emacs-tui-commit (&optional session)
  "Run SESSION's explicit commit callback, then close on success.
Errors in a callback roll back its edits to the origin buffer and leave
the workspace open.  Applications own all persistence semantics."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let ((callback (emacs-tui--workspace-on-commit session))
        (origin (emacs-tui--workspace-origin session))
        (item (emacs-tui-current-item session)))
    (unless callback (user-error "This workspace has no commit action"))
    (unless item (user-error "No selected item"))
    (unless (buffer-live-p (marker-buffer origin))
      (user-error "The origin buffer no longer exists"))
    (with-current-buffer (marker-buffer origin)
      (save-excursion
        (goto-char origin)
        (atomic-change-group (funcall callback session item origin))))
    (emacs-tui-close session)))

(defun emacs-tui-cycle-layout (&optional session)
  "Cycle SESSION between columns, rows and grid layouts."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (setf (emacs-tui--workspace-layout session)
        (pcase (emacs-tui--workspace-layout session)
          ('columns 'rows) ('rows 'grid) (_ 'columns)))
  (emacs-tui-refresh session))

(provide 'emacs-tui)
;;; emacs-tui.el ends here
