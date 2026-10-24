;;; emacs-tui-view-navigation-test.el --- Named application navigation -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-test--named-views (views &rest body)
  "Mount VIEWS, evaluate BODY with session bound, and dispose it."
  (declare (indent 1) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let ((session (emacs-tui-mount :views ,views)))
       (unwind-protect (progn ,@body) (emacs-tui-close session)))))

(ert-deftest emacs-tui-view-navigation-direct-focus-and-selection-have-no-actions ()
  (let ((actions 0) (item (list :id 'beta :label "Beta")))
    (emacs-tui-test--named-views
        (list (emacs-tui-view :id 'a :items '("one" "two"))
              (emacs-tui-view :id "b" :items (list "Alpha" item)
                              :on-select (lambda (&rest _) (cl-incf actions))))
      (should (eq (emacs-tui-current-view session) 'a))
      (should (eq session (emacs-tui-set-selection session "b" 'beta)))
      (should (eq (emacs-tui-current-view session) 'a))
      (should (eq (emacs-tui-current-item session "b") item))
      (should (equal (emacs-tui-current-item session) "one"))
      (should (eq session (emacs-tui-focus-view session "b")))
      (should (equal (emacs-tui-current-view session) "b"))
      (should (eq (emacs-tui-current-item) item))
      (should (equal (emacs-tui-current-view) "b"))
      (should (zerop actions))
      (emacs-tui-select session)
      (should (= actions 1)))))

(ert-deftest emacs-tui-view-navigation-preserves-query-sort-source-and-marks ()
  (let* ((a (list :id 'a :label "Alpha" :rank 3))
         (b (list :id 'b :label "Beta" :rank 1))
         (c (list :id 'c :label "Gamma" :rank 2))
         (source (list a b c)))
    (emacs-tui-test--named-views
        (list (emacs-tui-view :id 'rows :items source :multi-select t
                              :columns (list (emacs-tui-column :id 'rank :value :rank))))
      (emacs-tui-toggle-mark session)
      (emacs-tui-sort session 'rows 'rank)
      (emacs-tui-set-query session 'rows "Beta")
      (should-error (emacs-tui-set-selection session nil 'a) :type 'user-error)
      (should (equal (emacs-tui-query session 'rows) "Beta"))
      (should (eq (emacs-tui-current-item session) b))
      (should (equal (emacs-tui-marked-items session) (list a)))
      (emacs-tui-set-query session 'rows "")
      (emacs-tui-set-selection session nil 'c)
      (should (eq (emacs-tui-current-item session) c))
      (let ((view (emacs-tui--focused-view session)))
        (with-current-buffer (emacs-tui--view-buffer view)
          (should (= (line-number-at-pos) 3))))
      (should (equal source (list a b c)))
      (should (equal (emacs-tui-marked-items session) (list a))))))

(ert-deftest emacs-tui-view-navigation-reads-hidden-panel-and-reveals-on-request ()
  (emacs-tui-test--named-views
      (list (emacs-tui-view :id 'a :items '("first"))
            (emacs-tui-view :id 'b :items '("one" "two")))
    (emacs-tui-toggle-maximize session)
    (let* ((b (emacs-tui--resolve-view session 'b))
           (before (selected-window)))
      (should-not (emacs-tui--view-window b))
      (emacs-tui-set-selection session 'b "two")
      (should (eq before (selected-window)))
      (should (eq (emacs-tui-current-view session) 'a))
      (should (equal (emacs-tui-current-item session 'b) "two"))
      (should-not (emacs-tui--view-window b))
      (emacs-tui-focus-view session 'b)
      (should (eq (emacs-tui-current-view session) 'b))
      (should (equal (emacs-tui-current-item session) "two"))
      (should (eq (selected-window) (emacs-tui--view-window b)))
      (should (emacs-tui--workspace-maximized session)))))

(ert-deftest emacs-tui-view-navigation-retains-native-input-and-preview-state ()
  (emacs-tui-test--named-views
      (list (emacs-tui-input :id 'field :value "native input")
            (emacs-tui-view :id 'preview :text (make-string 500 ?x))
            (emacs-tui-view :id 'rows :items '("one" "two")))
    (let ((input (emacs-tui--resolve-view session 'field))
          (preview (emacs-tui--resolve-view session 'preview)))
      (with-current-buffer (emacs-tui--view-buffer input)
        (goto-char 5) (insert "edit") (undo-boundary))
      (with-current-buffer (emacs-tui--view-buffer preview) (goto-char 100))
      (set-window-point (emacs-tui--view-window preview) 100)
      (emacs-tui-set-selection session 'rows "two")
      (emacs-tui-focus-view session 'preview)
      (should (= (point) 100))
      (should-not (emacs-tui-current-item session 'preview))
      (should-error (emacs-tui-set-selection session 'field "one") :type 'user-error)
      (should-error (emacs-tui-set-selection session 'preview "one") :type 'user-error)
      (emacs-tui-focus-view session 'field)
      (should (equal (emacs-tui-input-value session) "natieditve input"))
      (should (consp buffer-undo-list))
      (should-not (emacs-tui-current-item session 'field)))))

(ert-deftest emacs-tui-view-navigation-ephemeral-focus-preserves-query-point ()
  (save-window-excursion
    (let ((session (emacs-tui-open
                    :backend 'windows
                    :views (list (emacs-tui-view :id 'a :items '("Alpha"))
                                  (emacs-tui-view :id 'b :items '("Beta"))))))
      (unwind-protect
          (let ((query (current-buffer)) (window (selected-window)))
            (insert "a")
            (goto-char 1)
            (emacs-tui-set-selection session 'b "Beta")
            (emacs-tui-focus-view session 'b)
            (should (eq window (selected-window)))
            (should (eq query (current-buffer)))
            (should (= (point) 1))
            (should (equal (emacs-tui-query session) "a"))
            (should (eq (emacs-tui-current-view session) 'b)))
        (emacs-tui-close session)))))

(ert-deftest emacs-tui-view-navigation-selects-fresh-source-objects-and-first-duplicate ()
  (emacs-tui-test--named-views
      (list (emacs-tui-view :id 'rows :items '((:id a :label "Old")) ))
    (let ((fresh (list :id 'a :label "New")))
      (emacs-tui-update session 'rows :items (list "other" fresh))
      (emacs-tui-set-selection session 'rows 'a)
      (should (eq fresh (emacs-tui-current-item session))))
    (emacs-tui-update session 'rows :items '("same" "same" "other"))
    (emacs-tui-set-selection session 'rows "other")
    (emacs-tui-set-selection session 'rows "same")
    (should (= (point) 1))))

(ert-deftest emacs-tui-view-navigation-tree-collapse-does-not-expand-implicitly ()
  (emacs-tui-test--named-views
      (list (emacs-tui-tree :id 'tree
                            :items '((:id root :label "Root"
                                          :children ((:id leaf :label "Leaf"))))))
    (should-error (emacs-tui-set-selection session 'tree 'leaf) :type 'user-error)
    (should (eq (plist-get (emacs-tui-current-item session) :id) 'root))
    (emacs-tui-tree-expand session)
    (emacs-tui-set-selection session 'tree 'leaf)
    (should (eq (plist-get (emacs-tui-current-item session) :id) 'leaf))))

(ert-deftest emacs-tui-view-navigation-invalid-targets-do-not-change-focus-or-content ()
  (emacs-tui-test--named-views (list (emacs-tui-view :id 'rows :items '("one" "two")))
    (let ((window (selected-window)) (text (buffer-string)))
      (should-error (emacs-tui-focus-view session 'missing))
      (should-error (emacs-tui-set-selection session 'rows "missing") :type 'user-error)
      (should-error (emacs-tui-current-item session 'missing))
      (should (eq (emacs-tui-current-view session) 'rows))
      (should (eq window (selected-window)))
      (should (equal (buffer-string) text))
      (should (equal (emacs-tui-current-item session) "one")))))

(ert-deftest emacs-tui-view-navigation-rejects-repurposed-surface ()
  (save-window-excursion
    (let* ((foreign (generate-new-buffer " *Foreign navigation*"))
           (session (emacs-tui-embed :view (emacs-tui-view :id 'rows :items '("one" "two")))))
      (unwind-protect
          (progn
            (with-current-buffer foreign (insert "foreign text") (goto-char 4))
            (set-window-buffer (selected-window) foreign)
            (set-window-point (selected-window) 4)
            (should-error (emacs-tui-focus-view session 'rows) :type 'user-error)
            (should-error (emacs-tui-set-selection session 'rows "two") :type 'user-error)
            (should (eq (window-buffer) foreign))
            (should (= (window-point) 4))
            (should (equal (with-current-buffer foreign (buffer-string)) "foreign text")))
        (emacs-tui-close session)
        (kill-buffer foreign)))))

(ert-deftest emacs-tui-view-navigation-rejects-closed-session ()
  (let ((session (emacs-tui-mount :views (list (emacs-tui-view :id 'a :items '("one"))))))
    (emacs-tui-close session)
    (should-error (emacs-tui-current-view session) :type 'user-error)
    (should-error (emacs-tui-current-item session 'a) :type 'user-error)
    (should-error (emacs-tui-focus-view session 'a) :type 'user-error)
    (should-error (emacs-tui-set-selection session 'a "one") :type 'user-error)))

(ert-deftest emacs-tui-view-navigation-cycle-cannot-reclaim-repurposed-hidden-slot ()
  (dolist (constructor '(emacs-tui-mount emacs-tui-open))
    (save-window-excursion
      (delete-other-windows)
      (let ((foreign (generate-new-buffer " *Foreign hidden slot*"))
            (session (funcall constructor :backend 'windows
                              :views (list (emacs-tui-view :id 'a :items '("one"))
                                           (emacs-tui-view :id 'b :text "Preview")))))
        (unwind-protect
            (progn
              (emacs-tui-toggle-maximize session)
              (let* ((a (emacs-tui--resolve-view session 'a))
                     (b (emacs-tui--resolve-view session 'b))
                     (window (emacs-tui--view-window a))
                     (selected (selected-window)))
                (should-not (emacs-tui--view-window b))
                (with-current-buffer foreign
                  (insert (make-string 200 ?x))
                  (set-buffer-modified-p nil))
                (set-window-buffer window foreign)
                (set-window-point window 80)
                (set-window-hscroll window 4)
                (dolist (command '(emacs-tui-next-view emacs-tui-previous-view))
                  (should-error (funcall command session) :type 'user-error)
                  (should (eq (emacs-tui-current-view session) 'a))
                  (should (eq window (emacs-tui--view-window a)))
                  (should-not (emacs-tui--view-window b))
                  (should (eq selected (selected-window)))
                  (should (eq foreign (window-buffer window)))
                  (should (= 80 (window-point window)))
                  (should (= 4 (window-hscroll window)))
                  (should (equal (make-string 200 ?x)
                                 (with-current-buffer foreign (buffer-string))))
                  (should-not (with-current-buffer foreign (buffer-modified-p))))
                ;; The existing invalidation path still disposes the session.
                (should-not (emacs-tui-refresh session))
                (should-not (emacs-tui-live-p session))
                (should (eq foreign (window-buffer window)))
                (should (= 80 (window-point window)))))
          (emacs-tui-close session)
          (kill-buffer foreign))))))

(ert-deftest emacs-tui-view-navigation-cycle-rejects-visible-foreign-pane ()
  (emacs-tui-test--named-views
      (list (emacs-tui-view :id 'a :items '("one"))
            (emacs-tui-view :id 'b :text "Preview"))
    (let ((foreign (generate-new-buffer " *Foreign visible pane*"))
          (window (emacs-tui--view-window (emacs-tui--resolve-view session 'b)))
          (selected (selected-window)))
      (unwind-protect
          (progn
            (with-current-buffer foreign (insert "foreign text"))
            (set-window-buffer window foreign)
            (set-window-point window 6)
            (should-error (emacs-tui-next-view session) :type 'user-error)
            (should-error (emacs-tui-previous-view session) :type 'user-error)
            (should (eq selected (selected-window)))
            (should (eq (emacs-tui-current-view session) 'a))
            (should (eq foreign (window-buffer window)))
            (should (= 6 (window-point window))))
        (kill-buffer foreign)))))

;;; emacs-tui-view-navigation-test.el ends here
