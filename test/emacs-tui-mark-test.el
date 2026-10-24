;;; emacs-tui-mark-test.el --- Multi-selection regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise marks through public operations with real query and view buffers.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-mark-test--workspace (options &rest body)
  "Open a workspace with OPTIONS, evaluate BODY, then release it."
  (declare (indent 1) (debug (form body)))
  `(save-window-excursion
     (delete-other-windows)
     (let ((source (generate-new-buffer " *tui-mark-source*")) session)
       (unwind-protect
           (progn
             (switch-to-buffer source)
             (insert "origin")
             (set-buffer-modified-p nil)
             (setq session (emacs-tui-open :backend 'windows ,@options))
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p source) (kill-buffer source))))))

(ert-deftest emacs-tui-mark-toggle-is-independent-from-actions-and-query ()
  (let (selected committed)
    (emacs-tui-mark-test--workspace
        (:views (list (emacs-tui-view
                       :id 'a :multi-select t :items '("alpha" "beta")
                       :on-select (lambda (&rest _) (setq selected t))))
         :on-commit (lambda (&rest _) (setq committed t)))
      (insert "a")
      (goto-char 1)
      (let ((query (current-buffer)) (window (selected-window)))
        (should (emacs-tui-toggle-mark))
        (should (equal '("alpha") (emacs-tui-marked-items)))
        (should-not (emacs-tui-toggle-mark))
        (should-not (emacs-tui-marked-items))
        (should (eq query (current-buffer)))
        (should (eq window (selected-window)))
        (should (= 1 (point)))
        (should (equal "a" (emacs-tui-query))))
      (should-not selected)
      (should-not committed)
      (with-current-buffer source
        (should (equal "origin" (buffer-string)))
        (should-not (buffer-modified-p))))))

(ert-deftest emacs-tui-mark-filter-retains-hidden-items-in-source-order ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t
                                    :items '("alpha" "beta" "gamma"))))
    (emacs-tui-next-item session 2)
    (emacs-tui-toggle-mark session)
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (insert "beta")
    (should (equal "beta" (emacs-tui-current-item session)))
    (should (equal '("alpha" "gamma") (emacs-tui-marked-items session)))
    (erase-buffer)
    (should (equal '("alpha" "gamma") (emacs-tui-marked-items session)))
    (insert "nothing matches")
    (should-not (emacs-tui-current-item session))
    (emacs-tui-clear-marks)
    (should-not (emacs-tui-marked-items session))))

(ert-deftest emacs-tui-mark-update-uses-current-items-and-source-order ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view
                     :id 'a :multi-select t
                     :items '((:id 1 :label "one" :value old-one)
                              (:id 2 :label "two" :value old-two)))))
    (emacs-tui-toggle-mark session)
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (let ((replacement '((:id 2 :label "new two" :value new-two)
                         (:id 1 :label "new one" :value new-one))))
      (emacs-tui-update session 'a :items replacement)
      (should (equal replacement (emacs-tui-marked-items session)))
      (should (eq (car replacement) (car (emacs-tui-marked-items session)))))))

(ert-deftest emacs-tui-mark-removed-identities-do-not-regain-marks ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t
                                    :items '("alpha" "beta"))))
    (emacs-tui-toggle-mark session)
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-update session 'a :items '("beta"))
    (should (equal '("beta") (emacs-tui-marked-items session)))
    (emacs-tui-update session 'a :items '("alpha" "beta"))
    (should (equal '("beta") (emacs-tui-marked-items session)))
    (emacs-tui-update session 'a :items nil)
    (emacs-tui-update session 'a :items '("alpha" "beta"))
    (should-not (emacs-tui-marked-items session))))

(ert-deftest emacs-tui-mark-equal-identities-survive-replacement ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t
                                    :items (list (copy-sequence "alpha")
                                                 (list :label "beta")))))
    (emacs-tui-toggle-mark session)
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-update session 'a
                      :items (list (list :label "beta") (copy-sequence "alpha")))
    (should (equal '((:label "beta") "alpha")
                   (emacs-tui-marked-items session)))))

(ert-deftest emacs-tui-mark-views-and-explicit-id-are-independent ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t :items '("same"))
                    (emacs-tui-view :id "b" :multi-select t :items '("same"))))
    (emacs-tui-toggle-mark session)
    (emacs-tui-next-view session)
    (should-not (emacs-tui-marked-items session))
    (should (equal '("same") (emacs-tui-marked-items session 'a)))
    (emacs-tui-toggle-mark session)
    (emacs-tui-clear-marks session 'a)
    (should-not (emacs-tui-marked-items session 'a))
    (should (equal '("same") (emacs-tui-marked-items session (copy-sequence "b"))))
    (should-error (emacs-tui-marked-items session 'unknown))
    (should-error (emacs-tui-clear-marks session 'unknown))))

(ert-deftest emacs-tui-mark-reused-description-has-fresh-session-state ()
  (let ((description (emacs-tui-view :id 'a :multi-select t :items '("alpha"))))
    (emacs-tui-mark-test--workspace (:views (list description))
      (emacs-tui-toggle-mark session)
      (should (equal '("alpha") (emacs-tui-marked-items session))))
    (emacs-tui-mark-test--workspace (:views (list description))
      (should-not (emacs-tui-marked-items session)))))

(ert-deftest emacs-tui-mark-disabled-empty-and-text-views-reject-toggle ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'plain :items '("alpha"))
                    (emacs-tui-view :id 'empty :multi-select t)
                    (emacs-tui-view :id 'text :multi-select t
                                    :items '("hidden") :text "Preview")))
    (dotimes (_ 3)
      (should-error (emacs-tui-toggle-mark session) :type 'user-error)
      (should-not (emacs-tui-marked-items session))
      (should-not (emacs-tui-clear-marks session))
      (emacs-tui-next-view session))))

(ert-deftest emacs-tui-mark-text-preview-clears-marks ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t :items '("alpha"))))
    (emacs-tui-toggle-mark session)
    (emacs-tui-update session 'a :text "Preview")
    (should-not (emacs-tui-marked-items session))
    (should-error (emacs-tui-toggle-mark session) :type 'user-error)
    (emacs-tui-update session 'a :text nil)
    (should (equal "alpha" (emacs-tui-current-item session)))
    (should-not (emacs-tui-marked-items session))))

(ert-deftest emacs-tui-mark-duplicates-rejected-only-for-opt-in-views ()
  (dolist (items '(("same" "same")
                   ((:id 1 :label "a") (:id 1 :label "b"))
                   ((:label "same") (:label "same"))
                   ("same" (:id "same" :label "another"))))
    (should-error (emacs-tui-view :id 'a :items items :multi-select t))
    (should (emacs-tui-view :id 'a :items items))))

(ert-deftest emacs-tui-mark-invalid-update-preserves-all-state ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t :items '("alpha"))))
    (emacs-tui-toggle-mark session)
    (let* ((view (emacs-tui--focused-view session))
           (buffer (emacs-tui--view-buffer view))
           (before (with-current-buffer buffer (buffer-string))))
      (should-error (emacs-tui-update session 'a :items '("bad" "bad") :text "Bad"))
      (should-error (emacs-tui-update session 'a :items '("valid") :text 42))
      (should (equal '("alpha") (emacs-tui-marked-items session)))
      (should (equal "alpha" (emacs-tui-current-item session)))
      (should (equal before (with-current-buffer buffer (buffer-string)))))))

(ert-deftest emacs-tui-mark-render-has-non-color-indicators-and-total-count ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t
                                    :items '("alpha" "beta"))
                    (emacs-tui-view :id 'plain :items '("plain"))))
    (emacs-tui-toggle-mark session)
    (let ((buffer (emacs-tui--view-buffer (emacs-tui--focused-view session))))
      (with-current-buffer buffer
        (should (equal "[x] alpha\n[ ] beta\n" (buffer-string)))
        (should (string-match-p "1 marked" header-line-format)))
      (insert "beta")
      (with-current-buffer buffer
        (should (equal "[ ] beta\n" (buffer-string)))
        (should (string-match-p "1 marked" header-line-format))))
    (erase-buffer)
    (emacs-tui-next-view session)
    (with-current-buffer (emacs-tui--view-buffer (emacs-tui--focused-view session))
      (should (equal "plain\n" (buffer-string)))
      (should-not (string-match-p "marked" header-line-format)))))

(ert-deftest emacs-tui-mark-hidden-only-batch-can-commit ()
  (let ((received-item 'unset))
    (emacs-tui-mark-test--workspace
        (:views (list (emacs-tui-view :id 'a :multi-select t
                                      :items '("alpha" "beta")))
         :on-commit (lambda (workspace item _origin)
                      (setq received-item item)
                      (insert (mapconcat #'identity
                                         (emacs-tui-marked-items workspace) ","))))
      (emacs-tui-toggle-mark session)
      (emacs-tui-next-item session)
      (emacs-tui-toggle-mark session)
      (insert "not visible")
      (should-not (emacs-tui-current-item session))
      (emacs-tui-commit session)
      (should-not received-item)
      (should-not (emacs-tui--workspace-active session))
      (with-current-buffer source
        (should (equal "originalpha,beta" (buffer-string)))))))

(ert-deftest emacs-tui-mark-failed-batch-commit-preserves-marks ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t :items '("alpha")))
       :on-commit (lambda (&rest _) (insert "bad") (error "Failed batch")))
    (emacs-tui-toggle-mark session)
    (insert "hidden")
    (should-error (emacs-tui-commit session))
    (should (equal '("alpha") (emacs-tui-marked-items session)))
    (should (emacs-tui--workspace-active session))
    (with-current-buffer source (should (equal "origin" (buffer-string))))))

(ert-deftest emacs-tui-mark-other-view-marks-cannot-enable-empty-commit ()
  (let (called)
    (emacs-tui-mark-test--workspace
        (:views (list (emacs-tui-view :id 'a :multi-select t :items '("alpha"))
                      (emacs-tui-view :id 'empty :multi-select t))
         :on-commit (lambda (&rest _) (setq called t)))
      (emacs-tui-toggle-mark session)
      (emacs-tui-next-view session)
      (should-error (emacs-tui-commit session) :type 'user-error)
      (should-not called))))

(ert-deftest emacs-tui-mark-provider-clear-invalidates-marks-before-next-result ()
  (let (publish)
    (emacs-tui-mark-test--workspace
        (:views (list (emacs-tui-view :id 'a :multi-select t)
                      (emacs-tui-view :id 'static :multi-select t :items '("static")))
         :debounce 60
         :provider (lambda (_ _query emit _fail) (setq publish emit) nil))
      (let ((request (emacs-tui--workspace-request session)))
        (cancel-timer (emacs-tui--request-timer request))
        (emacs-tui--start-provider request))
      (funcall publish 'a :items '("alpha"))
      (emacs-tui-toggle-mark session)
      (emacs-tui-next-view session)
      (emacs-tui-toggle-mark session)
      (emacs-tui-previous-view session)
      (insert "next")
      (should-not (emacs-tui-marked-items session))
      (should-not (funcall publish 'a :items '("alpha")))
      (should (equal '("static") (emacs-tui-marked-items session 'static)))
      (emacs-tui-update session 'a :items '("alpha"))
      (should-not (emacs-tui-marked-items session)))))

(ert-deftest emacs-tui-mark-layout-and-resize-preserve-query-and-marks ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t :items '("alpha" "beta"))
                    (emacs-tui-view :id 'b :items '("another"))))
    (insert "a")
    (goto-char 1)
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (dotimes (_ 3) (emacs-tui-cycle-layout session))
    (window-resize (emacs-tui--subtree session) 2)
    (run-hooks 'window-state-change-hook)
    (should (equal "a" (emacs-tui-query session)))
    (should (= 1 (point)))
    (should (equal "beta" (emacs-tui-current-item session)))
    (should (equal '("beta") (emacs-tui-marked-items session)))))

(ert-deftest emacs-tui-mark-keybindings-retain-normal-editing ()
  (emacs-tui-mark-test--workspace
      (:views (list (emacs-tui-view :id 'a :multi-select t :items '("alpha"))))
    (insert "al")
    (call-interactively (key-binding (kbd "C-c C-m")))
    (should (equal '("alpha") (emacs-tui-marked-items session)))
    (should (equal "al" (emacs-tui-query session)))
    (call-interactively (key-binding (kbd "C-c C-u")))
    (should-not (emacs-tui-marked-items session))
    (call-interactively (key-binding (kbd "C-b")))
    (should (= 2 (point)))))

(provide 'emacs-tui-mark-test)
;;; emacs-tui-mark-test.el ends here
