;;; emacs-tui-demo.el --- Small graph explorer demo -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Load this file and run M-x emacs-tui-demo.  This uses an in-memory
;; sample graph and does not read or modify any real knowledge base.

;;; Code:
(require 'emacs-tui)

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
\\[emacs-tui-cycle-layout] changes layout; \\[emacs-tui-close] cancels.
\\[emacs-tui-commit] inserts the focused view's marked demo links at the original
point, one per line in source order.
With no marks, it inserts only the selected node's link."
  (interactive)
  (emacs-tui-open
   :layout 'grid
   :views (list
           (emacs-tui-view :id 'nodes :title "Nodes" :multi-select t
                           :items (mapcar #'emacs-tui-demo--item emacs-tui-demo--nodes)
                           :on-select #'emacs-tui-demo--inspect)
           (emacs-tui-view :id 'preview :title "Preview" :text "RET to inspect a node")
           (emacs-tui-view :id 'links :title "Forward links" :multi-select t
                           :on-select #'emacs-tui-demo--inspect)
           (emacs-tui-view :id 'backlinks :title "Backlinks" :multi-select t
                           :on-select #'emacs-tui-demo--inspect))
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
                 "\n")))))

(provide 'emacs-tui-demo)
;;; emacs-tui-demo.el ends here
