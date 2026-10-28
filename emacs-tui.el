;;; emacs-tui.el --- Composable text interfaces -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; URL: https://github.com/vv111y/emacs-tui
;; Version: 0.1.0-beta4
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
(require 'emacs-tui-action)

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
  tree children tree-open tree-search display-state query actions)

(cl-defstruct (emacs-tui--workspace (:constructor emacs-tui--make-workspace))
  views (focus 0) layout backend on-query on-commit origin origin-window
  origin-frame frame query-buffer root windows active origin-kill-hook geometry
  provider debounce request provider-views on-close host maximized tty-focus popup)

(cl-defstruct (emacs-tui--popup (:constructor emacs-tui--make-popup))
  buffer begin end position width height terminal)

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

(defvar-local emacs-tui--row-ranges nil
  "Vector of displayed item bounds, excluding each trailing newline.")

(defvar-local emacs-tui--row-items nil
  "Item snapshot whose positions are in `emacs-tui--row-ranges'.")

(defvar-local emacs-tui--row-tick nil
  "Character modification tick at which row positions were prepared.")

(defvar-local emacs-tui--selection-overlay nil
  "Owned selection highlight, separate from application text properties.")

(defvar emacs-tui-input-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'emacs-tui-next-view)
    (define-key map (kbd "<backtab>") #'emacs-tui-previous-view)
    (define-key map (kbd "M-n") #'emacs-tui-next-item)
    (define-key map (kbd "M-p") #'emacs-tui-previous-item)
    (define-key map (kbd "C-c <") #'emacs-tui-first-item)
    (define-key map (kbd "C-c >") #'emacs-tui-last-item)
    (define-key map (kbd "RET") #'emacs-tui-select)
    (define-key map (kbd "C-c C-c") #'emacs-tui-commit)
    (define-key map (kbd "C-c C-m") #'emacs-tui-toggle-mark)
    (define-key map (kbd "C-c *") #'emacs-tui-mark-all)
    (define-key map (kbd "C-c C-t") #'emacs-tui-invert-marks)
    (define-key map (kbd "C-c C-u") #'emacs-tui-clear-marks)
    (define-key map (kbd "C-c C-l") #'emacs-tui-cycle-layout)
    (define-key map (kbd "C-c C-a") #'emacs-tui-act)
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
    (define-key map (kbd "a") #'emacs-tui-act)
    map)
  "Keymap for list and text views, including queryless applications.")

(define-derived-mode emacs-tui-view-mode special-mode "TUI-View"
  "Display a text interface view."
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t)
  (setq-local cursor-type nil))

(defvar emacs-tui-tree-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c +") #'emacs-tui-tree-expand-all)
    (define-key map (kbd "C-c -") #'emacs-tui-tree-collapse-all)
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
    (define-key map (kbd "C-c C-a") #'emacs-tui-act)
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

(cl-defun emacs-tui-view (&key id title items text on-select multi-select keymap columns actions)
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
ACTIONS optionally lists `emacs-tui-action' descriptions for explicit context
operations.  Use `emacs-tui-act' to choose or invoke one.  Rendering never
evaluates action predicates or callbacks.  View descriptions are copied
when opened."
  (unless (and id (or (symbolp id) (stringp id)))
    (error "View ID must be a non-nil symbol or string"))
  (unless (or (null text) (stringp text)) (error "TEXT must be a string"))
  (unless (or (null on-select) (functionp on-select))
    (error "ON-SELECT must be a function"))
  (unless (or (null keymap) (keymapp keymap))
    (error "KEYMAP must be a keymap or nil"))
  (emacs-tui--validate-columns columns)
  (emacs-tui--validate-actions actions)
  (emacs-tui--make-view :id id :title (or title (format "%s" id))
                        :items (emacs-tui--validate-items items multi-select)
                        :visible-items items :text text :on-select on-select
                        :multi-select multi-select :keymap keymap :columns columns :actions actions))

(cl-defun emacs-tui-tree (&key id title items (children :children)
                               on-select multi-select keymap actions)
  "Describe a finite tree of application ITEMS with view ID and TITLE.
CHILDREN is a plist keyword or pure function returning an item's child list.
It is evaluated once per node during construction and source replacement,
never during rendering or expansion.  Return promptly; load data in the
application or use an asynchronous provider to publish complete snapshots.
Items follow `emacs-tui-view'; plist nodes require explicit non-nil :id values.
Identities must be globally unique, including collapsed descendants.  Cycles
and repeated nodes are rejected.  Roots start collapsed.  Source updates
retain expansion, selection and marks for surviving identities.
ON-SELECT, MULTI-SELECT, KEYMAP and ACTIONS follow `emacs-tui-view'.
Selection/actions
receive the original item.  Local queries show matches and their ancestors
without changing expansion; clear the query before changing expansion."
  (unless (or (keywordp children) (functionp children))
    (error "CHILDREN must be a keyword or function"))
  (let* ((data (emacs-tui--tree-index items children))
         (projection (emacs-tui--tree-project data nil))
         (view (emacs-tui-view :id id :title title
                               :items (emacs-tui--tree-data-items data)
                               :on-select on-select :multi-select multi-select :keymap keymap :actions actions)))
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

(defun emacs-tui--tree-expand-all (session id expand)
  "Set all branches in SESSION's tree ID to EXPAND, staging before rendering."
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--resolve-view session id))
         (data (emacs-tui--view-tree view)))
    (unless data (user-error "This view is not a tree"))
    (when (emacs-tui--view-tree-search view)
      (user-error "Clear the local query before changing tree expansion"))
    (unless (emacs-tui--subtree session)
      (user-error "Interface surface is no longer owned"))
    (let* ((candidate (copy-emacs-tui--view view))
           (next-data (copy-emacs-tui--tree-data data))
           (expanded (make-hash-table :test #'equal))
           (item (nth (emacs-tui--view-selected view)
                      (emacs-tui--view-visible-items view)))
           (target (and item (emacs-tui--item-id item))))
      (if expand
          (maphash (lambda (key children)
                     (when children (puthash key t expanded)))
                   (emacs-tui--tree-data-children data))
        (while (and target (gethash target (emacs-tui--tree-data-parents data)))
          (setq target (gethash target (emacs-tui--tree-data-parents data)))))
      (setf (emacs-tui--tree-data-expanded next-data) expanded
            (emacs-tui--view-tree candidate) next-data)
      (emacs-tui--filter session candidate)
      (when target
        (setf (emacs-tui--view-selected candidate)
              (or (cl-position target (emacs-tui--view-visible-items candidate)
                               :key #'emacs-tui--item-id :test #'equal) 0)))
      (emacs-tui--render-view session candidate)
      (setf (emacs-tui--view-tree view) next-data
            (emacs-tui--view-tree-open view) (emacs-tui--view-tree-open candidate)
            (emacs-tui--view-visible-items view) (emacs-tui--view-visible-items candidate)
            (emacs-tui--view-selected view) (emacs-tui--view-selected candidate))))
  session)

(defun emacs-tui-tree-expand-all (&optional session id)
  "Expand every branch in SESSION's tree view ID and return SESSION.
Nil ID means the focused view.  Preserve selection by identity, queries,
marks and focus, including hidden panels.  Do not invoke application actions
or re-evaluate the child accessor.  Clear local search before expanding."
  (interactive)
  (emacs-tui--tree-expand-all session id t))

(defun emacs-tui-tree-collapse-all (&optional session id)
  "Collapse every branch in SESSION's tree view ID and return SESSION.
Select the selected item's root ancestor.  Keep hidden marks and focus.
Use the same search, action and child-accessor rules as
`emacs-tui-tree-expand-all'."
  (interactive)
  (emacs-tui--tree-expand-all session id nil))

(cl-defun emacs-tui-input (&key id title (value "") on-change keymap actions)
  "Describe an editable input for `emacs-tui-mount' or `emacs-tui-embed'.
ID, TITLE, KEYMAP and ACTIONS follow `emacs-tui-view'.
VALUE is the initial string.
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
  (let ((view (emacs-tui-view :id id :title title :text value :keymap keymap :actions actions)))
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

(defun emacs-tui--capture-input (view)
  "Synchronize editable VIEW's cached text with its live buffer.
Native hooks may be inhibited by another buffer's modification hook.  Read
the buffer before redisplay can replace it with an obsolete cached value.
This does not edit text, reset undo or synthesize an application callback."
  (when (and (emacs-tui--view-editable view)
             (buffer-live-p (emacs-tui--view-buffer view)))
    (with-current-buffer (emacs-tui--view-buffer view)
      (setf (emacs-tui--view-text view)
            (save-restriction (widen) (buffer-string))))))

(defun emacs-tui--field-changed (&rest _arguments)
  "Record native edits and notify the current editable view's application."
  (when (and (not emacs-tui--rendering) (emacs-tui-live-p emacs-tui--session))
    (let* ((session emacs-tui--session)
           (view (cl-find (current-buffer) (emacs-tui--workspace-views session)
                          :key #'emacs-tui--view-buffer :test #'eq)))
      (when (and view (emacs-tui--view-editable view))
        (setf (emacs-tui--view-display-state view) nil
              (emacs-tui--view-text view)
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
    (when (and (emacs-tui--workspace-popup session)
               (not (emacs-tui--subtree session)))
      (emacs-tui-close session)
      (user-error "Popup source or surface is no longer available"))
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

(defun emacs-tui-current-view (&optional session)
  "Return the logically focused view ID in SESSION.
SESSION defaults to the current interface.  Return its configured ID,
not an internal view structure."
  (emacs-tui--view-id (emacs-tui--focused-view (emacs-tui--require-session session))))

(defun emacs-tui-current-item (&optional session id)
  "Return SESSION's selected item in view ID, or nil.
Without ID, use the focused view when displayed, preserving normal action
semantics.  With ID, read its projected selection even in a hidden panel.
Text previews and editable inputs have no selected item.  The returned object
is from the current source snapshot; no focus or application action changes."
  (let ((view (emacs-tui--resolve-view (emacs-tui--require-session session) id)))
    (when (and (not (emacs-tui--view-text view))
               (or id (window-live-p (emacs-tui--view-window view))))
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

(defun emacs-tui--set-marks (session view table)
  "Render VIEW in SESSION with mark TABLE, then publish it."
  (let ((candidate (copy-emacs-tui--view view)))
    (setf (emacs-tui--view-marks candidate) table)
    (emacs-tui--render-view session candidate)
    (setf (emacs-tui--view-marks view) table)))

(defun emacs-tui-toggle-mark (&optional session)
  "Toggle the selected item's mark in SESSION's focused multi-select view.
Return non-nil when the item becomes marked, nil when unmarked.  Marks
do not invoke selection or commit callbacks.  SESSION defaults to the
current buffer's workspace.  If rendering fails, retain the prior marks."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (item (emacs-tui-current-item session)))
    (unless (and (emacs-tui--view-multi-select view)
                 (not (emacs-tui--view-text view)))
      (user-error "This view does not support marks"))
    (unless item (user-error "No selected item"))
    (let* ((marks (if (emacs-tui--view-marks view)
                      (copy-hash-table (emacs-tui--view-marks view))
                    (make-hash-table :test #'equal)))
           (id (emacs-tui--item-id item))
           (marked (not (gethash id marks))))
      (if marked (puthash id t marks) (remhash id marks))
      (emacs-tui--set-marks session view marks)
      marked)))

(defun emacs-tui--mark-projection (session id invert)
  "Mark SESSION's view ID projection, or toggle it when INVERT is non-nil."
  (setq session (emacs-tui--require-session session))
  (let ((view (emacs-tui--resolve-view session id)))
    (unless (and (emacs-tui--view-multi-select view)
                 (not (emacs-tui--view-text view)))
      (user-error "This view does not support marks"))
    (when (emacs-tui--view-visible-items view)
      (let ((table (if (emacs-tui--view-marks view)
                       (copy-hash-table (emacs-tui--view-marks view))
                     (make-hash-table :test #'equal))))
        (dolist (item (emacs-tui--view-visible-items view))
          (let ((identity (emacs-tui--item-id item)))
            (if (and invert (gethash identity table))
                (remhash identity table)
              (puthash identity t table))))
        (emacs-tui--set-marks session view table))))
  nil)

(defun emacs-tui-mark-all (&optional session id)
  "Mark every projected item in SESSION's multi-select view ID.
SESSION defaults to the current interface, and ID to its focused view.
Include off-screen rows in the current list/table/tree projection, but exclude
filtered items and collapsed descendants.  Retain their existing marks.
A named hidden panel uses its current projection without taking focus.
Preserve selection and queries; invoke no application action or commit.
Render once after staging all changes; a rendering error retains prior marks.
An empty projection is unchanged.  Return nil."
  (interactive)
  (emacs-tui--mark-projection session id nil))

(defun emacs-tui-invert-marks (&optional session id)
  "Toggle every projected item's mark in SESSION's multi-select view ID.
SESSION and ID default to the current interface and its focused view.
Use the same projection and failure behavior as `emacs-tui-mark-all': retain
marks on filtered items and collapsed descendants, and leave selection,
queries, focus and application data unchanged.  Return nil."
  (interactive)
  (emacs-tui--mark-projection session id t))

(defun emacs-tui-clear-marks (&optional session id)
  "Clear the marked state of SESSION's view ID, including hidden items.
SESSION defaults to the current buffer's workspace, and ID defaults to
its focused view.  Ordinary views are unchanged.  Return nil.
If rendering fails, retain all prior marks, including hidden items."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let ((view (emacs-tui--resolve-view session id)))
    (when (emacs-tui--view-marks view)
      (emacs-tui--set-marks session view nil)))
  nil)

(defun emacs-tui-query (&optional session id)
  "Return SESSION's workspace query, or the effective query of view ID.
Without ID, return the ephemeral query string, or an empty string for a
persistent interface.  A view's local query overrides the workspace query;
nil local state inherits it.  Use `emacs-tui-set-query' to set an override."
  (setq session (emacs-tui--require-session session))
  (or (and id (emacs-tui--view-query (emacs-tui--resolve-view session id)))
      (let ((query (emacs-tui--workspace-query-buffer session)))
        (if query
            (with-current-buffer query
              (buffer-substring-no-properties (point-min) (point-max)))
          ""))))

(defun emacs-tui-set-query (session id query)
  "Set SESSION's view ID to local literal QUERY and return SESSION.
Nil ID means the focused view.  QUERY is a string; nil removes the override
and inherits the workspace query.  An empty string disables query filtering.
Match whitespace-separated terms case-insensitively against labels and table
values, or reveal matching tree paths.  Retain source data, sort, hidden marks
and surviving visible selection.  Updates keep the local override.
Local filtering also applies to provider/application-owned results without
invoking callbacks, restarting providers or changing their workspace query.
Text previews and editable fields are not filter targets.  Input callbacks
can filter another view without replacing its source items."
  (setq session (emacs-tui--require-session session))
  (unless (or (null query) (stringp query))
    (error "QUERY must be a string or nil"))
  (let* ((view (emacs-tui--resolve-view session id))
         (candidate (copy-emacs-tui--view view)))
    (when (emacs-tui--view-text view)
      (user-error "Text and input views cannot be filtered"))
    (setf (emacs-tui--view-query candidate) query)
    (emacs-tui--filter session candidate)
    (emacs-tui--render-view session candidate)
    (setf (emacs-tui--view-query view) query
          (emacs-tui--view-visible-items view) (emacs-tui--view-visible-items candidate)
          (emacs-tui--view-selected view) (emacs-tui--view-selected candidate)
          (emacs-tui--view-tree-open view) (emacs-tui--view-tree-open candidate)
          (emacs-tui--view-tree-search view) (emacs-tui--view-tree-search candidate)))
  session)

(defun emacs-tui--filter (session view)
  "Update VIEW's visible items for SESSION, preserving stable selection."
  (let* ((old (nth (emacs-tui--view-selected view)
                   (emacs-tui--view-visible-items view)))
         (local-query (emacs-tui--view-query view))
         (application-query (and (null local-query)
                                 (or (emacs-tui--workspace-on-query session)
                                     (emacs-tui--workspace-provider session))))
         (terms (split-string (or local-query (emacs-tui-query session)) nil t))
         (case-fold-search t)
         (tree-terms (unless application-query terms))
         (projection (when (emacs-tui--view-tree view)
                       (emacs-tui--tree-project (emacs-tui--view-tree view) tree-terms)))
         (items
          (if projection (car projection)
            (if (or application-query (null terms))
		(emacs-tui--view-items view)
              ;; Snapshot pure projections once for this search, not per term.
              ;; Rebuild on every filter operation so new values stay visible.
              (let ((patterns (mapcar #'regexp-quote terms)))
                (cl-remove-if-not
                 (lambda (item)
                   (let ((text
                          (concat (emacs-tui--item-label item)
                                  (when (emacs-tui--view-columns view)
                                    (concat " "
                                            (mapconcat
                                             (lambda (column)
                                               (emacs-tui--cell-text
                                                (emacs-tui--table-value column item)))
                                             (emacs-tui--view-columns view) " "))))))
                     (cl-every (lambda (pattern) (string-match-p pattern text)) patterns)))
                 (emacs-tui--view-items view)))))))
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
          (replace-regexp-in-string "%" (lambda (match) (concat match match))
                                    (emacs-tui--view-title view) t t)
          (when (emacs-tui--workspace-maximized session) " | maximized")
          (when (emacs-tui--view-actions view)
            (if (emacs-tui--view-editable view) " | C-c C-a actions" " | a actions"))
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
Return (CONTENT POSITION ROW-RANGES).  Projection errors leave display intact."
  (if (emacs-tui--view-text view)
      (list (emacs-tui--view-text view) 1 nil)
    (let* ((window (emacs-tui--view-window view))
           (mark-width (if (emacs-tui--view-multi-select view) 4 0))
           (columns (emacs-tui--table-resolve-columns
                     (emacs-tui--view-columns view)
                     (when (window-live-p window)
                       ;; Account for native continuation/truncation indicator
                       ;; space and font width.
                       (- (window-max-chars-per-line window) mark-width))))
          (position 1) (selected-position 1) chunks ranges)
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
                   (setq selected-position position))
                 (push (cons position (+ position (length line))) ranges)
                 (push (concat line "\n") chunks)
                 (cl-incf position (1+ (length line)))))
      (list (apply #'concat (nreverse chunks)) selected-position
            (vconcat (nreverse ranges))))))

(defun emacs-tui--highlight-row (index)
  "Move the current view buffer's selection highlight to row INDEX."
  (if (and emacs-tui--row-ranges (< index (length emacs-tui--row-ranges)))
      (let ((range (aref emacs-tui--row-ranges index)))
        (unless (overlayp emacs-tui--selection-overlay)
          (setq emacs-tui--selection-overlay (make-overlay 1 1))
          (overlay-put emacs-tui--selection-overlay 'face 'emacs-tui-selection))
        (move-overlay emacs-tui--selection-overlay (car range) (cdr range) (current-buffer)))
    (when (overlayp emacs-tui--selection-overlay)
      (delete-overlay emacs-tui--selection-overlay))))

(defun emacs-tui--render-view (session view)
  "Render VIEW in SESSION without replacing its buffer or window.
Prepare application projections before changing any displayed content."
  ;; Once mounted, a live input buffer is authoritative.  Initial rendering
  ;; must still use its supplied value, and staged copies from explicit updates
  ;; must retain their replacement text rather than reading the old buffer.
  (when (and (memq session emacs-tui--sessions)
             (memq view (emacs-tui--workspace-views session)))
    (emacs-tui--capture-input view))
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
            (let ((old-start (and (overlayp emacs-tui--selection-overlay)
                                  (overlay-start emacs-tui--selection-overlay)))
                  (old-end (and (overlayp emacs-tui--selection-overlay)
                                (overlay-end emacs-tui--selection-overlay)))
                  completed)
              (unwind-protect
                  (progn
                    (atomic-change-group
                      (erase-buffer)
                      (insert (car content))
                      (goto-char (cadr content)))
                    (setq completed t))
                ;; Text rollback does not promise to restore overlay marker bounds.
                (when (and (not completed) old-start old-end (buffer-live-p buffer))
                  (move-overlay emacs-tui--selection-overlay old-start old-end buffer))))
            (setq emacs-tui--row-ranges (nth 2 content)
                  emacs-tui--row-items (emacs-tui--view-visible-items view)
                  emacs-tui--row-tick (buffer-chars-modified-tick))
            (emacs-tui--highlight-row (emacs-tui--view-selected view))
            (set-buffer-modified-p nil)
            (when (nth 4 (emacs-tui--view-display-state view))
              (let ((window (emacs-tui--view-window view)))
                (when (and (window-live-p window) (eq (window-buffer window) buffer))
                  (with-selected-window window
                    (scroll-right (window-hscroll window) t))))
              (setf (emacs-tui--view-display-state view) nil))
            (when (emacs-tui--view-text view)
              (setf (emacs-tui--view-display-state view) nil))
            (when (emacs-tui--view-editable view)
              (buffer-disable-undo)
              (buffer-enable-undo))
            (let ((window (emacs-tui--view-window view)))
              (when (and (window-live-p window) (eq (window-buffer window) buffer))
                (set-window-point window (point)))))
          ;; A list can become a preview whose text already equals the buffer.
          ;; Retire list display state even when no character replacement is needed.
          (when (emacs-tui--view-text view)
            (setq emacs-tui--row-ranges nil emacs-tui--row-items nil emacs-tui--row-tick nil)
            (when (overlayp emacs-tui--selection-overlay)
              (delete-overlay emacs-tui--selection-overlay)))
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
                                    (text nil text-p) (title nil title-p))
  "Update SESSION's view ID, reusing its display resources.
Supplying ITEMS, including nil, replaces its source items.  Supplying
TEXT, including nil, replaces or clears the preview.  Omitted fields
are unchanged.  Marks survive by identity while the identity remains
in ITEMS; non-nil TEXT clears marks.  Multi-select item identities must
be unique.  Identical preview text, including properties, retains its reading
position; changed text starts at the beginning.  Editable views accept only
string TEXT updates; changed values reset undo without calling ON-CHANGE.
Tree ITEMS are root snapshots; descendants are indexed through CHILDREN.
Non-nil TEXT is rejected for trees.
TITLE, when supplied, must be a string (empty clears it).  Title-only updates
change the header without filtering, projecting or editing view contents.
Combined updates commit the title only after successful rendering.
Return SESSION."
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
    (when (and title-p (not (stringp title)))
      (error "TITLE must be a string"))
    (emacs-tui--capture-input view)
    (let ((candidate (copy-emacs-tui--view view)))
      (when title-p (setf (emacs-tui--view-title candidate) title))
      (when items-p
        (when (emacs-tui--view-tree view)
          (let ((data (emacs-tui--tree-index items (emacs-tui--view-children view)
                                             (emacs-tui--view-tree view))))
            (setf (emacs-tui--view-tree candidate) data)
            (setq items (emacs-tui--tree-data-items data))))
        (setf (emacs-tui--view-items candidate) items))
      (when text-p (setf (emacs-tui--view-text candidate) text))
      (if (and title-p (not items-p) (not text-p))
          (with-current-buffer (emacs-tui--view-buffer view)
            (setq header-line-format (emacs-tui--view-header session candidate)))
        (progn
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
          (emacs-tui--render-view session candidate)))
      (setf (emacs-tui--view-title view) (emacs-tui--view-title candidate)
            (emacs-tui--view-items view) (emacs-tui--view-items candidate)
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

(defun emacs-tui--tty-child-p (session)
  "Whether SESSION has a live native terminal child frame."
  (let ((frame (emacs-tui--workspace-frame session)))
    (and (not (emacs-tui--workspace-popup session))
         (frame-live-p frame) (not (display-graphic-p frame)))))

(defun emacs-tui--remember-tty-focus ()
  "Remember each terminal's last explicitly selected interface frame."
  (let ((selected (selected-frame)))
    (dolist (session emacs-tui--sessions)
      (when (and (emacs-tui--tty-child-p session)
                 (eq (frame-terminal selected)
                     (frame-terminal (emacs-tui--workspace-frame session))))
        (setf (emacs-tui--workspace-tty-focus session)
              (and (eq selected (emacs-tui--workspace-frame session))
                   (not (emacs-tui--workspace-popup session))
                   (emacs-tui--subtree session) t))))))

(defun emacs-tui--track-tty-focus ()
  "Observe command completion after restoring any implicit deletion fallback."
  (emacs-tui--consume-tty-deletions)
  (emacs-tui--remember-tty-focus))

(defun emacs-tui--frame-below-p (frame ancestor)
  "Whether live FRAME is ANCESTOR or one of its descendants."
  (while (and (frame-live-p frame) (not (eq frame ancestor)))
    (setq frame (frame-parent frame)))
  (and (frame-live-p frame) (eq frame ancestor)))

(defun emacs-tui--tty-switch-frame (arguments)
  "Restore owned terminal child focus in switch-frame ARGUMENTS.
Emacs assigns input on a returning terminal to its top-level frame when
another terminal is selected.  Preserve that terminal's last interface
focus, including nested children.  Explicit selection within one terminal
and invalidated surfaces retain normal Emacs routing."
  (let* ((event (car arguments))
         (target (and (consp event) (eq (car event) 'switch-frame) (cadr event)))
         (selected (selected-frame))
         (session
          (when (and (frame-live-p target) (not (display-graphic-p target))
                     (not (eq (frame-terminal target) (frame-terminal selected))))
            (cl-find-if
             (lambda (app)
               (and (emacs-tui--workspace-tty-focus app)
                    (emacs-tui--tty-child-p app)
                    (eq (frame-terminal target)
                        (frame-terminal (emacs-tui--workspace-frame app)))
                    (emacs-tui--frame-below-p (emacs-tui--workspace-frame app) target)
                    (emacs-tui--subtree app)))
             emacs-tui--sessions))))
    (if session
        (cons (list 'switch-frame (emacs-tui--workspace-frame session)) (cdr arguments))
      arguments)))

(defun emacs-tui--restore-tty-focus (session)
  "Restore a remembered owned ancestor when SESSION's child closes.
Do not select a frame or resurrect focus after explicit parent selection."
  (when (emacs-tui--workspace-tty-focus session)
    (let ((parent (emacs-tui--workspace-origin-frame session)))
      (dolist (app emacs-tui--sessions)
        (when (and (emacs-tui--tty-child-p app)
                   (eq parent (emacs-tui--workspace-frame app))
                   (emacs-tui--subtree app))
          (setf (emacs-tui--workspace-tty-focus app) t))))))

(defvar emacs-tui--tty-deleting-frames nil
  "Frames being deleted and their previously selected frame.")

(defun emacs-tui--tty-frame-deleting (frame)
  "Remember native selection before deleting live FRAME."
  (when (and (cl-some #'emacs-tui--tty-child-p emacs-tui--sessions)
             (frame-live-p frame) (not (assq frame emacs-tui--tty-deleting-frames)))
    (push (list frame (selected-frame)
                (emacs-tui--frame-below-p (selected-frame) frame))
          emacs-tui--tty-deleting-frames)))

(defun emacs-tui--restore-tty-survivor ()
  "Restore a remembered owned child below the selected fallback frame.
Return non-nil only after changing native focus.  Explicit parent selection,
an already selected child and invalidated or graphical surfaces are unchanged."
  (let* ((selected (selected-frame))
         (app
          (when (and (frame-live-p selected) (not (display-graphic-p selected)))
            (cl-find-if
             (lambda (session)
               (and (emacs-tui--workspace-tty-focus session)
                    (emacs-tui--tty-child-p session)
                    (not (eq (emacs-tui--workspace-frame session) selected))
                    (emacs-tui--frame-below-p
                     (emacs-tui--workspace-frame session) selected)
                    (emacs-tui--subtree session)))
             emacs-tui--sessions))))
    (when app
      (select-window (frame-selected-window (emacs-tui--workspace-frame app)))
      t)))

(defun emacs-tui--restore-tty-deletion (entry)
  "Restore an owned survivor for recorded deletion ENTRY, once.
Do not change focus for a background deletion or an explicit parent choice."
  (when (and (nth 2 entry) (not (eq (nth 1 entry) (selected-frame))))
    (emacs-tui--restore-tty-survivor)))

(defun emacs-tui--consume-tty-deletions ()
  "Consume completed deletions before recording implicit fallback focus.
Emacs can defer frame hooks until after the command's post-command hooks."
  (let ((dead (cl-remove-if (lambda (entry) (frame-live-p (car entry)))
                            emacs-tui--tty-deleting-frames)))
    (setq emacs-tui--tty-deleting-frames
          (cl-set-difference emacs-tui--tty-deleting-frames dead :test #'eq))
    (cl-some #'emacs-tui--restore-tty-deletion dead)))

(defun emacs-tui--tty-terminal-deleting (terminal)
  "Capture live frames before an ordinary server deletes TERMINAL.
Server client disposal can defer both frame hooks until frames are dead."
  (dolist (frame (frame-list))
    (when (and (frame-live-p frame) (eq terminal (frame-terminal frame)))
      (emacs-tui--tty-frame-deleting frame))))

(defun emacs-tui--tty-frame-deleted (frame)
  "Preserve a surviving terminal interface after deleting FRAME."
  (let ((entry (assq frame emacs-tui--tty-deleting-frames)))
    (setq emacs-tui--tty-deleting-frames (delq entry emacs-tui--tty-deleting-frames))
    (when (emacs-tui--restore-tty-deletion entry)
      (emacs-tui--track-tty-focus))))

(defun emacs-tui--sync-tty-focus-hooks ()
  "Install terminal routing only while native terminal interfaces are live."
  (if (cl-some #'emacs-tui--tty-child-p emacs-tui--sessions)
      (progn
        (add-hook 'post-command-hook #'emacs-tui--track-tty-focus)
        (add-hook 'delete-frame-functions #'emacs-tui--tty-frame-deleting t)
        (add-hook 'after-delete-frame-functions #'emacs-tui--tty-frame-deleted)
        (add-hook 'delete-terminal-functions #'emacs-tui--tty-terminal-deleting t)
        (unless (advice-member-p #'emacs-tui--tty-switch-frame #'handle-switch-frame)
          (advice-add #'handle-switch-frame :filter-args #'emacs-tui--tty-switch-frame)))
    (remove-hook 'post-command-hook #'emacs-tui--track-tty-focus)
    (remove-hook 'delete-frame-functions #'emacs-tui--tty-frame-deleting)
    (remove-hook 'after-delete-frame-functions #'emacs-tui--tty-frame-deleted)
    (remove-hook 'delete-terminal-functions #'emacs-tui--tty-terminal-deleting)
    (setq emacs-tui--tty-deleting-frames nil)
    (advice-remove #'handle-switch-frame #'emacs-tui--tty-switch-frame)))

(defun emacs-tui-popup-supported-p (&optional window)
  "Whether WINDOW's display supports popups without changing host windows.
WINDOW defaults to the selected window.  Graphical child frames and displays
advertising `tty-child-frames' are supported.  Older terminals do not fall
back to split windows, since that would alter the host layout."
  (setq window (or window (selected-window)))
  (and (not noninteractive) (window-live-p window)
       (or (display-graphic-p (window-frame window)) (featurep 'tty-child-frames))))

(defun emacs-tui--popup-source-valid-p (session)
  "Whether SESSION's popup still has its original visible source buffer."
  (let* ((popup (emacs-tui--workspace-popup session))
         (window (emacs-tui--workspace-origin-window session))
         (buffer (emacs-tui--popup-buffer popup))
         (parent (emacs-tui--workspace-origin-frame session))
         (child (emacs-tui--workspace-frame session)))
    (and (window-live-p window) (buffer-live-p buffer)
         (eq (window-buffer window) buffer) (eq (window-frame window) parent)
         (or (null child)
             (and (frame-live-p child) (eq (frame-parent child) parent)
                  (eq (frame-terminal child) (frame-terminal parent))))
         (eq (marker-buffer (emacs-tui--popup-begin popup)) buffer)
         (eq (marker-buffer (emacs-tui--popup-end popup)) buffer)
         (with-current-buffer buffer
           (<= (point-min) (emacs-tui--popup-begin popup)
               (emacs-tui--popup-end popup) (point-max))))))

(defun emacs-tui--popup-anchor (session)
  "Return SESSION's visible anchor as a parent-relative pixel rectangle.
A range on one visual line uses exclusive endpoint coordinates.  Wrapped or
partially hidden ranges use the glyph at the source window's point instead."
  (unless (emacs-tui--popup-source-valid-p session)
    (error "Popup source is no longer available"))
  (let* ((popup (emacs-tui--workspace-popup session))
         (window (emacs-tui--workspace-origin-window session))
         (parent (window-frame window))
         (begin (marker-position (emacs-tui--popup-begin popup)))
         (end (marker-position (emacs-tui--popup-end popup)))
         (first (posn-at-point begin window))
         (after (posn-at-point end window))
         (point (posn-at-point (window-point window) window))
         (edges (window-inside-pixel-edges window)) width)
    (unless point (error "Popup anchor is offscreen"))
    (if (and first after (< begin end)
             (= (cdr (posn-x-y first)) (cdr (posn-x-y after)))
             (<= 0 (car (posn-x-y first)) (car (posn-x-y after))
                 (window-body-width window t))
             (> (car (posn-x-y after)) (car (posn-x-y first))))
        (setq width (- (car (posn-x-y after)) (car (posn-x-y first))))
      (setq first point)
      (let* ((at (window-point window))
             (next (with-current-buffer (window-buffer window) (min (point-max) (1+ at))))
             (size (window-text-pixel-size window at next nil
                                           (* 2 (frame-char-height parent)))))
        (setq width (max (frame-char-width parent) (car size)))))
    (let* ((xy (posn-x-y first))
           (height (cdr (posn-object-width-height first))))
      (list (+ (car edges) (car xy)) (+ (cadr edges) (cdr xy)) width
            (max (frame-char-height parent) (or height 0))))))

(defun emacs-tui--fit-popup (session)
  "Fit SESSION's popup around its visible source anchor without selecting it."
  (let* ((popup (emacs-tui--workspace-popup session))
         (parent (emacs-tui--workspace-origin-frame session))
         (child (emacs-tui--workspace-frame session))
         (cw (frame-char-width child)) (ch (frame-char-height child))
         (pw (frame-inner-width parent)) (ph (frame-inner-height parent))
         (columns (min (emacs-tui--popup-width popup) (/ pw cw)))
         (rows (min (emacs-tui--popup-height popup) (/ ph ch))))
    (when (or (< columns 2) (< rows 2)) (error "No space for the popup"))
    (unless (and (= columns (frame-width child)) (= rows (frame-height child)))
      (let ((frame-resize-pixelwise t)) (set-frame-size child columns rows)))
    (when (or (> (frame-pixel-width child) pw) (> (frame-pixel-height child) ph))
      (error "Display minimum popup size exceeds the parent viewport"))
    (let ((rect (emacs-tui-layout-popup
                 (emacs-tui--popup-anchor session)
                 (frame-pixel-width child) (frame-pixel-height child)
                 (list 0 0 pw ph) (emacs-tui--popup-position popup)
                 (cons (frame-char-width parent) (frame-char-height parent)))))
      (unless (and (equal (cons (car rect) (cadr rect)) (frame-position child))
                   (equal (car rect) (frame-parameter child 'left))
                   (equal (cadr rect) (frame-parameter child 'top)))
        ;; The parameter setter also invalidates native TTY composition and
        ;; keeps reported parameters in sync with the internal coordinates.
        (modify-frame-parameters child `((left . ,(car rect)) (top . ,(cadr rect))))))))

(defun emacs-tui--make-popup-surface (session)
  "Create SESSION's single popup child frame without touching the host layout."
  (let* ((parent (emacs-tui--workspace-origin-frame session))
         (popup (emacs-tui--workspace-popup session))
         (parameters
          `((parent-frame . ,parent) (minibuffer . ,(minibuffer-window parent))
            (left . 0) (top . 0) (width . ,(min (emacs-tui--popup-width popup)
                           (max 2 (/ (frame-inner-width parent) (frame-char-width parent)))))
            (height . ,(min (emacs-tui--popup-height popup)
                            (max 2 (/ (frame-inner-height parent) (frame-char-height parent))))) (min-width . 2) (min-height . 2)
            (undecorated . t) (visibility . nil) (no-focus-on-map . t)
            (menu-bar-lines . 0) (tool-bar-lines . 0) (tab-bar-lines . 0)
            (internal-border-width . 0) (left-fringe . 0) (right-fringe . 0)
            (vertical-scroll-bars . nil) (horizontal-scroll-bars . nil))))
    (save-selected-window
      (let ((child (make-frame (if (display-graphic-p parent)
                                  (cons '(no-accept-focus . t) parameters)
                                parameters))))
        ;; Record ownership before any operation which can fail or run hooks.
        (setf (emacs-tui--workspace-frame session) child
              (emacs-tui--workspace-root session) (frame-root-window child)
              (emacs-tui--workspace-backend session) 'popup)
        (condition-case nil (redirect-frame-focus child parent) (error nil))
        (emacs-tui--fit-popup session)
        (make-frame-visible child)))))

(defun emacs-tui--popup-terminal-deleted (terminal)
  "Dispose popups belonging to TERMINAL before its frame handles expire."
  (dolist (session (copy-sequence emacs-tui--sessions))
    (when-let* ((popup (emacs-tui--workspace-popup session)))
      (when (eq terminal (emacs-tui--popup-terminal popup))
        (emacs-tui-close session)))))

(defun emacs-tui--popup-switch-frame (arguments)
  "Keep graphical read-only popup events in ARGUMENTS at their source.
Native focus events can outlive temporary preview selection or resizing.
Only redirect an exact owned popup while its source is still selected;
foreign events and invalidated surfaces retain normal Emacs routing."
  (let* ((event (car-safe arguments))
         (target (and (consp event) (eq (car event) 'switch-frame)
                      (consp (cdr event)) (null (cddr event)) (cadr event)))
         (session
          (when (and (frame-live-p target) (display-graphic-p target))
            (cl-find-if
             (lambda (app)
               (and (emacs-tui--workspace-active app)
                    (emacs-tui--workspace-popup app)
                    (eq target (emacs-tui--workspace-frame app))
                    (eq (selected-window) (emacs-tui--workspace-origin-window app))
                    (emacs-tui--subtree app)))
             emacs-tui--sessions))))
    (if session
        (cons (list 'switch-frame (emacs-tui--workspace-origin-frame session))
              (cdr arguments))
      arguments)))

(defun emacs-tui--sync-popup-focus-hook ()
  "Route native focus events only while graphical popups are live."
  (if (cl-some (lambda (app)
                 (let ((frame (emacs-tui--workspace-frame app)))
                   (and (emacs-tui--workspace-active app)
                        (emacs-tui--workspace-popup app)
                        (frame-live-p frame) (display-graphic-p frame))))
               emacs-tui--sessions)
      (unless (advice-member-p #'emacs-tui--popup-switch-frame #'handle-switch-frame)
        (advice-add #'handle-switch-frame :filter-args #'emacs-tui--popup-switch-frame))
    (advice-remove #'handle-switch-frame #'emacs-tui--popup-switch-frame)))

(defun emacs-tui--popup-post-command ()
  "Follow visible popup anchors, closing popups when their source is left."
  (unless emacs-tui--refreshing
    (dolist (session (copy-sequence emacs-tui--sessions))
      (when (emacs-tui--workspace-popup session)
        (if (or (not (emacs-tui--popup-source-valid-p session))
                (not (eq (selected-window) (emacs-tui--workspace-origin-window session))))
            (emacs-tui-close session)
          (condition-case nil
              (progn
                (redisplay t)
                (unless (equal (emacs-tui--workspace-geometry session)
                               (emacs-tui--geometry session))
                  (emacs-tui-refresh session)))
            (error (emacs-tui-close session))))))))

(cl-defun emacs-tui-popup (&key view (window (selected-window)) begin end
                              (position 'south-west) (width 32) (height 8) on-close)
  "Show VIEW around BEGIN..END in WINDOW, retaining source input focus.
WINDOW must be the selected input window; presentation leaves its buffer and
layout intact.  BEGIN and END default to WINDOW's point and track source edits.
Single-visual-line ranges anchor around the whole range; wrapped/hidden ranges
anchor at point.
POSITION is one of `emacs-tui-layout-popup-positions'.  WIDTH and HEIGHT are
requested child-frame columns/rows, including the header.  Edges are clamped to
the parent; constrained positions can coincide or overlap the anchor.
VIEW must be read-only.  Applications keep typing in their own source buffer,
publish candidates with `emacs-tui-update', navigate with `emacs-tui-next-item'
and accept with `emacs-tui-select', passing the returned session explicitly.
Use `emacs-tui-reposition-popup' to move it.  No completion effects or keymaps
are installed in the host.  Leaving, killing or repurposing the source closes
the popup.  ON-CLOSE follows `emacs-tui-mount'.  Native child frames are
required; unsupported terminals signal an error without changing the host."
  (unless (and (window-live-p window) (not (window-minibuffer-p window))
               (eq window (selected-window)))
    (user-error "A popup needs the selected live source window"))
  (unless (emacs-tui-popup-supported-p window)
    (user-error "Popups require graphical or native TTY child frames"))
  (unless (and (emacs-tui--view-p view) (not (emacs-tui--view-editable view))
               (memq position emacs-tui-layout-popup-positions)
               (integerp width) (>= width 2) (integerp height) (>= height 2))
    (error "Invalid popup view, position or dimensions"))
  (let* ((buffer (window-buffer window))
         (begin (or begin (window-point window)))
         (end (or end (window-point window))) popup ready)
    (with-current-buffer buffer
      (unless (and (integer-or-marker-p begin) (integer-or-marker-p end)
                   (<= (point-min) begin end (point-max))
                   (cl-every (lambda (pos) (or (not (markerp pos))
                                               (eq (marker-buffer pos) buffer)))
                             (list begin end)))
        (error "Popup bounds must belong to the source buffer"))
      (setq popup (emacs-tui--make-popup
                   :buffer buffer :begin (copy-marker begin) :end (copy-marker end t)
                   :position position :width width :height height
                   :terminal (frame-terminal (window-frame window)))))
    (unwind-protect
        (prog1 (progn
                 (redisplay t)
                 (emacs-tui--create :views (list view) :layout 'columns
                                    :backend 'child-frame :popup popup :debounce 0.08
                                    :on-close on-close))
          (setq ready t))
      (unless ready
        (set-marker (emacs-tui--popup-begin popup) nil)
        (set-marker (emacs-tui--popup-end popup) nil)))))

(defun emacs-tui-reposition-popup (session &optional position)
  "Move SESSION's popup to POSITION, or cycle clockwise when omitted.
Retain source input, candidate selection and marks.  Return the requested
position symbol.  Near edges native viewport clamping can limit movement.
Reject calls made during reflow before changing the requested position."
  (setq session (emacs-tui--require-session session))
  (when emacs-tui--refreshing
    (user-error "Cannot move a popup during reflow"))
  (let ((popup (emacs-tui--workspace-popup session)))
    (unless popup (user-error "This session is not an anchored popup"))
    (setq position
          (or position
              (nth (mod (1+ (cl-position (emacs-tui--popup-position popup)
                                         emacs-tui-layout-popup-positions)) 8)
                   emacs-tui-layout-popup-positions)))
    (unless (memq position emacs-tui-layout-popup-positions)
      (error "Unknown popup position: %S" position))
    (setf (emacs-tui--popup-position popup) position)
    (unless (emacs-tui--reflow session t) (user-error "Popup is no longer available"))
    position))

(defun emacs-tui-resize-popup (session width height)
  "Request WIDTH columns and HEIGHT rows for SESSION's existing popup.
Both dimensions must be integers of at least two, including the header.
Native viewport clamping may limit the actual size.  Retain source focus,
placement, selection and marks; refit and reflow the existing child frame.
Reject nested reflow before changing dimensions.  A failed native fit closes
the popup using the usual cleanup policy.  Return SESSION on success."
  (unless (and (integerp width) (>= width 2) (integerp height) (>= height 2))
    (error "Popup dimensions must be integers of at least two"))
  (setq session (emacs-tui--require-session session))
  (when emacs-tui--refreshing (user-error "Cannot resize a popup during reflow"))
  (let ((popup (emacs-tui--workspace-popup session)))
    (unless popup (user-error "This session is not an anchored popup"))
    (setf (emacs-tui--popup-width popup) width
          (emacs-tui--popup-height popup) height)
    (unless (emacs-tui--reflow session t) (user-error "Popup is no longer available")))
  session)

(defun emacs-tui--fit-workspace-child (session)
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

(defun emacs-tui--fit-child (session)
  "Fit SESSION's child frame according to its presentation policy."
  (if (emacs-tui--workspace-popup session)
      (emacs-tui--fit-popup session)
    (emacs-tui--fit-workspace-child session)))

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
               (or (null (emacs-tui--workspace-popup session))
                   (emacs-tui--popup-source-valid-p session))
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
          (when (emacs-tui--workspace-popup session)
            (list (window-edges (emacs-tui--workspace-origin-window session))
                  (emacs-tui--popup-anchor session)
                  (frame-position (emacs-tui--workspace-frame session))
                  (emacs-tui--popup-viewport session)))
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
                  (window-hscroll window) (window-vscroll window t)
                  (nth 4 (emacs-tui--view-display-state view)))))))

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
          ;; Native buffer installation clears the manual horizontal minimum.
          ;; Restore only a minimum explicitly requested through our scroll API.
          (when (nth 4 state)
            (set-window-hscroll window (nth 4 state))
            (with-selected-window window (scroll-left 0 t)))
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
  (unless (or (emacs-tui--workspace-query-buffer session)
              (emacs-tui--workspace-popup session))
    (let ((window (emacs-tui--view-window (emacs-tui--focused-view session))))
      (when (window-live-p window)
        (select-window window)
        (emacs-tui--remember-tty-focus)))))

(defun emacs-tui-refresh (&optional session)
  "Reflow SESSION safely, preserving its query and logical selection.
This is normally automatic after window or frame geometry changes.
Return SESSION on success, or nil after closing an invalidated surface.
No application provider or commit callback is invoked."
  (interactive)
  (emacs-tui--reflow (emacs-tui--require-session session)))

(defun emacs-tui--popup-viewport (session)
  "Return the content viewport of SESSION's existing popup."
  (let ((window (emacs-tui--workspace-root session))
        (frame (emacs-tui--workspace-frame session)))
    (list (window-inside-pixel-edges window)
          (window-max-chars-per-line window)
          (frame-char-height frame))))

(defun emacs-tui--reflow (session &optional moving-popup)
  "Reflow live SESSION, optionally preserving content while MOVING-POPUP.
Only a previously current popup with an unchanged fitted content viewport
can retain its rendered rows.  Explicit public refresh always renders."
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
                       (window-point (window-point root))
                       (viewport
                        (when (and moving-popup (emacs-tui--workspace-popup session)
                                   (emacs-tui--workspace-frame session)
                                   (equal (emacs-tui--workspace-geometry session)
                                          (emacs-tui--geometry session)))
                          (emacs-tui--popup-viewport session))))
                  (mapc #'emacs-tui--remember-view (emacs-tui--workspace-views session))
                  (save-selected-window
                    (when (emacs-tui--workspace-frame session)
                      (emacs-tui--fit-child session))
                    (unless (and viewport
                                 (equal viewport (emacs-tui--popup-viewport session)))
                      (emacs-tui--arrange session))
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
query edits; it replaces workspace-query substring matching.  Explicit local
view filters still apply.
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
                                  provider debounce on-close ephemeral host-window keymap popup)
  "Create views and resources shared by both interface lifecycles.
VIEWS, LAYOUT, BACKEND, ON-QUERY, ON-COMMIT, PROVIDER, DEBOUNCE and
ON-CLOSE specify configuration.  POPUP optionally configures an anchored
read-only presentation.  EPHEMERAL enables query input and
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
           :active t :popup popup))
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
            (if popup (emacs-tui--make-popup-surface session)
              (emacs-tui--make-surface session backend)))
          (emacs-tui--arrange session)
          (setf (emacs-tui--workspace-geometry session) (emacs-tui--geometry session))
          (push session emacs-tui--sessions)
          (add-hook 'delete-frame-functions #'emacs-tui--frame-deleted)
          (add-hook 'window-state-change-hook #'emacs-tui--window-state-changed)
          (emacs-tui--sync-tty-focus-hooks)
          (emacs-tui--sync-popup-focus-hook)
          (when (or ephemeral popup)
            (let ((hook (lambda () (emacs-tui-close session))))
              (setf (emacs-tui--workspace-origin-kill-hook session) hook)
              (with-current-buffer (if popup (emacs-tui--popup-buffer popup)
                                     (marker-buffer (emacs-tui--workspace-origin session)))
                (add-hook 'kill-buffer-hook hook nil t))))
          (when popup
            (add-hook 'post-command-hook #'emacs-tui--popup-post-command)
            (add-hook 'delete-terminal-functions #'emacs-tui--popup-terminal-deleted))
          (unless popup (select-window (emacs-tui--workspace-root session)))
          (emacs-tui--focus-window session)
          (with-current-buffer (or query (emacs-tui--view-buffer
                                          (emacs-tui--focused-view session)))
            (emacs-tui--query-changed 'initial))
          (emacs-tui--remember-tty-focus)
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
      (let ((restore-survivor
             (and (eq (emacs-tui--workspace-backend session) 'child-frame)
                  (emacs-tui--workspace-tty-focus session))))
        ;; Emacs owns deletion of this frame and all descendant windows.  Do
        ;; not mutate a dying subtree, including when hooks were deferred.
        (setf (emacs-tui--workspace-frame session) nil
              (emacs-tui--workspace-windows session) nil)
        (emacs-tui-close session)
        ;; Some server implementations report abrupt terminal loss only after
        ;; native fallback selected a surviving terminal's top-level frame.
        (when (and restore-survivor (emacs-tui--restore-tty-survivor))
          (emacs-tui--track-tty-focus))))))

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
    (emacs-tui--restore-tty-focus session)
    (when-let* ((popup (emacs-tui--workspace-popup session)))
      (when (buffer-live-p (emacs-tui--popup-buffer popup))
        (with-current-buffer (emacs-tui--popup-buffer popup)
          (remove-hook 'kill-buffer-hook (emacs-tui--workspace-origin-kill-hook session) t)))
      (set-marker (emacs-tui--popup-begin popup) nil)
      (set-marker (emacs-tui--popup-end popup) nil))
    (unless (cl-some #'emacs-tui--workspace-popup emacs-tui--sessions)
      (remove-hook 'post-command-hook #'emacs-tui--popup-post-command)
      (remove-hook 'delete-terminal-functions #'emacs-tui--popup-terminal-deleted))
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
      (emacs-tui--sync-tty-focus-hooks)
      (emacs-tui--sync-popup-focus-hook)
      (unwind-protect
          (emacs-tui--stop-request (emacs-tui--workspace-request session))
        (let ((callback (emacs-tui--workspace-on-close session))
              (callback-frame (selected-frame))
              (callback-window (selected-window)))
          (setf (emacs-tui--workspace-on-close session) nil)
          (when callback
            (condition-case err (funcall callback session)
              ((error quit)
               (message "emacs-tui close callback: %s" (error-message-string err))))
            (when (or (not (eq callback-frame (selected-frame)))
                      (not (eq callback-window (selected-window))))
              (emacs-tui--remember-tty-focus)))))))
  nil)

(defun emacs-tui-next-view (&optional session delta)
  "Move SESSION's logical view focus by DELTA, defaulting to one.
Reject invalidated surfaces before changing focus or revealing hidden panels."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (unless (emacs-tui--subtree session)
    (user-error "Interface surface is no longer owned"))
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

(defun emacs-tui-focus-view (session id)
  "Focus SESSION's view ID and return SESSION.
Nil ID means the current view.  Reveal hidden panels using the existing layout
and maximize policy.  Persistent interfaces select the native view window;
ephemeral interfaces retain separate query editing focus.  Do not change
selection, queries or marks, or invoke exploration/commit/action callbacks."
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--resolve-view session id))
         (index (cl-position view (emacs-tui--workspace-views session))))
    (unless (emacs-tui--subtree session)
      (user-error "Interface surface is no longer owned"))
    (emacs-tui-next-view session (- index (emacs-tui--workspace-focus session))))
  session)

(defun emacs-tui-scroll-view (session id &optional lines)
  "Scroll SESSION's visible text preview ID by LINES without taking focus.
Nil ID means the logically focused view.  LINES follows `scroll-up': nil
scrolls nearly one window, and a negative integer scrolls backward.  Native
end-of-buffer and beginning-of-buffer errors are preserved.  Hidden, list and
editable input views are rejected; this command never reveals a hidden pane.
Preserve the selected source window/buffer and logical focus, changing only
the preview's reading position.  No selection or application action runs.
Return SESSION."
  (unless (or (null lines) (integerp lines))
    (error "Scroll distance must be an integer or nil"))
  (setq session (emacs-tui--require-session session))
  (let ((view (emacs-tui--scrollable-view session id)))
    (unwind-protect
        (with-selected-window (emacs-tui--view-window view) (scroll-up lines))
      (emacs-tui--remember-view view)))
  session)

(defun emacs-tui-scroll-view-horizontally (session id &optional columns)
  "Scroll SESSION's visible read-only preview ID horizontally by COLUMNS.
Nil ID means the logically focused view.  Positive COLUMNS reveals text farther
along each line; negative values return toward the beginning, stopping at zero.
Nil COLUMNS uses the native window width minus two, as with `scroll-left'.
Preserve source focus, text, selection and marks.  Retain the explicit scroll
minimum through layout changes and popup resizing; new preview text resets it.
Hidden, list and editable views are rejected.  Return SESSION."
  (unless (or (null columns) (integerp columns))
    (error "Scroll distance must be an integer or nil"))
  (setq session (emacs-tui--require-session session))
  (let ((view (emacs-tui--scrollable-view session id)))
    (with-selected-window (emacs-tui--view-window view)
      (scroll-left columns t))
    (emacs-tui--remember-view view)
    (setf (nth 4 (emacs-tui--view-display-state view))
          (window-hscroll (emacs-tui--view-window view))))
  session)

(defun emacs-tui--scrollable-view (session id)
  "Return SESSION's visible read-only preview ID or signal a user error."
  (let* ((view (emacs-tui--resolve-view session id))
         (window (emacs-tui--view-window view)))
    (unless (and (emacs-tui--view-text view)
                 (not (emacs-tui--view-editable view)))
      (user-error "Only read-only text previews can scroll without focus"))
    (unless (and (emacs-tui--subtree session)
                 (window-live-p window)
                 (emacs-tui--owned-window-p session window)
                 (eq (window-buffer window) (emacs-tui--view-buffer view)))
      (user-error "Preview is not visible in an owned window"))
    view))

(defun emacs-tui--selection-cached-p (view)
  "Whether the current buffer has valid rendered positions for VIEW."
  (and (not (emacs-tui--view-text view))
       (vectorp emacs-tui--row-ranges)
       (eq emacs-tui--row-items (emacs-tui--view-visible-items view))
       (eql emacs-tui--row-tick (buffer-chars-modified-tick))
       (not emacs-tui--rendering)))

(defun emacs-tui--select-index (session view index)
  "Set VIEW's projected selection to INDEX in SESSION after display success."
  (with-current-buffer (emacs-tui--view-buffer view)
    (if (emacs-tui--selection-cached-p view)
        (progn
          ;; Match full list rendering, which widens via `erase-buffer'.
          (widen)
          (emacs-tui--highlight-row index)
          (goto-char (car (aref emacs-tui--row-ranges index)))
          (let ((window (emacs-tui--view-window view)))
            (when (and (window-live-p window) (eq (window-buffer window) (current-buffer)))
              (set-window-point window (point)))))
      (let ((candidate (copy-emacs-tui--view view)))
        (setf (emacs-tui--view-selected candidate) index)
        (emacs-tui--render-view session candidate)))
    (setf (emacs-tui--view-selected view) index)))

(defun emacs-tui-set-selection (session id item-id)
  "Select the first projected item with ITEM-ID in SESSION's view ID.
Nil ID means the focused view.  ITEM-ID follows the identity rules of
`emacs-tui-view'.  Signal a user error if the target is filtered out, collapsed,
absent, or belongs to a text/input view.  Hidden panels can retain selection
without taking focus; use `emacs-tui-focus-view' to reveal them explicitly.
Do not clear queries, change marks or invoke exploration/commit/action
callbacks.  Return SESSION.  Read the source object with
`emacs-tui-current-item'."
  (setq session (emacs-tui--require-session session))
  (let ((view (emacs-tui--resolve-view session id)))
    (when (emacs-tui--view-text view)
      (user-error "Text and input views do not select items"))
    (let ((index (cl-position item-id (emacs-tui--view-visible-items view)
                              :key #'emacs-tui--item-id :test #'equal)))
      (unless index (user-error "Item is not in the current projection: %S" item-id))
      (unless (emacs-tui--subtree session)
        (user-error "Interface surface is no longer owned"))
      (emacs-tui--select-index session view index)))
  session)

(defun emacs-tui-next-item (&optional session delta)
  "Move SESSION's focused selection by DELTA, defaulting to one.
Wrap at projection boundaries.  Interactively, use the numeric prefix argument."
  (interactive (list nil (prefix-numeric-value current-prefix-arg)))
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (buffer (emacs-tui--view-buffer view)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let* ((cached (emacs-tui--selection-cached-p view))
               (count (if cached (length emacs-tui--row-ranges)
                        (length (emacs-tui--view-visible-items view)))))
          (when (> count 0)
            (let ((index (mod (+ (emacs-tui--view-selected view) (or delta 1)) count)))
              (emacs-tui--select-index session view index))))))))

(defun emacs-tui-previous-item (&optional session count)
  "Move SESSION's focused selection backward by COUNT, defaulting to one.
Wrap at projection boundaries.  A negative COUNT moves forward.
Interactively, use the numeric prefix argument."
  (interactive (list nil (prefix-numeric-value current-prefix-arg)))
  (emacs-tui-next-item session (- (or count 1))))

(defun emacs-tui--select-boundary (session last)
  "Select SESSION's first projected row, or its last when LAST is non-nil."
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (buffer (emacs-tui--view-buffer view)))
    (when (emacs-tui--view-text view)
      (user-error "Text and input views do not select items"))
    (unless (emacs-tui--subtree session)
      (user-error "Interface surface is no longer owned"))
    (with-current-buffer buffer
      (let ((count (if (emacs-tui--selection-cached-p view)
                       (length emacs-tui--row-ranges)
                     (length (emacs-tui--view-visible-items view)))))
        (when (> count 0)
          (emacs-tui--select-index session view (if last (1- count) 0))))))
  session)

(defun emacs-tui-first-item (&optional session)
  "Select SESSION's first projected item without invoking application actions.
Preserve queries, sort and marks.  An empty projection is unchanged.
Text/input views and invalidated surfaces signal a user error.
SESSION defaults to the current interface.  Return SESSION."
  (interactive)
  (emacs-tui--select-boundary session nil))

(defun emacs-tui-last-item (&optional session)
  "Select SESSION's last projected item without invoking application actions.
Use the same projection, preservation and error rules as `emacs-tui-first-item'.
SESSION defaults to the current interface.  Return SESSION."
  (interactive)
  (emacs-tui--select-boundary session t))

(defun emacs-tui--action-items (session view)
  "Return a fresh target list for VIEW's explicit action in SESSION."
  (or (emacs-tui-marked-items session (emacs-tui--view-id view))
      (when-let* ((item (emacs-tui-current-item session))) (list item))))

(defun emacs-tui--action-enabled-p (action session items)
  "Test ACTION's availability for SESSION and ITEMS."
  (let ((enabled (emacs-tui--action-enabled action)))
    (if (functionp enabled) (funcall enabled session items) enabled)))

(defun emacs-tui--action-choice (answer choices)
  "Resolve accepted completion ANSWER in CHOICES without case ambiguity.
Prefer an exact spelling.  Native completion can accept another spelling
when case folding is enabled, including by minibuffer-local configuration."
  (or (assoc answer choices)
      (let ((matches (cl-remove-if-not
                      (lambda (choice)
                        (eq t (compare-strings answer nil nil (car choice) nil nil t)))
                      choices)))
        (when (cdr matches)
          (user-error "Ambiguous action spelling; choose an exact candidate"))
        (car matches))
      (user-error "No matching action chosen")))

(defun emacs-tui-act (&optional session id)
  "Invoke action ID in SESSION's focused view, or prompt when ID is nil.
Use marked objects in source order, including hidden marks, before falling
back to the selected object.  With no targets, pass nil; applications can
provide target-free actions such as refresh.  Read current objects and check
availability again after choosing from the menu.  If the interface closes or
focus changes during the prompt, abort rather than dispatch to another view.
Only the chosen action's RUN callback executes.  Return its result.  There is
no implicit close, commit or transaction; applications own all effects."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (let* ((view (emacs-tui--focused-view session))
         (actions (emacs-tui--view-actions view)))
    (unless actions (user-error "This view has no named actions"))
    (unless id
      (let* ((items (emacs-tui--action-items session view))
             (labels (make-hash-table :test #'equal))
             (choices
              (cl-loop for action in actions
                       when (emacs-tui--action-enabled-p action session items)
                       collect
                       (let* ((label (format "%s (%S)" (emacs-tui--action-title action)
                                             (emacs-tui--action-id action)))
                              (choice label) (suffix 1))
                         ;; Distinct uninterned IDs can have the same printed name.
                         (while (gethash choice labels)
                           (setq choice (format "%s [%d]" label (cl-incf suffix))))
                         (puthash choice t labels)
                         (cons choice (emacs-tui--action-id action))))))
        (unless choices (user-error "No actions are available for these targets"))
        (setq id (cdr (emacs-tui--action-choice (completing-read
						 (format "Action (%d target%s): " (length items)
							 (if (= 1 (length items)) "" "s"))
						 choices nil t)
						choices)))))
    (emacs-tui--require-session session)
    (unless (eq view (emacs-tui--focused-view session))
      (user-error "Focused view changed; choose an action again"))
    (let ((action (cl-find id actions :key #'emacs-tui--action-id :test #'equal))
          (items (emacs-tui--action-items session view)))
      (unless action (user-error "Unknown action: %S" id))
      (unless (emacs-tui--action-enabled-p action session items)
        (user-error "This action is unavailable for the current targets"))
      (funcall (emacs-tui--action-run action) session items))))

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

(defun emacs-tui-set-layout (session layout)
  "Use LAYOUT for SESSION, preserving focus and view state.
LAYOUT is `columns', `rows' or `grid'.  Interactively, choose by name.
An unchanged layout does not reflow or render.  While maximized, remember
LAYOUT for restoration without replacing the visible panel.  Reject an
invalidated surface before changing state.  Return SESSION, or nil if a
necessary reflow closes the interface.  No application actions or providers
are invoked."
  (interactive
   (let ((session (emacs-tui--require-session nil)))
     (list session
           (intern (completing-read
                    "Layout: " '("columns" "rows" "grid") nil t nil nil
                    (symbol-name (emacs-tui--workspace-layout session)))))))
  (setq session (emacs-tui--require-session session))
  (unless (memq layout '(columns rows grid)) (error "Unknown layout: %S" layout))
  (unless (emacs-tui--subtree session)
    (user-error "Interface surface is no longer owned"))
  (if (eq layout (emacs-tui--workspace-layout session)) session
    (setf (emacs-tui--workspace-layout session) layout)
    (if (emacs-tui--workspace-maximized session) session
      (emacs-tui-refresh session))))

(defun emacs-tui-cycle-layout (&optional session)
  "Cycle SESSION between columns, rows and grid layouts.
Interactively, a prefix argument chooses a layout by name instead."
  (interactive)
  (setq session (emacs-tui--require-session session))
  (if (and (called-interactively-p 'any) current-prefix-arg)
      (call-interactively #'emacs-tui-set-layout)
    (emacs-tui-set-layout
     session (pcase (emacs-tui--workspace-layout session)
               ('columns 'rows) ('rows 'grid) (_ 'columns)))))

(provide 'emacs-tui)
;;; emacs-tui.el ends here
