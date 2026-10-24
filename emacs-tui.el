;;; emacs-tui.el --- Composable text interfaces -*- lexical-binding: t; -*-

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

;; Mount a persistent interface with `emacs-tui-mount', or open an
;; ephemeral workspace with `emacs-tui-open'.  Ordinary editing
;; commands edit its private query buffer.  Applications provide views
;; and callbacks.  Persistent applications own their actions and data;
;; ephemeral workspaces use `emacs-tui-commit' for explicit persistence.
;; Native child frames are used when supported, with owned windows as a
;; fallback.  The initial API is experimental.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'emacs-tui-layout)
(require 'emacs-tui-table)
(require 'emacs-tui-tree)

(defgroup emacs-tui nil
  "Composable text interfaces."
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
  id title items visible-items (selected 0) text on-select buffer window
  multi-select marks keymap columns sort-column sort-descending editable on-change
  tree children tree-open tree-search display-state)

(cl-defstruct (emacs-tui--workspace (:constructor emacs-tui--make-workspace))
  views (focus 0) layout backend on-query on-commit origin origin-window
  origin-frame frame query-buffer root windows active origin-kill-hook geometry
  provider debounce request provider-views on-close host maximized)

(cl-defstruct (emacs-tui--host (:constructor emacs-tui--make-host))
  window buffer point start hscroll vscroll)

(cl-defstruct (emacs-tui--request (:constructor emacs-tui--make-request))
  session query timer cancel (active t))

(defvar-local emacs-tui--session nil
  "Interface associated with the current view or input buffer.")

(defvar emacs-tui--sessions nil
  "Live workspaces, used to release resources when a frame is deleted.")

(defvar emacs-tui--refreshing nil
  "Non-nil while workspace geometry is being changed.")

(defvar emacs-tui--rendering nil
  "Non-nil while rendering, suppressing editable-view change callbacks.")

(defvar emacs-tui-input-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'emacs-tui-next-view)
    (define-key map (kbd "<backtab>") #'emacs-tui-previous-view)
    (define-key map (kbd "M-n") #'emacs-tui-next-item)
    (define-key map (kbd "M-p") #'emacs-tui-previous-item)
    (define-key map (kbd "RET") #'emacs-tui-select)
    (define-key map (kbd "C-c C-c") #'emacs-tui-commit)
    (define-key map (kbd "C-c C-m") #'emacs-tui-toggle-mark)
    (define-key map (kbd "C-c C-u") #'emacs-tui-clear-marks)
    (define-key map (kbd "C-c C-l") #'emacs-tui-cycle-layout)
    (define-key map (kbd "C-c C-f") #'emacs-tui-toggle-maximize)
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

(defvar emacs-tui-view-mode-map
  (let ((map (copy-keymap emacs-tui-input-mode-map)))
    (define-key map (kbd "n") #'emacs-tui-next-item)
    (define-key map (kbd "p") #'emacs-tui-previous-item)
    (define-key map (kbd "q") #'emacs-tui-close)
    (define-key map (kbd "s") #'emacs-tui-sort)
    map)
  "Keymap for list and text views, including queryless applications.")

(define-derived-mode emacs-tui-view-mode special-mode "TUI-View"
  "Display a text interface view."
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t)
  (setq-local cursor-type nil))

(defvar emacs-tui-tree-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "SPC") #'emacs-tui-tree-toggle)
    (define-key map (kbd "<right>") #'emacs-tui-tree-expand)
    (define-key map (kbd "<left>") #'emacs-tui-tree-collapse)
    map)
  "Tree navigation bindings, inheriting ordinary view commands.")

(define-derived-mode emacs-tui-tree-mode emacs-tui-view-mode "TUI-Tree"
  "Browse a tree using identity-preserving expansion and selection.")

(defvar emacs-tui-field-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'emacs-tui-next-view)
    (define-key map (kbd "<backtab>") #'emacs-tui-previous-view)
    (define-key map (kbd "C-c C-q") #'emacs-tui-close)
    (define-key map (kbd "C-c C-l") #'emacs-tui-cycle-layout)
    (define-key map (kbd "C-c C-f") #'emacs-tui-toggle-maximize)
    map)
  "Keymap for editable views; ordinary text editing remains available.")

(define-derived-mode emacs-tui-field-mode text-mode "TUI-Input"
  "Edit an application's scratch input with native Emacs editing and undo."
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t)
  (buffer-enable-undo))

(defun emacs-tui--item-label (item)
  "Return the display label of ITEM."
  (if (stringp item) item (or (plist-get item :label) "")))

(defun emacs-tui--item-id (item)
  "Return the stable identity of ITEM."
  (if (stringp item) item (or (plist-get item :id) item)))

(defun emacs-tui--validate-items (items &optional unique)
  "Validate ITEMS and return them, requiring distinct identities if UNIQUE."
  (unless (proper-list-p items)
    (error "Items must be a proper list"))
  (dolist (item items)
    (unless (or (stringp item)
                (and (proper-list-p item)
                     (stringp (plist-get item :label))))
      (error "Each item must be a string or a plist with a string :label")))
  (when unique
    (let ((identities (make-hash-table :test #'equal)))
      (dolist (item items)
        (let ((id (emacs-tui--item-id item)))
          (when (gethash id identities)
            (error "Multi-select item identities must be unique: %S" id))
          (puthash id t identities)))))
  items)

(cl-defun emacs-tui-view (&key id title items text on-select multi-select keymap columns)
  "Describe a list, table or text view.
ID is a unique symbol or string.  TITLE defaults to ID.  ITEMS is a list
of strings or plists with :label, optional :id, :value and :annotation.
TEXT is a preview string and takes precedence over ITEMS when non-nil.
COLUMNS is an optional list of `emacs-tui-column' descriptions; it displays
the same source items as table rows.  Local queries search all column values
as well as the item label.  Use `emacs-tui-sort' to order visible rows.
Non-nil MULTI-SELECT enables independent marks.  Item identities must
then be unique under `equal': strings identify themselves, plists use
their non-nil :id or otherwise the entire plist.  Use stable :id values
to retain marks when labels or payloads change.  Text previews cannot
be marked.
ON-SELECT is called with the workspace and selected item; it need not
close the workspace.  KEYMAP optionally overrides application and default
view bindings.  Maps are composed without mutation and remain live references.
View descriptions are copied when opened."
  (unless (and id (or (symbolp id) (stringp id)))
    (error "View ID must be a non-nil symbol or string"))
  (unless (or (null text) (stringp text)) (error "TEXT must be a string"))
  (unless (or (null on-select) (functionp on-select))
    (error "ON-SELECT must be a function"))
  (unless (or (null keymap) (keymapp keymap))
    (error "KEYMAP must be a keymap or nil"))
  (emacs-tui--validate-columns columns)
  (emacs-tui--make-view :id id :title (or title (format "%s" id))
                        :items (emacs-tui--validate-items items multi-select)
                        :visible-items items :text text :on-select on-select
                        :multi-select multi-select :keymap keymap :columns columns))

(cl-defun emacs-tui-tree (&key id title items (children :children)
                               on-select multi-select keymap)
  "Describe a finite tree of application ITEMS with view ID and TITLE.
CHILDREN is a plist keyword or pure function returning an item's child list.
It is evaluated once per node during construction and source replacement,
never during rendering or expansion.  Return promptly; load data in the
application or use an asynchronous provider to publish complete snapshots.
Items follow `emacs-tui-view'; plist nodes require explicit non-nil :id values.
Identities must be globally unique, including collapsed descendants.  Cycles
and repeated nodes are rejected.  Roots start collapsed.  Source updates
retain expansion, selection and marks for surviving identities.
ON-SELECT, MULTI-SELECT and KEYMAP follow `emacs-tui-view'.  Selection/actions
receive the original item.  Local queries show matches and their ancestors
without changing expansion; clear the query before changing expansion."
  (unless (or (keywordp children) (functionp children))
    (error "CHILDREN must be a keyword or function"))
  (let* ((data (emacs-tui--tree-index items children))
         (projection (emacs-tui--tree-project data nil))
         (view (emacs-tui-view :id id :title title
                               :items (emacs-tui--tree-data-items data)
                               :on-select on-select :multi-select multi-select :keymap keymap)))
    (setf (emacs-tui--view-tree view) data
          (emacs-tui--view-visible-items view) (car projection)
          (emacs-tui--view-tree-open view) (cdr projection)
          (emacs-tui--view-children view) children)
    view))

(defun emacs-tui--tree-command (session operation)
  "Apply tree OPERATION in SESSION, staging state before rendering."
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (data (emacs-tui--view-tree view))
         (item (emacs-tui-current-item session)))
    (unless data (user-error "This view is not a tree"))
    (when (emacs-tui--view-tree-search view)
      (user-error "Clear the local query before changing tree expansion"))
    (when item
      (let* ((id (emacs-tui--item-id item))
             (children (gethash id (emacs-tui--tree-data-children data)))
             (expanded (gethash id (emacs-tui--tree-data-expanded data)))
             (candidate (copy-emacs-tui--view view))
             (next-data (copy-emacs-tui--tree-data data)) target)
        (setf (emacs-tui--tree-data-expanded next-data)
              (copy-hash-table (emacs-tui--tree-data-expanded data))
              (emacs-tui--view-tree candidate) next-data)
        (cond
         ((and (eq operation 'expand) expanded) (setq target (car children)))
         ((and (eq operation 'collapse) (not expanded))
          (setq target (gethash id (emacs-tui--tree-data-parents data))))
         ((and children (or (eq operation 'collapse)
                            (and (eq operation 'toggle) expanded)))
          (remhash id (emacs-tui--tree-data-expanded next-data)))
         (children (puthash id t (emacs-tui--tree-data-expanded next-data))))
        (emacs-tui--filter session candidate)
        (when target
          (setf (emacs-tui--view-selected candidate)
                (or (cl-position target (emacs-tui--view-visible-items candidate)
                                 :key #'emacs-tui--item-id :test #'equal) 0)))
        (emacs-tui--render-view session candidate)
        (setf (emacs-tui--view-tree view) next-data
              (emacs-tui--view-tree-open view) (emacs-tui--view-tree-open candidate)
              (emacs-tui--view-visible-items view) (emacs-tui--view-visible-items candidate)
              (emacs-tui--view-selected view) (emacs-tui--view-selected candidate)))))
  session)

(defun emacs-tui-tree-toggle (&optional session)
  "Toggle SESSION's selected tree branch without invoking its action."
  (interactive)
  (emacs-tui--tree-command session 'toggle))

(defun emacs-tui-tree-expand (&optional session)
  "Expand SESSION's selected branch, or move to its first child if open."
  (interactive)
  (emacs-tui--tree-command session 'expand))

(defun emacs-tui-tree-collapse (&optional session)
  "Collapse SESSION's selected branch, or move to its parent if closed."
  (interactive)
  (emacs-tui--tree-command session 'collapse))

(cl-defun emacs-tui-input (&key id title (value "") on-change keymap)
  "Describe an editable input for `emacs-tui-mount' or `emacs-tui-embed'.
ID, TITLE and KEYMAP follow `emacs-tui-view'.  VALUE is the initial string.
Ordinary editing, multiline input, input methods and undo use native Emacs
commands; `emacs-tui-next-view' changes view and `emacs-tui-close' closes it.
ON-CHANGE, when non-nil, receives (SESSION ID VALUE) after edits, including
undo.  VALUE has no text properties.  It is not called during initialization,
focus changes or programmatic `emacs-tui-update' calls.  Errors are reported
without discarding the edit or closing the interface.  Read the current value
with `emacs-tui-input-value'.  Applications own validation and persistence.
The ephemeral `emacs-tui-open' query workflow does not accept editable views."
  (unless (stringp value) (error "VALUE must be a string"))
  (unless (or (null on-change) (functionp on-change))
    (error "ON-CHANGE must be a function or nil"))
  (let ((view (emacs-tui-view :id id :title title :text value :keymap keymap)))
    (setf (emacs-tui--view-editable view) t
          (emacs-tui--view-on-change view) on-change)
    view))

(defun emacs-tui-input-value (&optional session id)
  "Return the full input string in SESSION's editable view ID.
SESSION defaults to the current interface; nil ID means its focused view.
Ignore narrowing and strip text properties.  Signal an error for other views."
  (let ((view (emacs-tui--resolve-view (emacs-tui--require-session session) id)))
    (unless (emacs-tui--view-editable view)
      (user-error "This view is not editable"))
    (with-current-buffer (emacs-tui--view-buffer view)
      (save-restriction
        (widen)
        (buffer-substring-no-properties (point-min) (point-max))))))

(defun emacs-tui--field-changed (&rest _arguments)
  "Record native edits and notify the current editable view's application."
  (when (and (not emacs-tui--rendering) (emacs-tui-live-p emacs-tui--session))
    (let* ((session emacs-tui--session)
           (view (cl-find (current-buffer) (emacs-tui--workspace-views session)
                          :key #'emacs-tui--view-buffer :test #'eq)))
      (when (and view (emacs-tui--view-editable view))
        (setf (emacs-tui--view-text view)
              (save-restriction (widen) (buffer-string)))
        (when (emacs-tui--view-on-change view)
          (condition-case err
              (funcall (emacs-tui--view-on-change view) session
                       (emacs-tui--view-id view)
                       (substring-no-properties (emacs-tui--view-text view)))
            ((error quit)
             (message "emacs-tui input callback: %s" (error-message-string err)))))))))

(defun emacs-tui--require-session (session)
  "Return live SESSION, defaulting to the current buffer's workspace."
  (let ((inferred (null session)))
    (setq session (or session emacs-tui--session))
    (unless (and (emacs-tui--workspace-p session)
                 (emacs-tui--workspace-active session))
      (user-error "No active emacs-tui workspace"))
    (when inferred (emacs-tui--sync-view-focus))
    session))

(defun emacs-tui-current-session ()
  "Return the live session associated with the current TUI buffer.
Signal a user error outside a live interface.  Application keymap commands
can pass this handle to `emacs-tui-update' and other explicit session APIs."
  (emacs-tui--require-session nil))

(defun emacs-tui-live-p (session)
  "Return non-nil if SESSION is a live interface handle."
  (and (emacs-tui--workspace-p session)
       (emacs-tui--workspace-active session)))

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

(defun emacs-tui--resolve-view (session id)
  "Return SESSION's view ID, or its focused view if ID is nil."
  (if id
      (or (cl-find id (emacs-tui--workspace-views session)
                   :key #'emacs-tui--view-id :test #'equal)
          (error "Unknown view: %S" id))
    (emacs-tui--focused-view session)))

(defun emacs-tui--marked-p (view item)
  "Return non-nil if ITEM is marked in VIEW."
  (and (emacs-tui--view-marks view)
       (gethash (emacs-tui--item-id item) (emacs-tui--view-marks view))))

(defun emacs-tui-marked-items (&optional session id)
  "Return marked source items in SESSION's view ID, in source order.
SESSION defaults to the current buffer's workspace, and ID defaults to
its focused view.  Include items hidden by local filtering.  Return
nil for ordinary views and text previews.  Removed source identities
lose their marks; updates with the same identities return new items."
  (let ((view (emacs-tui--resolve-view
               (emacs-tui--require-session session) id)))
    (when (and (emacs-tui--view-multi-select view)
               (not (emacs-tui--view-text view)))
      (cl-remove-if-not (lambda (item) (emacs-tui--marked-p view item))
                        (emacs-tui--view-items view)))))

(defun emacs-tui-toggle-mark (&optional session)
  "Toggle the selected item's mark in SESSION's focused multi-select view.
Return non-nil when the item becomes marked, nil when unmarked.  Marks
do not invoke selection or commit callbacks.  SESSION defaults to the
current buffer's workspace."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (item (emacs-tui-current-item session)))
    (unless (and (emacs-tui--view-multi-select view)
                 (not (emacs-tui--view-text view)))
      (user-error "This view does not support marks"))
    (unless item (user-error "No selected item"))
    (unless (emacs-tui--view-marks view)
      (setf (emacs-tui--view-marks view) (make-hash-table :test #'equal)))
    (let* ((marks (emacs-tui--view-marks view))
           (id (emacs-tui--item-id item))
           (marked (not (gethash id marks))))
      (if marked (puthash id t marks) (remhash id marks))
      (emacs-tui--render-view session view)
      marked)))

(defun emacs-tui-clear-marks (&optional session id)
  "Clear the marked state of SESSION's view ID, including hidden items.
SESSION defaults to the current buffer's workspace, and ID defaults to
its focused view.  Ordinary views are unchanged.  Return nil."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let ((view (emacs-tui--resolve-view session id)))
    (when (emacs-tui--view-marks view)
      (setf (emacs-tui--view-marks view) nil)
      (emacs-tui--render-view session view)))
  nil)

(defun emacs-tui-query (&optional session)
  "Return SESSION's query string, or an empty string if it has no input."
  (let ((query (emacs-tui--workspace-query-buffer
                (emacs-tui--require-session session))))
    (if query
        (with-current-buffer query
          (buffer-substring-no-properties (point-min) (point-max)))
      "")))

(defun emacs-tui--filter (session view)
  "Update VIEW's visible items for SESSION, preserving stable selection."
  (let* ((old (nth (emacs-tui--view-selected view)
                   (emacs-tui--view-visible-items view)))
         (terms (split-string (emacs-tui-query session) nil t))
         (case-fold-search t)
         (tree-terms (unless (or (emacs-tui--workspace-on-query session)
                                 (emacs-tui--workspace-provider session)) terms))
         (projection (when (emacs-tui--view-tree view)
                       (emacs-tui--tree-project (emacs-tui--view-tree view) tree-terms)))
         (items
          (if projection (car projection)
            (if (or (emacs-tui--workspace-on-query session)
                    (emacs-tui--workspace-provider session))
		(emacs-tui--view-items view)
              (cl-remove-if-not
               (lambda (item)
		 (cl-every
                  (lambda (term)
                    (string-match-p
                     (regexp-quote term)
                     (concat (emacs-tui--item-label item)
                             (when (emacs-tui--view-columns view)
                               (concat " "
                                       (mapconcat
					(lambda (column)
                                          (emacs-tui--cell-text
                                           (emacs-tui--table-value column item)))
					(emacs-tui--view-columns view) " "))))))
                  terms))
               (emacs-tui--view-items view))))))
    (when projection
      (setf (emacs-tui--view-tree-open view) (cdr projection)
            (emacs-tui--view-tree-search view) (and tree-terms t)))
    (when (emacs-tui--view-sort-column view)
      (setq items (emacs-tui--table-sort
                   items (emacs-tui--view-sort-column view)
                   (emacs-tui--view-sort-descending view))))
    (setf (emacs-tui--view-visible-items view) items
          (emacs-tui--view-selected view)
          (or (and old (cl-position (emacs-tui--item-id old) items
                                    :key #'emacs-tui--item-id :test #'equal))
              0))))

(defun emacs-tui-sort (&optional session id column descending)
  "Sort SESSION's table view ID by COLUMN's ID, optionally DESCENDING.
Nil ID selects the focused view; nil COLUMN restores source order.
Keep selection and marks by identity, never reorder source items or invoke
actions.  Updates retain this sort.  Interactively prompt for the column;
an empty answer restores source order, and a prefix requests descending order."
  (interactive
   (let* ((session (emacs-tui-current-session))
          (view (emacs-tui--focused-view session))
          (columns (emacs-tui--view-columns view)))
     (unless columns (user-error "This view is not a table"))
     (let* ((choices (mapcar (lambda (col)
                              (cons (format "%S" (emacs-tui--column-id col))
                                    (emacs-tui--column-id col))) columns))
            (answer (completing-read "Sort column (empty for source order): " choices nil t)))
       (list session nil (cdr (assoc answer choices)) current-prefix-arg))))
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--resolve-view session id))
         (columns (emacs-tui--view-columns view))
         (target (when column (cl-find column columns :key #'emacs-tui--column-id :test #'equal))))
    (unless (and columns (not (emacs-tui--view-text view)))
      (user-error "This view is not a table"))
    (when (and column (not target)) (user-error "Unknown table column: %S" column))
    (let ((candidate (copy-emacs-tui--view view)))
      (setf (emacs-tui--view-sort-column candidate) target
            (emacs-tui--view-sort-descending candidate) descending)
      (emacs-tui--filter session candidate)
      (emacs-tui--render-view session candidate)
      (setf (emacs-tui--view-sort-column view) target
            (emacs-tui--view-sort-descending view) descending
            (emacs-tui--view-visible-items view) (emacs-tui--view-visible-items candidate)
            (emacs-tui--view-selected view) (emacs-tui--view-selected candidate))))
  session)

(defun emacs-tui--view-header (session view)
  "Return VIEW's focus and mark header within SESSION."
  (concat (if (equal (emacs-tui--view-id view)
                         (emacs-tui--view-id (emacs-tui--focused-view session))) "* " "  ")
          (emacs-tui--view-title view)
          (when (emacs-tui--workspace-maximized session) " | maximized")
          (when (and (emacs-tui--view-multi-select view)
                     (not (emacs-tui--view-text view)))
            (format " | %d marked"
                    (if (emacs-tui--view-marks view)
                        (hash-table-count (emacs-tui--view-marks view))
                      0)))))

(defun emacs-tui--sync-view-focus ()
  "Synchronize native window focus with a queryless interface's focused view."
  (let ((session emacs-tui--session))
    (when (and (emacs-tui-live-p session)
               (not (emacs-tui--workspace-query-buffer session)))
      (let ((index (cl-position (current-buffer)
                                (emacs-tui--workspace-views session)
                                :key #'emacs-tui--view-buffer :test #'eq)))
        (when (and index (/= index (emacs-tui--workspace-focus session)))
          (setf (emacs-tui--workspace-focus session) index)
          (dolist (view (emacs-tui--workspace-views session))
            (when (buffer-live-p (emacs-tui--view-buffer view))
              (with-current-buffer (emacs-tui--view-buffer view)
                (setq header-line-format (emacs-tui--view-header session view))))))))))

(defun emacs-tui--view-content (view)
  "Prepare VIEW's complete content and selected position without display edits.
Return (CONTENT . POSITION).  Projection errors leave the live buffer intact."
  (if (emacs-tui--view-text view)
      (cons (emacs-tui--view-text view) 1)
    (let ((columns (emacs-tui--view-columns view))
          (position 1) (selected-position 1) chunks)
      (when columns
        (let ((header
               (concat (when (emacs-tui--view-multi-select view) "    ")
                       (propertize
                        (emacs-tui--table-line
                         columns nil t
                         (when (emacs-tui--view-sort-column view)
                           (emacs-tui--column-id (emacs-tui--view-sort-column view)))
                         (emacs-tui--view-sort-descending view)) 'face 'bold)
                       "\n")))
          (push header chunks)
          (cl-incf position (length header))))
      (cl-loop for item in (emacs-tui--view-visible-items view)
               for index from 0 do
               (let* ((annotation (and (not columns) (listp item)
                                       (plist-get item :annotation)))
                      (line
                       (concat (when (emacs-tui--view-multi-select view)
                                 (if (emacs-tui--marked-p view item) "[x] " "[ ] "))
                               (when (emacs-tui--view-tree view)
                                 (emacs-tui--tree-prefix (emacs-tui--view-tree view)
                                                         (emacs-tui--view-tree-open view) item))
                               (if columns (emacs-tui--table-line columns item)
                                 (emacs-tui--item-label item))
                               (when annotation
                                 (concat "  " (propertize (format "%s" annotation)
                                                           'face 'emacs-tui-annotation))))))
                 (when (= index (emacs-tui--view-selected view))
                   (setq selected-position position)
                   (add-face-text-property 0 (length line) 'emacs-tui-selection t line))
                 (push (concat line "\n") chunks)
                 (cl-incf position (1+ (length line)))))
      (cons (apply #'concat (nreverse chunks)) selected-position))))

(defun emacs-tui--render-view (session view)
  "Render VIEW in SESSION without replacing its buffer or window.
Prepare application projections before changing any displayed content."
  (let ((buffer (emacs-tui--view-buffer view)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let ((inhibit-read-only t)
              (emacs-tui--rendering t)
              (content (emacs-tui--view-content view)))
          (unless (and (emacs-tui--view-text view)
                       (save-restriction
                         (widen)
                         (equal-including-properties (car content) (buffer-string))))
            (atomic-change-group
              (erase-buffer)
              (insert (car content))
              (goto-char (cdr content)))
            (set-buffer-modified-p nil)
            (when (emacs-tui--view-text view)
              (setf (emacs-tui--view-display-state view) nil))
            (when (emacs-tui--view-editable view)
              (buffer-disable-undo)
              (buffer-enable-undo))
            (when (window-live-p (emacs-tui--view-window view))
              (set-window-point (emacs-tui--view-window view) (point))))
          (setq header-line-format (emacs-tui--view-header session view)))))))

(defun emacs-tui--query-changed (&rest arguments)
  "Refresh the workspace after a query edit.
ARGUMENTS come from `after-change-functions', or start with `initial'
to propagate initialization failures to the workspace opener."
  (let ((session emacs-tui--session))
    (when (and session (emacs-tui--workspace-active session))
      (when (emacs-tui--workspace-provider session)
        (emacs-tui--schedule-provider session (emacs-tui-query session)))
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
are unchanged.  Marks survive by identity while the identity remains
in ITEMS; non-nil TEXT clears marks.  Multi-select item identities must
be unique.  Identical preview text, including properties, retains its reading
position; changed text starts at the beginning.  Editable views accept only
string TEXT updates; changed values reset undo without calling ON-CHANGE.
Tree ITEMS are root snapshots; descendants are indexed through CHILDREN.
Non-nil TEXT is rejected for trees.  Return SESSION."
  (emacs-tui--require-session session)
  (let ((view (cl-find id (emacs-tui--workspace-views session)
                       :key #'emacs-tui--view-id :test #'equal)))
    (unless view (error "Unknown view: %S" id))
    (when (and (emacs-tui--view-editable view)
               (or items-p (and text-p (not (stringp text)))))
      (error "Editable views accept only string TEXT updates"))
    (when (and (emacs-tui--view-tree view) text-p text)
      (error "Tree views accept item updates, not text previews"))
    (when items-p
      (emacs-tui--validate-items items (emacs-tui--view-multi-select view)))
    (when (and text-p (not (or (null text) (stringp text))))
      (error "TEXT must be a string or nil"))
    (let ((candidate (copy-emacs-tui--view view)))
      (when items-p
        (when (emacs-tui--view-tree view)
          (let ((data (emacs-tui--tree-index items (emacs-tui--view-children view)
                                            (emacs-tui--view-tree view))))
            (setf (emacs-tui--view-tree candidate) data)
            (setq items (emacs-tui--tree-data-items data))))
        (setf (emacs-tui--view-items candidate) items))
      (when text-p (setf (emacs-tui--view-text candidate) text))
      (when (emacs-tui--view-marks candidate)
	(if (emacs-tui--view-text candidate)
            (setf (emacs-tui--view-marks candidate) nil)
          (when items-p
            (let ((marks (make-hash-table :test #'equal)))
              (dolist (item items)
		(when (emacs-tui--marked-p view item)
                  (puthash (emacs-tui--item-id item) t marks)))
              (setf (emacs-tui--view-marks candidate) marks)))))
      (emacs-tui--filter session candidate)
      (emacs-tui--render-view session candidate)
      (setf (emacs-tui--view-items view) (emacs-tui--view-items candidate)
            (emacs-tui--view-tree view) (emacs-tui--view-tree candidate)
            (emacs-tui--view-tree-open view) (emacs-tui--view-tree-open candidate)
            (emacs-tui--view-tree-search view) (emacs-tui--view-tree-search candidate)
            (emacs-tui--view-text view) (emacs-tui--view-text candidate)
            (emacs-tui--view-display-state view) (emacs-tui--view-display-state candidate)
            (emacs-tui--view-marks view) (emacs-tui--view-marks candidate)
            (emacs-tui--view-visible-items view) (emacs-tui--view-visible-items candidate)
            (emacs-tui--view-selected view) (emacs-tui--view-selected candidate))))
  session)

(defun emacs-tui--request-current-p (request)
  "Return non-nil if REQUEST may still publish into its live session."
  (let ((session (emacs-tui--request-session request)))
    (and (emacs-tui--request-active request)
         (emacs-tui--workspace-active session)
         (eq request (emacs-tui--workspace-request session)))))

(defun emacs-tui--call-cancel (cancel)
  "Invoke non-nil CANCEL, containing cancellation errors and quits."
  (when cancel
    (condition-case err
        (funcall cancel)
      ((error quit)
       (message "emacs-tui provider cancellation: %s" (error-message-string err))))))

(defun emacs-tui--stop-request (request)
  "Invalidate REQUEST and dispose its timer and cancellation handle once."
  (when request
    (let ((session (emacs-tui--request-session request))
          (timer (emacs-tui--request-timer request))
          (cancel (emacs-tui--request-cancel request)))
      (setf (emacs-tui--request-active request) nil
            (emacs-tui--request-timer request) nil
            (emacs-tui--request-cancel request) nil)
      (when (eq request (emacs-tui--workspace-request session))
        (setf (emacs-tui--workspace-request session) nil))
      (when timer (cancel-timer timer))
      (emacs-tui--call-cancel cancel))))

(defun emacs-tui--provider-fail (request error)
  "Terminate current REQUEST with ERROR, an error condition or string.
Return t if accepted, or nil for an obsolete request."
  (when (emacs-tui--request-current-p request)
    (emacs-tui--stop-request request)
    (message "emacs-tui provider: %s"
             (if (stringp error) error
               (condition-case nil (error-message-string error)
                 (error (format "%S" error)))))
    t))

(defun emacs-tui--provider-publish (request id &rest keywords)
  "Update view ID only while REQUEST is current.
KEYWORDS are the property replacements for `emacs-tui-update'.
Return t if accepted, or nil if obsolete or invalid.  Invalid data
terminates the request without partially applying update arguments."
  (when (emacs-tui--request-current-p request)
    (let ((session (emacs-tui--request-session request)))
      (condition-case err
          (progn
            (apply #'emacs-tui-update session id keywords)
            (cl-pushnew id (emacs-tui--workspace-provider-views session) :test #'equal)
            t)
        ((error quit) (emacs-tui--provider-fail request err) nil)))))

(defun emacs-tui--start-provider (request)
  "Start REQUEST after debounce, with generation-bound publishing callbacks."
  (setf (emacs-tui--request-timer request) nil)
  (when (emacs-tui--request-current-p request)
    (let ((session (emacs-tui--request-session request)) returned)
      (unwind-protect
          (condition-case err
              (let ((cancel
                     (funcall
                      (emacs-tui--workspace-provider session)
                      session (emacs-tui--request-query request)
                      (lambda (id &rest updates)
                        (apply #'emacs-tui--provider-publish request id updates))
                      (lambda (error) (emacs-tui--provider-fail request error)))))
                (setq returned t)
                (unless (or (null cancel) (functionp cancel))
                  (error "A provider must return nil or a cancellation function"))
                (if (emacs-tui--request-current-p request)
                    (setf (emacs-tui--request-cancel request) cancel)
                  (emacs-tui--call-cancel cancel)))
            ((error quit) (emacs-tui--provider-fail request err)))
        (unless returned (emacs-tui--stop-request request))))))

(defun emacs-tui--schedule-provider (session query)
  "Schedule SESSION's provider for QUERY, superseding previous work.
Invalidate the previous generation before calling its cancellation
function.  Already published views are cleared to prevent committing
results belonging to the previous query.  Untouched views are retained."
  (let ((previous (emacs-tui--workspace-request session))
        (request (emacs-tui--make-request :session session :query query))
        scheduled)
    (setf (emacs-tui--workspace-request session) request)
    (unwind-protect
        (progn
          (dolist (id (emacs-tui--workspace-provider-views session))
            (emacs-tui-update session id :items nil :text nil))
          (emacs-tui--stop-request previous)
          (when (emacs-tui--request-current-p request)
            (setf (emacs-tui--request-query request) (emacs-tui-query session)
                  (emacs-tui--request-timer request)
                  (run-at-time (emacs-tui--workspace-debounce session) nil
                               #'emacs-tui--start-provider request))
            (setq scheduled t)))
      (unless scheduled (emacs-tui--stop-request request))
      (emacs-tui--stop-request previous))))

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
           (query (emacs-tui--workspace-query-buffer session))
           (minimum (if query 8 4))
           (window-min-height (if query 3 2))
           (height (window-total-height origin)))
      (when (< height minimum)
        (user-error "Need at least %d window rows for this interface" minimum))
      (setf (emacs-tui--workspace-root session)
            (split-window origin (- (max (if query 4 2) (/ height 2))) 'below)
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
  "Record WINDOW as an owned resource of SESSION and return WINDOW."
  (set-window-parameter window 'emacs-tui-session session)
  (cl-pushnew window (emacs-tui--workspace-windows session))
  window)

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
               (frame-live-p (emacs-tui--workspace-origin-frame session))
               (or (null (emacs-tui--workspace-origin session))
                   (and (window-live-p (emacs-tui--workspace-origin-window session))
                        (buffer-live-p (marker-buffer (emacs-tui--workspace-origin session)))))
               (or (null (emacs-tui--workspace-query-buffer session))
                   (eq (window-buffer root) (emacs-tui--workspace-query-buffer session)))
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
  (when-let* ((subtree (emacs-tui--subtree session)))
    (list (window-edges subtree)
          (mapcar (lambda (window) (list window (window-edges window)))
                  (cl-remove-if-not #'window-live-p
                                    (emacs-tui--workspace-windows session)))
          (when-let* ((child (emacs-tui--workspace-frame session)))
            (let ((parent (emacs-tui--workspace-origin-frame session)))
              (and (frame-live-p child)
                   (list (frame-inner-width parent) (frame-inner-height parent)
                         (frame-pixel-width child) (frame-pixel-height child)
                         (frame-char-width child) (frame-char-height child)
                         (frame-parameter child 'left) (frame-parameter child 'top))))))))

(defun emacs-tui--remember-view (view)
  "Capture VIEW's native window position before hiding or rearranging it."
  (let ((window (emacs-tui--view-window view)))
    (when (and (window-live-p window)
               (eq (window-buffer window) (emacs-tui--view-buffer view)))
      (setf (emacs-tui--view-display-state view)
            (list (window-start window) (window-point window)
                  (window-hscroll window) (window-vscroll window t))))))

(defun emacs-tui--restore-view (view)
  "Restore VIEW's cached scroll and text cursor in its current window."
  (let ((window (emacs-tui--view-window view))
        (state (emacs-tui--view-display-state view)))
    (when (and state (window-live-p window))
      (with-current-buffer (emacs-tui--view-buffer view)
        (let ((start (max (point-min) (min (point-max) (nth 0 state))))
              (position (max (point-min) (min (point-max) (nth 1 state)))))
          (set-window-start window start t)
          (when (emacs-tui--view-text view) (set-window-point window position))
          (set-window-hscroll window (nth 2 state))
          (set-window-vscroll window (nth 3 state) t))))))

(defun emacs-tui--reveal-focus (session &optional arranging)
  "Reveal SESSION's focused view, retaining hidden view positions.
ARRANGING means old windows were already captured before layout changes."
  (let ((focused (emacs-tui--focused-view session)))
    (unless (window-live-p (emacs-tui--view-window focused))
      (let ((visible (cl-find-if
                      (lambda (view)
                        (window-live-p (emacs-tui--view-window view)))
                      (emacs-tui--workspace-views session))))
        (when visible
          (let ((window (emacs-tui--view-window visible)))
            (unless arranging (emacs-tui--remember-view visible))
            (setf (emacs-tui--view-window visible) nil
                  (emacs-tui--view-window focused) window)
            (set-window-buffer window (emacs-tui--view-buffer focused))
            (emacs-tui--restore-view focused)))))))

(defun emacs-tui--arrange (session)
  "Arrange SESSION's views inside its owned window subtree."
  (let ((root (emacs-tui--workspace-root session))
        (query (emacs-tui--workspace-query-buffer session))
        (window-combination-limit t))
    (dolist (window (emacs-tui--workspace-windows session))
      (when (and (not (eq root window)) (window-live-p window)
                 (eq (window-parameter window 'emacs-tui-session) session))
        (delete-window window)))
    (dolist (view (emacs-tui--workspace-views session))
      (setf (emacs-tui--view-window view) nil))
    (setf (emacs-tui--workspace-windows session) (list root))
    (set-window-buffer root (or query (emacs-tui--view-buffer
                                       (car (emacs-tui--workspace-views session)))))
    (emacs-tui--own-window session root)
    (let* ((window-min-height 1)
           (panel (if query
                      (when (> (window-total-height root) 2)
                        (emacs-tui--own-window session (split-window root 2 'below)))
                    root)))
      (when panel
        (let ((rectangles
               (emacs-tui-layout-compute
                (if (emacs-tui--workspace-maximized session)
                    (list (emacs-tui--view-id (emacs-tui--focused-view session)))
                  (mapcar #'emacs-tui--view-id (emacs-tui--workspace-views session)))
                (window-total-width panel) (window-total-height panel)
                (emacs-tui--workspace-layout session))))
          (condition-case err
              (emacs-tui--split-rectangles session panel rectangles)
            (error
             (dolist (window (emacs-tui--workspace-windows session))
               (when (and (not (memq window (list root panel)))
                          (window-live-p window))
                 (delete-window window)))
             (dolist (view (emacs-tui--workspace-views session))
               (setf (emacs-tui--view-window view) nil))
             (setf (emacs-tui--workspace-windows session)
                   (delete-dups (list root panel)))
             (when (window-live-p panel)
               (set-window-buffer panel (emacs-tui--view-buffer
                                         (car (emacs-tui--workspace-views session))))
               (setf (emacs-tui--view-window
                      (car (emacs-tui--workspace-views session))) panel))
             (message "emacs-tui compact layout: %s" (error-message-string err)))))))
    (emacs-tui--reveal-focus session t)
    (dolist (view (emacs-tui--workspace-views session))
      (emacs-tui--render-view session view)
      (emacs-tui--restore-view view))))

(defun emacs-tui--focus-window (session)
  "Select SESSION's focused view when there is no separate query input."
  (unless (emacs-tui--workspace-query-buffer session)
    (let ((window (emacs-tui--view-window (emacs-tui--focused-view session))))
      (when (window-live-p window) (select-window window)))))

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
                       (point (when query (with-current-buffer query (point))))
                       (owned-selection (emacs-tui--owned-window-p session (selected-window)))
                       (window-point (window-point root)))
                  (mapc #'emacs-tui--remember-view (emacs-tui--workspace-views session))
                  (save-selected-window
                    (when (emacs-tui--workspace-frame session)
                      (emacs-tui--fit-child session))
                    (emacs-tui--arrange session)
                    (when query
                      (with-current-buffer query (goto-char point))
                      (set-window-point root window-point)))
                  (when owned-selection (emacs-tui--focus-window session)))
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
                               on-query on-commit provider (debounce 0.08) on-close keymap)
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
ITEM may be nil when the focused multi-select view has marked items
but no visible selection; use `emacs-tui-marked-items' for a batch.

PROVIDER is an asynchronous alternative to ON-QUERY; supplying both
is an error.  It receives (SESSION QUERY PUBLISH FAIL) after DEBOUNCE
seconds without a query change.  DEBOUNCE must be nonnegative and
finite; even zero starts via a timer.  The provider must return promptly
with nil or a zero-argument cancellation function.  Call PUBLISH with
a view ID and `emacs-tui-update' keywords, repeatedly for streaming
replacements.  Call FAIL with an error condition or string to terminate
the request.  Obsolete callbacks are ignored after query changes or
session close.  Views previously published by the provider are cleared
on a new query; untouched static views remain available.

KEYMAP optionally adds application commands in view buffers, leaving query
editing untouched.  View-specific maps take precedence over KEYMAP, which
precedes the default view map.  Maps are referenced without mutation.

ON-CLOSE receives the closed session once, including initialization failures
after allocation, and may release application-owned timers or resources.

The query is editable scratch text; the source buffer and its point
are not modified by opening, filtering, selecting or cancelling."
  (emacs-tui--create :views views :layout layout :backend backend
                     :on-query on-query :on-commit on-commit
                     :provider provider :debounce debounce :on-close on-close :keymap keymap
                     :ephemeral t))

(cl-defun emacs-tui-mount (&key views (layout 'columns) (backend 'windows)
                                provider (debounce 0.08) on-close keymap)
  "Mount a persistent interface and return its session handle.
VIEWS, LAYOUT and BACKEND have the same meaning as in `emacs-tui-open'.
The interface owns its surface and view buffers, but has no query
buffer, origin marker or commit destination.  Killing its launching
buffer or window does not end it.  Explicit selection actions may
update application data and keep the interface open.

PROVIDER optionally starts asynchronous work with the same contract as
`emacs-tui-open', using an empty query after DEBOUNCE seconds.  Updates
use `emacs-tui-update'.  ON-CLOSE receives the closed session once and
may release application resources.  Use `emacs-tui-live-p' to check a
retained handle.  Close explicitly with `emacs-tui-close'.  KEYMAP supplies
application view bindings as in `emacs-tui-open'.

This entry point creates owned windows or a child frame.  To borrow an
application-owned window for one panel, use `emacs-tui-embed'."
  (emacs-tui--create :views views :layout layout :backend backend
                     :provider provider :debounce debounce :on-close on-close :keymap keymap))

(cl-defun emacs-tui-embed (&key view (window (selected-window))
                              provider (debounce 0.08) on-close keymap)
  "Display VIEW in application-owned WINDOW and return a session handle.
WINDOW defaults to the selected window and becomes selected.  It must be
live, non-minibuffer, non-dedicated and not already claimed by a TUI.
The toolkit owns its new view buffer, but never deletes WINDOW or modifies
its previous buffer.  Closing restores the previous buffer, point and scroll
if WINDOW still displays the panel.  Host positions track intervening edits.
A repurposed window is left alone; a deleted window closes the session.

PROVIDER, DEBOUNCE, ON-CLOSE and KEYMAP follow `emacs-tui-mount'.
Explicit actions keep the panel open.  This entry point embeds one list or
text view; use
separate sessions for independently owned panels."
  (unless (and (window-live-p window) (not (window-minibuffer-p window))
               (not (window-dedicated-p window))
               (not (emacs-tui-live-p (window-parameter window 'emacs-tui-session)))
               (not (emacs-tui-live-p
                     (buffer-local-value 'emacs-tui--session (window-buffer window)))))
    (user-error "Embedding requires a live, unclaimed, non-dedicated window"))
  (emacs-tui--create :views (list view) :layout 'columns :host-window window
                     :provider provider :debounce debounce :on-close on-close :keymap keymap))

(cl-defun emacs-tui--create (&key views layout backend on-query on-commit
                                  provider debounce on-close ephemeral host-window keymap)
  "Create views and resources shared by both interface lifecycles.
VIEWS, LAYOUT, BACKEND, ON-QUERY, ON-COMMIT, PROVIDER, DEBOUNCE and
ON-CLOSE specify configuration.  EPHEMERAL enables query input and
origin-buffer commit policy.  HOST-WINDOW borrows an existing window.
KEYMAP supplies application commands for view buffers."
  (unless (and (proper-list-p views) views
               (cl-every #'emacs-tui--view-p views))
    (error "VIEWS must be a nonempty list of emacs-tui-view descriptions"))
  (when (and ephemeral (cl-some #'emacs-tui--view-editable views))
    (error "Editable views require emacs-tui-mount or emacs-tui-embed"))
  (unless (memq layout '(columns rows grid)) (error "Unknown layout: %S" layout))
  (when (and on-query provider)
    (error "PROVIDER and ON-QUERY are mutually exclusive"))
  (unless (condition-case nil
              (and (numberp debounce) (>= debounce 0) (< debounce 1.0e+INF))
            (arith-error nil))
    (error "DEBOUNCE must be a nonnegative finite number"))
  (dolist (callback (list on-query on-commit provider on-close))
    (unless (or (null callback) (functionp callback))
      (error "Callbacks must be functions or nil")))
  (unless (or (null keymap) (keymapp keymap))
    (error "KEYMAP must be a keymap or nil"))
  (let ((ids (mapcar #'emacs-tui--view-id views)))
    (unless (= (length ids) (length (delete-dups (copy-sequence ids))))
      (error "View IDs must be unique")))
  (let* ((session
          (emacs-tui--make-workspace
           :views (mapcar #'copy-emacs-tui--view views) :layout layout
           :on-query on-query :on-commit on-commit
           :provider provider :debounce debounce :on-close on-close
           :origin (when ephemeral (copy-marker (point)))
           :origin-window (or host-window (selected-window))
           :origin-frame (if host-window (window-frame host-window) (selected-frame))
           :active t))
         (query (when ephemeral (generate-new-buffer " *emacs-tui query*")))
         initialized)
    (setf (emacs-tui--workspace-query-buffer session) query)
    (unwind-protect
        (progn
          (when query
            (with-current-buffer query
              (emacs-tui-input-mode)
              (setq-local emacs-tui--session session)
              (add-hook 'after-change-functions #'emacs-tui--query-changed nil t)
              (add-hook 'kill-buffer-hook #'emacs-tui--buffer-killed nil t)))
          (dolist (view (emacs-tui--workspace-views session))
            (setf (emacs-tui--view-buffer view)
                  (generate-new-buffer (format " *emacs-tui %s*"
                                               (emacs-tui--view-id view)))
                  (emacs-tui--view-window view) nil
                  (emacs-tui--view-display-state view) nil
                  (emacs-tui--view-marks view) nil)
            (when (emacs-tui--view-tree view)
              (let ((data (copy-emacs-tui--tree-data (emacs-tui--view-tree view))))
                (setf (emacs-tui--tree-data-expanded data)
                      (copy-hash-table (emacs-tui--tree-data-expanded data))
                      (emacs-tui--view-tree view) data)))
            (with-current-buffer (emacs-tui--view-buffer view)
              (if (emacs-tui--view-tree view)
                  (emacs-tui-tree-mode)
                (if (emacs-tui--view-editable view)
                  (emacs-tui-field-mode)
                  (emacs-tui-view-mode)))
              (when (or keymap (emacs-tui--view-keymap view))
                (use-local-map
                 (make-composed-keymap
                  (delq nil (list (emacs-tui--view-keymap view) keymap))
                  (current-local-map))))
              (setq-local emacs-tui--session session)
              (when (emacs-tui--view-editable view)
                (add-hook 'after-change-functions #'emacs-tui--field-changed nil t))
              (add-hook 'kill-buffer-hook #'emacs-tui--buffer-killed nil t)
              (unless query
                (add-hook 'post-command-hook #'emacs-tui--sync-view-focus nil t))))
          (if host-window
              (let ((buffer (window-buffer host-window)))
                (setf (emacs-tui--workspace-host session)
                      (with-current-buffer buffer
                        (emacs-tui--make-host
                         :window host-window :buffer buffer
                         :point (copy-marker (window-point host-window))
                         :start (copy-marker (window-start host-window))
                         :hscroll (window-hscroll host-window)
                         :vscroll (window-vscroll host-window t)))
                      (emacs-tui--workspace-root session) host-window
                      (emacs-tui--workspace-backend session) 'embedded))
            (emacs-tui--make-surface session backend))
          (emacs-tui--arrange session)
          (setf (emacs-tui--workspace-geometry session) (emacs-tui--geometry session))
          (push session emacs-tui--sessions)
          (add-hook 'delete-frame-functions #'emacs-tui--frame-deleted)
          (add-hook 'window-state-change-hook #'emacs-tui--window-state-changed)
          (when ephemeral
            (let ((hook (lambda () (emacs-tui-close session))))
              (setf (emacs-tui--workspace-origin-kill-hook session) hook)
              (with-current-buffer (marker-buffer (emacs-tui--workspace-origin session))
                (add-hook 'kill-buffer-hook hook nil t))))
          (select-window (emacs-tui--workspace-root session))
          (emacs-tui--focus-window session)
          (with-current-buffer (or query (emacs-tui--view-buffer
                                          (emacs-tui--focused-view session)))
            (emacs-tui--query-changed 'initial))
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

(defun emacs-tui--restore-host (session)
  "Release SESSION's borrowed window and restore its untouched host state."
  (when-let* ((host (emacs-tui--workspace-host session)))
    (let ((window (emacs-tui--host-window host)))
      (unwind-protect
          (when (and (window-live-p window)
                     (eq (window-parameter window 'emacs-tui-session) session))
            (let ((owned (emacs-tui--owned-window-p session window)))
              (set-window-parameter window 'emacs-tui-session nil)
              (when owned
                (let ((buffer (emacs-tui--host-buffer host))
                      (dedicated (window-dedicated-p window)))
                  (unwind-protect
                      (progn
                        (set-window-dedicated-p window nil)
                        (if (buffer-live-p buffer)
                            (progn
                              (set-window-buffer window buffer)
                              (set-window-point window (emacs-tui--host-point host))
                              (set-window-start window (emacs-tui--host-start host) t)
                              (set-window-hscroll window (emacs-tui--host-hscroll host))
                              (set-window-vscroll window (emacs-tui--host-vscroll host) t))
                          (set-window-buffer window (other-buffer (window-buffer window) t))))
                    (when (window-live-p window)
                      (set-window-dedicated-p window dedicated)))))))
        (set-marker (emacs-tui--host-point host) nil)
        (set-marker (emacs-tui--host-start host) nil)
        (setf (emacs-tui--workspace-host session) nil
              (emacs-tui--workspace-windows session)
              (delq window (emacs-tui--workspace-windows session)))))))

(defun emacs-tui-close (&optional session)
  "Close SESSION, discarding interface state and releasing owned resources.
It is safe to close an already-closed session.  Source text and other
windows are preserved."
  (interactive)
  (setq session (or session emacs-tui--session))
  (when (and (emacs-tui--workspace-p session)
             (emacs-tui--workspace-active session))
    (setf (emacs-tui--workspace-active session) nil)
    (setq emacs-tui--sessions (delq session emacs-tui--sessions))
    (unwind-protect
        (let* ((origin (emacs-tui--workspace-origin session))
               (origin-window (emacs-tui--workspace-origin-window session))
               (frame (emacs-tui--workspace-frame session))
               (owned-selection (emacs-tui--owned-window-p session (selected-window))))
	  (when (and origin (buffer-live-p (marker-buffer origin)))
            (with-current-buffer (marker-buffer origin)
              (remove-hook 'kill-buffer-hook
			   (emacs-tui--workspace-origin-kill-hook session) t)))
	  (when (and owned-selection (window-live-p origin-window))
            (select-window origin-window))
          (emacs-tui--restore-host session)
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
                      (when (and origin (buffer-live-p (marker-buffer origin)))
			(set-window-buffer window (marker-buffer origin))
			(set-window-point window origin))
                      (unless origin
                        (set-window-buffer window (other-buffer (window-buffer window) t)))))))))
	  (dolist (buffer (cons (emacs-tui--workspace-query-buffer session)
				(mapcar #'emacs-tui--view-buffer
					(emacs-tui--workspace-views session))))
            (when (buffer-live-p buffer)
              (with-current-buffer buffer (set-buffer-modified-p nil))
              (kill-buffer buffer)))
	  (when origin (set-marker origin nil)))
      (unless emacs-tui--sessions
	(remove-hook 'delete-frame-functions #'emacs-tui--frame-deleted)
	(remove-hook 'window-state-change-hook #'emacs-tui--window-state-changed))
      (unwind-protect
          (emacs-tui--stop-request (emacs-tui--workspace-request session))
        (let ((callback (emacs-tui--workspace-on-close session)))
          (setf (emacs-tui--workspace-on-close session) nil)
          (when callback
            (condition-case err (funcall callback session)
              ((error quit)
               (message "emacs-tui close callback: %s" (error-message-string err)))))))))
  nil)

(defun emacs-tui-next-view (&optional session delta)
  "Move SESSION's logical view focus by DELTA, defaulting to one."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (setf (emacs-tui--workspace-focus session)
        (mod (+ (emacs-tui--workspace-focus session) (or delta 1))
             (length (emacs-tui--workspace-views session))))
  (emacs-tui--reveal-focus session)
  (emacs-tui--focus-window session)
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
the workspace open.  Applications own all persistence semantics.
The callback receives a nil item only when the focused multi-select
view has marked items but no visible selection.  Read those items with
`emacs-tui-marked-items' to implement batch commits."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let ((callback (emacs-tui--workspace-on-commit session))
        (origin (emacs-tui--workspace-origin session))
        (item (emacs-tui-current-item session)))
    (unless callback (user-error "This workspace has no commit action"))
    (unless (or item (emacs-tui-marked-items session))
      (user-error "No selected item or marked items"))
    (unless (buffer-live-p (marker-buffer origin))
      (user-error "The origin buffer no longer exists"))
    (with-current-buffer (marker-buffer origin)
      (save-excursion
        (goto-char origin)
        (atomic-change-group (funcall callback session item origin))))
    (emacs-tui-close session)))

(defun emacs-tui-toggle-maximize (&optional session)
  "Toggle focused-view maximization within SESSION's owned surface.
Keep an ephemeral query visible.  View navigation visits every view while
maximized; toggling again restores the selected layout.  Preserve native
input/undo, text position and scroll, logical selection, marks and expansion.
No application actions or providers are invoked.  A single-view interface
is already full size and is unchanged.  Return SESSION, or nil if reflow
closes an invalidated surface."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (if (= 1 (length (emacs-tui--workspace-views session))) session
    (setf (emacs-tui--workspace-maximized session)
          (not (emacs-tui--workspace-maximized session)))
    (emacs-tui-refresh session)))

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
