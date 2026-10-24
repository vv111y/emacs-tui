;;; emacs-tui-tree-bulk-test.el --- Whole-forest expansion -*- lexical-binding: t; -*-
;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-tree-bulk-test--with (&rest body)
  "Run BODY in a mounted forest with session bound."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (let ((session (emacs-tui-mount
                     :views (list
                             (emacs-tui-tree
                              :id 'tree :multi-select t
                              :items '((:id a :label "A" :children ((:id x :label "X")))
                                       (:id b :label "B" :children
                                            ((:id c :label "C" :children ((:id z :label "日本語")))))))
                             (emacs-tui-view :id 'preview :text "Preview")))))
       (unwind-protect (progn ,@body) (emacs-tui-close session)))))

(ert-deftest emacs-tui-tree-bulk-retains-hidden-marks-and-selects-root-ancestor ()
  (emacs-tui-tree-bulk-test--with
    (should (eq session (emacs-tui-tree-expand-all session)))
    (let ((view (emacs-tui--resolve-view session 'tree)))
      (should (equal '(a x b c z) (mapcar #'emacs-tui--item-id
                                         (emacs-tui--view-visible-items view)))))
    (emacs-tui-set-selection session 'tree 'z)
    (emacs-tui-toggle-mark session)
    (emacs-tui-tree-collapse-all session)
    (should (eq 'b (emacs-tui--item-id (emacs-tui-current-item session))))
    (should (equal '(z) (mapcar #'emacs-tui--item-id (emacs-tui-marked-items session))))
    (emacs-tui-tree-expand-all session)
    (should (eq 'b (emacs-tui--item-id (emacs-tui-current-item session))))))

(ert-deftest emacs-tui-tree-bulk-hidden-panel-and-search-policy ()
  (emacs-tui-tree-bulk-test--with
    (emacs-tui-focus-view session 'preview)
    (emacs-tui-toggle-maximize session)
    (emacs-tui-tree-expand-all session 'tree)
    (should (eq 'preview (emacs-tui-current-view session)))
    (emacs-tui-set-query session 'tree "日本語")
    (let ((view (emacs-tui--resolve-view session 'tree)))
      (should-error (emacs-tui-tree-collapse-all session 'tree) :type 'user-error)
      (should (equal "日本語" (emacs-tui-query session 'tree)))
      (should (equal '(b c z) (mapcar #'emacs-tui--item-id (emacs-tui--view-visible-items view)))))
    (emacs-tui-set-query session 'tree "")
    (emacs-tui-tree-collapse-all session 'tree)
    (emacs-tui-focus-view session 'tree)
    (execute-kbd-macro (kbd "C-c + C-c -"))
    (should (= 2 (length (emacs-tui--view-visible-items
                          (emacs-tui--resolve-view session 'tree)))))))

(ert-deftest emacs-tui-tree-bulk-render-failure-keeps-expansion-and-selection ()
  (emacs-tui-tree-bulk-test--with
    (emacs-tui-tree-expand-all session)
    (emacs-tui-set-selection session 'tree 'z)
    (emacs-tui-toggle-mark session)
    (let* ((view (emacs-tui--resolve-view session 'tree))
           (data (emacs-tui--view-tree view)) (text (buffer-string))
           (reject (lambda (&rest _) (error "Editing failed"))))
      (add-hook 'after-change-functions reject nil t)
      (should-error (emacs-tui-tree-collapse-all session))
      (remove-hook 'after-change-functions reject t)
      (should (eq data (emacs-tui--view-tree view)))
      (should (equal-including-properties text (buffer-string)))
      (should (eq 'z (emacs-tui--item-id (emacs-tui-current-item session))))
      (should (equal '(z) (mapcar #'emacs-tui--item-id (emacs-tui-marked-items session))))
      (emacs-tui-tree-collapse-all session)
      (should (eq 'b (emacs-tui--item-id (emacs-tui-current-item session)))))))

(ert-deftest emacs-tui-tree-bulk-does-not-call-accessors-or-actions ()
  (emacs-tui-tree-bulk-test--with
    (let ((view (emacs-tui--focused-view session)))
      (setf (emacs-tui--view-children view) (lambda (_) (ert-fail "Accessor called"))
            (emacs-tui--view-on-select view) (lambda (&rest _) (ert-fail "Action called")))
      (emacs-tui-tree-expand-all session)
      (emacs-tui-tree-collapse-all session)
      (emacs-tui-update session 'tree :items nil)
      (should (eq session (emacs-tui-tree-expand-all session)))
      (should-not (emacs-tui-current-item session)))))

(ert-deftest emacs-tui-tree-bulk-rejects-nontrees-closed-and-foreign-surfaces ()
  (emacs-tui-tree-bulk-test--with
    (should-error (emacs-tui-tree-expand-all session 'preview) :type 'user-error)
    (let* ((view (emacs-tui--resolve-view session 'tree))
           (data (emacs-tui--view-tree view))
           (foreign (generate-new-buffer " *foreign tree bulk*")))
      (unwind-protect
          (progn
            (with-current-buffer foreign (insert "Unrelated contents"))
            (set-window-buffer (emacs-tui--view-window view) foreign)
            (should-error (emacs-tui-tree-expand-all session 'tree) :type 'user-error)
            (should-error (emacs-tui-tree-collapse-all session 'tree) :type 'user-error)
            (should (eq data (emacs-tui--view-tree view)))
            (should (equal "Unrelated contents" (with-current-buffer foreign (buffer-string)))))
        (emacs-tui-close session)
        (kill-buffer foreign)))
    (should-error (emacs-tui-tree-expand-all session) :type 'user-error)))
