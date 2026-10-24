;;; emacs-tui-tree-test.el --- Tree interaction regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Cover source identity, expansion, search context and transactional updates.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defun emacs-tui-tree-test--forest ()
  "Return a three-level forest with stable identities."
  (list (list :id 'root :label "Root"
              :children (list (list :id 'branch :label "Branch"
                                    :children (list (list :id 'leaf :label "Needle" :value 42)))
                              (list :id 'sibling :label "Sibling")))
        (list :id 'other :label "Other")))

(defun emacs-tui-tree-test--ids (session)
  "Return the visible tree identities in SESSION."
  (mapcar #'emacs-tui--item-id
          (emacs-tui--view-visible-items (emacs-tui--focused-view session))))

(defmacro emacs-tui-tree-test--with (&rest body)
  "Mount a marked tree as session, run BODY and dispose it."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let (session)
       (unwind-protect
           (progn
             (setq session (emacs-tui-mount
                            :views (list (emacs-tui-tree :id 'tree :multi-select t
                                                        :items (emacs-tui-tree-test--forest)))))
             ,@body)
         (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-expand-collapse-and-parent-navigation ()
  (emacs-tui-tree-test--with
    (should (equal '(root other) (emacs-tui-tree-test--ids session)))
    (should (string-match-p (regexp-quote "+ Root") (buffer-string)))
    (execute-kbd-macro (kbd "<right>"))
    (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids session)))
    (should (eq 'root (plist-get (emacs-tui-current-item session) :id)))
    (execute-kbd-macro (kbd "<right> <right> <right>"))
    (should (eq 'leaf (plist-get (emacs-tui-current-item session) :id)))
    (execute-kbd-macro (kbd "<left>"))
    (should (eq 'branch (plist-get (emacs-tui-current-item session) :id)))
    (execute-kbd-macro (kbd "<left>"))
    (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids session)))
    (execute-kbd-macro (kbd "<left> <left>"))
    (should (equal '(root other) (emacs-tui-tree-test--ids session)))))

(ert-deftest emacs-tui-tree-actions-return-original-objects ()
  (let* ((forest (emacs-tui-tree-test--forest))
         (leaf (car (plist-get (car (plist-get (car forest) :children)) :children)))
         selected session)
    (save-window-excursion
      (unwind-protect
          (progn
            (setq session (emacs-tui-mount
                           :views (list (emacs-tui-tree :id 'tree :items forest
                                                       :on-select (lambda (_app item) (setq selected item))))))
            (execute-kbd-macro (kbd "<right> <right> <right> <right> RET"))
            (should (eq leaf selected))
            (should (eq leaf (emacs-tui-current-item session)))
            (should (emacs-tui-live-p session)))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-collapsed-marks-survive-and-use-source-order ()
  (emacs-tui-tree-test--with
    (execute-kbd-macro (kbd "<right> <right> <right> <right> C-c C-m"))
    (execute-kbd-macro (kbd "<left> C-c C-m <left> <left> <left>"))
    (should (equal '(root other) (emacs-tui-tree-test--ids session)))
    (should (equal '(branch leaf)
                   (mapcar #'emacs-tui--item-id (emacs-tui-marked-items session))))))

(ert-deftest emacs-tui-tree-source-updates-retain-identity-and-expansion ()
  (emacs-tui-tree-test--with
    (execute-kbd-macro (kbd "<right> <right> <right> <right> C-c C-m"))
    (let* ((forest (emacs-tui-tree-test--forest))
           (leaf (car (plist-get (car (plist-get (car forest) :children)) :children))))
      (plist-put leaf :label "Renamed")
      (emacs-tui-update session 'tree :items forest)
      (should (equal '(root branch leaf sibling other) (emacs-tui-tree-test--ids session)))
      (should (eq leaf (emacs-tui-current-item session)))
      (should (eq leaf (car (emacs-tui-marked-items session))))
      (emacs-tui-update session 'tree :items (cdr forest))
      (should-not (emacs-tui-marked-items session))
      (emacs-tui-update session 'tree :items forest)
      (should (equal '(root other) (emacs-tui-tree-test--ids session))))))

(ert-deftest emacs-tui-tree-local-query-reveals-ancestors-without-changing-expansion ()
  (save-window-excursion
    (let (session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-open :backend 'windows
                                         :views (list (emacs-tui-tree :id 'tree
                                                                     :items (emacs-tui-tree-test--forest)))))
            (insert "needle")
            (should (equal '(root branch leaf) (emacs-tui-tree-test--ids session)))
            (should-error (emacs-tui-tree-toggle session) :type 'user-error)
            (erase-buffer)
            (should (equal '(root other) (emacs-tui-tree-test--ids session))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-child-projection-is-not-called-during-interaction ()
  (let ((calls 0) session)
    (save-window-excursion
      (unwind-protect
          (progn
            (setq session (emacs-tui-mount
                           :views (list (emacs-tui-tree :id 'tree :items (emacs-tui-tree-test--forest)
                                                       :children (lambda (item)
                                                                   (cl-incf calls)
                                                                   (plist-get item :children))))))
            (should (= 5 calls))
            (emacs-tui-tree-expand session)
            (emacs-tui-next-item session)
            (emacs-tui-tree-expand session)
            (emacs-tui-refresh session)
            (should (= 5 calls)))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-rejects-duplicate-cyclic-and-invalid-children ()
  (should-error (emacs-tui-tree :id 'tree :children nil))
  (should-error (emacs-tui-tree :id 'tree :items '((:label "Missing ID"))))
  (should-error (emacs-tui-tree :id 'tree :items '((:id a :label "A" :children 42))))
  (should-error (emacs-tui-tree :id 'tree :items '((:id a :label "A" :children ("same")) "same")))
  (let ((node (list :id 'self :label "Cycle" :children nil)))
    (plist-put node :children (list node))
    (should-error (emacs-tui-tree :id 'tree :items (list node)))))

(ert-deftest emacs-tui-tree-failed-source-update-preserves-state-and-display ()
  (emacs-tui-tree-test--with
    (execute-kbd-macro (kbd "<right> <right> C-c C-m"))
    (let ((item (emacs-tui-current-item session))
          (text (buffer-string)) (position (point))
          (marks (emacs-tui-marked-items session)))
      (should-error (emacs-tui-update session 'tree
                                      :items '((:id bad :label "Bad" :children 1))))
      (should (eq item (emacs-tui-current-item session)))
      (should (equal marks (emacs-tui-marked-items session)))
      (should (equal-including-properties text (buffer-string)))
      (should (= position (point)))
      (should-error (emacs-tui-update session 'tree :text "preview"))
      (should (equal-including-properties text (buffer-string))))))

(ert-deftest emacs-tui-tree-failed-expansion-render-does-not-commit ()
  (emacs-tui-tree-test--with
    (let ((text (buffer-string)))
      (add-hook 'before-change-functions (lambda (&rest _) (error "Render failed")) nil t)
      (should-error (emacs-tui-tree-expand session))
      (should (equal '(root other) (emacs-tui-tree-test--ids session)))
      (should (equal-including-properties text (buffer-string)))
      (setq-local before-change-functions nil)
      (emacs-tui-tree-expand session)
      (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids session))))))

(ert-deftest emacs-tui-tree-description-expansion-is-session-local ()
  (let ((description (emacs-tui-tree :id 'tree :items (emacs-tui-tree-test--forest))) a b)
    (save-window-excursion
      (unwind-protect
          (progn
            (setq a (emacs-tui-mount :views (list description)))
            (emacs-tui-tree-expand a)
            (setq b (emacs-tui-mount :views (list description)))
            (should (equal '(root other) (emacs-tui-tree-test--ids b)))
            (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids a))))
        (when b (emacs-tui-close b))
        (when a (emacs-tui-close a))))))

(ert-deftest emacs-tui-tree-provider-updates-and-supersession ()
  (save-window-excursion
    (let (session publish)
      (unwind-protect
          (progn
            (setq session
                  (emacs-tui-open :backend 'windows :debounce 0
                                  :views (list (emacs-tui-tree :id 'tree))
                                  :provider (lambda (_app _query callback _fail)
                                              (setq publish callback) nil)))
            (let ((request (emacs-tui--workspace-request session)))
              (cancel-timer (emacs-tui--request-timer request))
              (emacs-tui--start-provider request))
            (should (funcall publish 'tree :items (emacs-tui-tree-test--forest)))
            (emacs-tui-tree-expand session)
            (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids session)))
            (insert "new query")
            (should-not (emacs-tui-tree-test--ids session))
            (should-not (funcall publish 'tree :items (emacs-tui-tree-test--forest))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-embedding-and-native-keymap ()
  (save-window-excursion
    (let ((host (window-buffer)) session input)
      (unwind-protect
          (progn
            (setq session (emacs-tui-embed :view (emacs-tui-tree :id 'tree
                                                               :items (emacs-tui-tree-test--forest)))
                  input (current-buffer))
            (execute-kbd-macro (kbd "SPC"))
            (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids session)))
            (emacs-tui-close session)
            (should (eq host (window-buffer)))
            (should-not (buffer-live-p input)))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-search-restores-prior-expansion-and-handles-no-match ()
  (save-window-excursion
    (let (session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-open :backend 'windows
                                         :views (list (emacs-tui-tree :id 'tree
                                                                     :items (emacs-tui-tree-test--forest)))))
            (emacs-tui-tree-expand session)
            (insert "missing")
            (should-not (emacs-tui-tree-test--ids session))
            (erase-buffer)
            (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids session))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-application-query-policy-retains-expansion-commands ()
  (save-window-excursion
    (let (session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-open :backend 'windows :on-query #'ignore
                                         :views (list (emacs-tui-tree :id 'tree
                                                                     :items (emacs-tui-tree-test--forest)))))
            (insert "application-owned")
            (emacs-tui-tree-expand session)
            (should (equal '(root branch sibling other) (emacs-tui-tree-test--ids session))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-tree-buffer-example-previews-without-changing-source ()
  (load (expand-file-name "../examples/emacs-tui-buffer-tree.el"
                          (file-name-directory (or load-file-name
                                                   (locate-library "emacs-tui-tree-test")))))
  (save-window-excursion
    (with-temp-buffer
      (insert "Application source")
      (goto-char 4)
      (let ((source (current-buffer)) session)
        (unwind-protect
            (progn
              (setq session (emacs-tui-buffer-tree))
              (emacs-tui-buffer-tree--preview session (list :value source))
              (should (= 4 (with-current-buffer source (point))))
              (should (equal "Application source" (with-current-buffer source (buffer-string))))
              (emacs-tui-next-view session)
              (should (string-match-p "Application source" (buffer-string)))
              (emacs-tui-buffer-tree-refresh)
              (should (emacs-tui-live-p session)))
          (when session (emacs-tui-close session)))))))

(provide 'emacs-tui-tree-test)
;;; emacs-tui-tree-test.el ends here
