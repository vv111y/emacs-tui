;;; emacs-tui-demo.el --- Small graph explorer demo -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Load this file and run M-x emacs-tui-demo.  This uses an in-memory
;; sample graph and does not read or modify any real knowledge base.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)

(cl-defstruct (emacs-tui-demo--history (:constructor emacs-tui-demo--make-history))
  current back forward)

(defconst emacs-tui-demo--nodes
  '(("emacs" "Emacs" "A programmable editing environment." ("org" "lisp"))
    ("org" "Org" "Structured plain-text documents." ("graph"))
    ("graph" "Knowledge graph" "Nodes, identities, links and exploration." ("org" "emacs"))
    ("lisp" "Emacs Lisp" "A language for extending Emacs." ("emacs")))
  "Sample nodes: ID, title, body and outgoing IDs.")

(defun emacs-tui-demo--item (node)
  "Return an interactive item for NODE."
  (list :id (car node) :label (nth 1 node) :value (car node)
        :annotation (format "%d links" (length (nth 3 node)))))

(defun emacs-tui-demo--inspect (session item)
  "Inspect ITEM in SESSION, updating its preview and link views."
  (let* ((id (plist-get item :value))
         (node (assoc id emacs-tui-demo--nodes)))
    (unless node (user-error "Unknown demo node: %S" id))
    (emacs-tui-update session 'preview
                      :text (format "%s\n\n%s" (nth 1 node) (nth 2 node)))
    (emacs-tui-update session 'links
                      :items (mapcar (lambda (linked)
                                       (emacs-tui-demo--item
                                        (assoc linked emacs-tui-demo--nodes)))
                                     (nth 3 node)))
    (emacs-tui-update session 'backlinks
                      :items (mapcar #'emacs-tui-demo--item
                                     (cl-remove-if-not
                                      (lambda (candidate)
                                        (member id (nth 3 candidate)))
                                      emacs-tui-demo--nodes)))))

(defun emacs-tui-demo--visit (history session item)
  "Inspect ITEM in SESSION, recording a new visit in HISTORY on success."
  (emacs-tui-demo--inspect session item)
  (let ((id (plist-get item :value)))
    (unless (equal id (emacs-tui-demo--history-current history))
      (when (emacs-tui-demo--history-current history)
        (push (emacs-tui-demo--history-current history)
              (emacs-tui-demo--history-back history)))
      (setf (emacs-tui-demo--history-current history) id
            (emacs-tui-demo--history-forward history) nil))))

(defun emacs-tui-demo--travel (history session backward)
  "Inspect a previous node in SESSION using HISTORY.
Move backward when BACKWARD is non-nil, otherwise move forward."
  (let ((id (car (if backward (emacs-tui-demo--history-back history)
                   (emacs-tui-demo--history-forward history)))))
    (unless id (user-error "No %s history" (if backward "backward" "forward")))
    (emacs-tui-demo--inspect session (emacs-tui-demo--item
                                      (assoc id emacs-tui-demo--nodes)))
    ;; Move stacks only after the display updates succeed.  Store identities,
    ;; not UI snapshots: queries, focus, selection and marks remain independent.
    (if backward
        (progn
          (push (emacs-tui-demo--history-current history)
                (emacs-tui-demo--history-forward history))
          (pop (emacs-tui-demo--history-back history)))
      (push (emacs-tui-demo--history-current history)
            (emacs-tui-demo--history-back history))
      (pop (emacs-tui-demo--history-forward history)))
    (setf (emacs-tui-demo--history-current history) id)))

(defun emacs-tui-demo--history-actions (history)
  "Describe explicit Back and Forward actions using this session's HISTORY."
  (list
   (emacs-tui-action
    :id 'back :title "Back"
    :enabled (lambda (_session _items) (emacs-tui-demo--history-back history))
    :run (lambda (session _items) (emacs-tui-demo--travel history session t)))
   (emacs-tui-action
    :id 'forward :title "Forward"
    :enabled (lambda (_session _items) (emacs-tui-demo--history-forward history))
    :run (lambda (session _items) (emacs-tui-demo--travel history session nil)))))

;;;###autoload
(defun emacs-tui-demo ()
  "Explore a sample graph, optionally committing Org-style links.
Type to search nodes.  Search changes can remove marks for nodes no longer
in the results.  Traversing a node can similarly replace its link lists.
\\<emacs-tui-input-mode-map>\\[emacs-tui-select] previews the selected node;
\\[emacs-tui-next-view] changes the focused view, and
\\[emacs-tui-next-item]/\\[emacs-tui-previous-item] navigate items.
\\[emacs-tui-toggle-mark] toggles a mark; \\[emacs-tui-clear-marks] clears marks
in the focused view.  Marks are independent in each list.
\\[emacs-tui-mark-all] marks its projected items;
\\[emacs-tui-invert-marks] inverts their marks.
Every view offers Back/Forward through \\[emacs-tui-act], including from the
query buffer.  The application map adds direct bindings in view buffers.  Only
explicit inspections create history.  Revisiting the current node does not
duplicate it; visiting another node after Back discards forward history.
History is private to this session and does not restore queries or marks.
\\[emacs-tui-cycle-layout] changes layout; \\[emacs-tui-close] cancels.
\\[emacs-tui-commit] inserts the focused view's marked demo links at the original
point, one per line in source order.
With no marks, it inserts only the selected node's link."
  (interactive)
  (let* ((history (emacs-tui-demo--make-history))
         (actions (emacs-tui-demo--history-actions history))
         (inspect (apply-partially #'emacs-tui-demo--visit history))
         (map (make-sparse-keymap)))
    (define-key map (kbd "C-c [")
                (lambda () (interactive) (emacs-tui-act nil 'back)))
    (define-key map (kbd "C-c ]")
                (lambda () (interactive) (emacs-tui-act nil 'forward)))
    (emacs-tui-open
     :layout 'grid
     :keymap map
     :views (list
             (emacs-tui-view :id 'nodes :title "Nodes" :multi-select t
                             :items (mapcar #'emacs-tui-demo--item emacs-tui-demo--nodes)
                             :on-select inspect :actions actions)
             (emacs-tui-view :id 'preview :title "Preview" :text "RET to inspect a node"
                             :actions actions)
             (emacs-tui-view :id 'links :title "Forward links" :multi-select t
                             :on-select inspect :actions actions)
             (emacs-tui-view :id 'backlinks :title "Backlinks" :multi-select t
                             :on-select inspect :actions actions))
     :on-query
     (lambda (session query)
       (let ((case-fold-search t))
	 (emacs-tui-update
          session 'nodes
          :items (mapcar #'emacs-tui-demo--item
			 (cl-remove-if-not
                          (lambda (node)
                            (string-match-p (regexp-quote query) (nth 1 node)))
                          emacs-tui-demo--nodes)))))
     :on-commit
     (lambda (session item marker)
       (goto-char marker)
       (insert
	(mapconcat (lambda (node)
                     (format "[[demo:%s][%s]]" (plist-get node :value)
                             (plist-get node :label)))
                   (or (emacs-tui-marked-items session) (list item))
                   "\n"))))))

(provide 'emacs-tui-demo)
;;; emacs-tui-demo.el ends here
