;;; emacs-tui-local-query-test.el --- Independent view search -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Local filters preserve source identity and provider/application lifetimes.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-local-query-test--with (views &rest body)
  "Mount VIEWS as session, run BODY and release owned resources."
  (declare (indent 1) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let (session)
       (unwind-protect
           (progn (setq session (emacs-tui-mount :views ,views)) ,@body)
         (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-local-query-keeps-source-and-hidden-marks ()
  (emacs-tui-local-query-test--with
      (list (emacs-tui-view :id 'a :items '("alpha" "beta") :multi-select t))
    (emacs-tui-toggle-mark session)
    (emacs-tui-set-query session 'a "BETA")
    (should (equal "beta" (emacs-tui-current-item session)))
    (should (equal '("alpha") (emacs-tui-marked-items session)))
    (should (equal '("alpha" "beta") (emacs-tui--view-items (emacs-tui--focused-view session))))
    (should (equal "BETA" (emacs-tui-query session 'a)))
    (should (equal "" (emacs-tui-query session)))
    (emacs-tui-set-query session nil "")
    (should (equal "beta" (emacs-tui-current-item session)))
    (should (= 2 (length (emacs-tui--view-visible-items (emacs-tui--focused-view session)))))))

(ert-deftest emacs-tui-local-query-is-independent-per-view ()
  (emacs-tui-local-query-test--with
      (list (emacs-tui-view :id 'a :items '("alpha" "beta"))
            (emacs-tui-view :id 'b :items '("alpha" "beta")))
    (emacs-tui-set-query session 'a "alpha")
    (emacs-tui-set-query session 'b "beta")
    (should (equal "alpha" (emacs-tui-current-item session)))
    (emacs-tui-next-view session)
    (should (equal "beta" (emacs-tui-current-item session)))
    (should (equal "alpha" (emacs-tui-query session 'a)))
    (should (equal "beta" (emacs-tui-query session 'b)))))

(ert-deftest emacs-tui-local-query-empty-overrides-global-nil-inherits ()
  (save-window-excursion
    (let (session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-open :backend 'windows
                                         :views (list (emacs-tui-view :id 'a :items '("alpha" "beta")))))
            (insert "alpha")
            (emacs-tui-set-query session 'a "")
            (should (equal "alpha" (emacs-tui-query session)))
            (should (equal "" (emacs-tui-query session 'a)))
            (should (= 2 (length (emacs-tui--view-visible-items (emacs-tui--focused-view session)))))
            (emacs-tui-set-query session 'a nil)
            (should (equal "alpha" (emacs-tui-query session 'a)))
            (should (= 1 (length (emacs-tui--view-visible-items (emacs-tui--focused-view session))))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-local-query-table-values-and-sort-survive ()
  (let ((first (list :id 'a :label "A" :mode "Emacs Lisp" :size 20))
        (second (list :id 'b :label "B" :mode "Emacs Lisp" :size 10)))
    (emacs-tui-local-query-test--with
        (list (emacs-tui-view :id 'a :items (list first second)
                              :columns (list (emacs-tui-column :id 'mode :width 3 :value :mode)
                                             (emacs-tui-column :id 'size :value :size))))
      (emacs-tui-sort session 'a 'size)
      (emacs-tui-set-query session 'a "LISP emacs")
      (emacs-tui-next-item session)
      (should (eq second (emacs-tui-current-item session)))
      (emacs-tui-set-query session 'a "10")
      (should (eq second (emacs-tui-current-item session)))
      (emacs-tui-set-query session 'a nil)
      (should (equal (list second first)
                     (emacs-tui--view-visible-items (emacs-tui--focused-view session))))
      (should (equal (list first second)
                     (emacs-tui--view-items (emacs-tui--focused-view session)))))))

(ert-deftest emacs-tui-local-query-source-replacement-retains-filter-and-identities ()
  (emacs-tui-local-query-test--with
      (list (emacs-tui-view :id 'a :items '((:id a :label "alpha") (:id b :label "beta"))
                            :multi-select t))
    (emacs-tui-toggle-mark session)
    (emacs-tui-set-query session 'a "beta")
    (let ((beta (list :id 'b :label "beta new")))
      (emacs-tui-update session 'a :items (list (list :id 'a :label "renamed") beta
                                               (list :id 'c :label "other")))
      (should (eq beta (emacs-tui-current-item session)))
      (should (equal "beta" (emacs-tui-query session 'a)))
      (should (equal "renamed" (plist-get (car (emacs-tui-marked-items session)) :label))))))

(ert-deftest emacs-tui-local-query-empty-and-whitespace-retain-source-order-and-marks ()
  (let* ((a (list :id 'a :label "Alpha" :rank 3))
         (b (list :id 'b :label "Beta" :rank 1))
         (c (list :id 'c :label "Gamma" :rank 2))
         (source (list a b c)))
    (emacs-tui-local-query-test--with
        (list (emacs-tui-view :id 'a :items source :multi-select t
                              :columns (list (emacs-tui-column :id 'rank :value :rank))))
      (emacs-tui-set-query session 'a "Alpha")
      (emacs-tui-toggle-mark session)
      (emacs-tui-set-query session 'a " \t\n\r ")
      (should (eq a (emacs-tui-current-item session)))
      (should (equal source (list a b c)))
      (emacs-tui-sort session 'a 'rank)
      (emacs-tui-set-query session 'a "Beta")
      (emacs-tui-set-query session 'a "")
      (should (eq b (emacs-tui-current-item session)))
      (should (equal (list b c a)
                     (emacs-tui--view-visible-items (emacs-tui--focused-view session))))
      (should (equal source (list a b c)))
      (should (equal (list a) (emacs-tui-marked-items session)))
      (should (eq a (car (emacs-tui-marked-items session)))))))

(ert-deftest emacs-tui-local-query-tree-reveals-context-and-restores-expansion ()
  (emacs-tui-local-query-test--with
      (list (emacs-tui-tree :id 'a :items '((:id root :label "Root"
                                                 :children ((:id leaf :label "Needle"))))))
    (emacs-tui-set-query session 'a "needle")
    (should (equal '(root leaf)
                   (mapcar #'emacs-tui--item-id
                           (emacs-tui--view-visible-items (emacs-tui--focused-view session)))))
    (should-error (emacs-tui-tree-toggle session) :type 'user-error)
    (emacs-tui-set-query session 'a nil)
    (should (= 1 (length (emacs-tui--view-visible-items (emacs-tui--focused-view session)))))))

(ert-deftest emacs-tui-local-query-does-not-restart-or-cancel-provider ()
  (save-window-excursion
    (let (session publish (calls 0) (cancels 0))
      (unwind-protect
          (progn
            (setq session (emacs-tui-mount
                           :debounce 60 :views (list (emacs-tui-view :id 'a))
                           :provider (lambda (_app _query callback _fail)
                                       (cl-incf calls) (setq publish callback)
                                       (lambda () (cl-incf cancels)))))
            (let ((request (emacs-tui--workspace-request session)))
              (cancel-timer (emacs-tui--request-timer request))
              (emacs-tui--start-provider request)
              (emacs-tui-set-query session 'a "beta")
              (should (funcall publish 'a :items '("alpha" "beta")))
              (should (equal "beta" (emacs-tui-current-item session)))
              (should (= 1 calls))
              (should (= 0 cancels))
              (should (emacs-tui--request-current-p request))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-local-query-overlays-application-owned-workspace-search ()
  (save-window-excursion
    (let (session (calls 0))
      (unwind-protect
          (progn
            (setq session (emacs-tui-open
                           :backend 'windows :on-query (lambda (&rest _) (cl-incf calls))
                           :views (list (emacs-tui-view :id 'a :items '("alpha" "beta")))))
            (insert "application search")
            (let ((before calls))
              (emacs-tui-set-query session 'a "beta")
              (should (equal "beta" (emacs-tui-current-item session)))
              (emacs-tui-set-query session 'a nil)
              (should (= before calls))
              (should (= 2 (length (emacs-tui--view-visible-items (emacs-tui--focused-view session)))))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-local-query-failure-retains-query-selection-and-display ()
  (let (fail)
    (emacs-tui-local-query-test--with
        (list (emacs-tui-view :id 'a :items '("alpha" "beta")
                              :columns (list (emacs-tui-column
                                              :id 'value :value (lambda (item)
                                                                  (when fail (error "Projection failed")) item)))))
      (emacs-tui-set-query session 'a "alpha")
      (let ((text (buffer-string)) (position (point)))
        (setq fail t)
        (should-error (emacs-tui-set-query session 'a "beta"))
        (setq fail nil)
        (should (equal "alpha" (emacs-tui-query session 'a)))
        (should (equal "alpha" (emacs-tui-current-item session)))
        (should (equal-including-properties text (buffer-string)))
        (should (= position (point)))))))

(ert-deftest emacs-tui-local-query-validates-target-and-value ()
  (emacs-tui-local-query-test--with
      (list (emacs-tui-view :id 'preview :text "Text") (emacs-tui-input :id 'input))
    (should-error (emacs-tui-set-query session 'preview "x") :type 'user-error)
    (should-error (emacs-tui-set-query session 'input "x") :type 'user-error)
    (should-error (emacs-tui-set-query session 'missing "x"))
    (should-error (emacs-tui-set-query session 'preview 42))
    (should-error (emacs-tui-query session 'missing))
    (should (equal "Text" (buffer-string)))))

(ert-deftest emacs-tui-local-query-native-input-demo-preserves-marks-and-refresh ()
  (load (expand-file-name "../examples/emacs-tui-filter-demo.el"
                          (file-name-directory (or load-file-name
                                                   (locate-library "emacs-tui-local-query-test")))))
  (save-window-excursion
    (let ((source (generate-new-buffer "Local query fixture")) session)
      (unwind-protect
          (progn
            (with-current-buffer source (insert "Fixture contents"))
            (setq session (emacs-tui-filter-demo))
            (insert "Local query fixture")
            (emacs-tui-next-view session)
            (should (eq source (plist-get (emacs-tui-current-item session) :value)))
            (emacs-tui-toggle-mark session)
            (emacs-tui-filter-demo-refresh)
            (should (equal "Local query fixture" (emacs-tui-query session 'buffers)))
            (emacs-tui-select session)
            (emacs-tui-next-view session)
            (should (equal "Fixture contents" (buffer-string)))
            (emacs-tui-next-view session)
            (erase-buffer)
            (should (eq source (plist-get (car (emacs-tui-marked-items session 'buffers)) :value))))
        (when session (emacs-tui-close session))
        (when (buffer-live-p source) (kill-buffer source))))))

(provide 'emacs-tui-local-query-test)
;;; emacs-tui-local-query-test.el ends here
