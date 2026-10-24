;;; emacs-tui-mount-test.el --- Persistent lifecycle regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Persistent applications share views and resources without origin/query policy.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-mount-test--application (options &rest body)
  "Mount an application with OPTIONS, evaluate BODY, then release it."
  (declare (indent 1) (debug (form body)))
  `(save-window-excursion
     (delete-other-windows)
     (let ((source (generate-new-buffer " *mount-launcher*")) session)
       (unwind-protect
           (progn
             (switch-to-buffer source)
             (insert "launch context")
             (setq session (emacs-tui-mount :backend 'windows ,@options))
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p source) (kill-buffer source))))))

(ert-deftest emacs-tui-mount-needs-no-query-origin-or-commit ()
  (emacs-tui-mount-test--application
      (:views (list (emacs-tui-view :id 'a :items '("Alpha"))))
    (should (emacs-tui-live-p session))
    (should-not (emacs-tui--workspace-query-buffer session))
    (should-not (emacs-tui--workspace-origin session))
    (should (equal "" (emacs-tui-query session)))
    (should (equal "Alpha" (emacs-tui-current-item session)))
    (should-error (emacs-tui-commit session) :type 'user-error)
    (should (equal "launch context" (with-current-buffer source (buffer-string))))))

(ert-deftest emacs-tui-mount-outlives-launching-buffer ()
  (emacs-tui-mount-test--application
      (:views (list (emacs-tui-view :id 'a :items '("Alpha"))))
    (kill-buffer source)
    (should (emacs-tui-refresh session))
    (emacs-tui-update session 'a :items '("Updated"))
    (should (equal "Updated" (emacs-tui-current-item session)))))

(ert-deftest emacs-tui-mount-fits-a-small-window-without-query-overhead ()
  (save-window-excursion
    (delete-other-windows)
    (let ((window-min-height 2) session)
      (split-window (selected-window) 4 'below)
      (unwind-protect
          (progn
            (setq session (emacs-tui-mount
                           :views (list (emacs-tui-view :id 'a :items '("A")))))
            (should (emacs-tui-live-p session))
            (should (= 2 (window-total-height (emacs-tui--workspace-root session))))
            (should (equal "A" (emacs-tui-current-item session))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-mount-outlives-launching-window ()
  (emacs-tui-mount-test--application
      (:views (list (emacs-tui-view :id 'a :items '("Alpha"))))
    (delete-window (emacs-tui--workspace-origin-window session))
    (should (emacs-tui-refresh session))
    (emacs-tui-close session)
    (should-not (emacs-tui-live-p session))
    (should (= 1 (length (window-list))))
    (should (buffer-live-p (window-buffer (selected-window))))
    (should-not (buffer-local-value 'emacs-tui--session (window-buffer (selected-window))))))

(ert-deftest emacs-tui-mount-actions-change-state-and-stay-open ()
  (let ((count 0))
    (emacs-tui-mount-test--application
        (:views (list (emacs-tui-view
                       :id 'counter :items '("Increment")
                       :on-select
                       (lambda (app _item)
                         (cl-incf count)
                         (emacs-tui-update app 'status :text (number-to-string count))))
                      (emacs-tui-view :id 'status :text "0")))
      (dotimes (_ 3) (emacs-tui-select session))
      (should (= 3 count))
      (should (emacs-tui-live-p session))
      (should (equal "3" (emacs-tui--view-text (cadr (emacs-tui--workspace-views session)))))
      (should (equal "launch context" (with-current-buffer source (buffer-string)))))))

(ert-deftest emacs-tui-mount-native-view-navigation ()
  (emacs-tui-mount-test--application
      (:views (list (emacs-tui-view :id 'a :items '("A1" "A2"))
                    (emacs-tui-view :id 'b :items '("B1" "B2"))))
    (execute-kbd-macro (kbd "n TAB n"))
    (should (equal "B2" (emacs-tui-current-item session)))
    (should (eq (current-buffer) (emacs-tui--view-buffer (cadr (emacs-tui--workspace-views session)))))
    (execute-kbd-macro (kbd "<backtab>"))
    (should (equal "A2" (emacs-tui-current-item session)))))

(ert-deftest emacs-tui-mount-manually-selected-view-routes-actions ()
  (let (chosen)
    (emacs-tui-mount-test--application
        (:views (list (emacs-tui-view :id 'a :items '("A"))
                      (emacs-tui-view :id 'b :items '("B")
                                      :on-select (lambda (_ item) (setq chosen item)))))
      (select-window (emacs-tui--view-window (cadr (emacs-tui--workspace-views session))))
      (run-hooks 'post-command-hook)
      (let ((views (emacs-tui--workspace-views session)))
        (should (string-prefix-p "  " (buffer-local-value 'header-line-format (emacs-tui--view-buffer (car views)))))
        (should (string-prefix-p "* " (buffer-local-value 'header-line-format (emacs-tui--view-buffer (cadr views))))))
      (call-interactively #'emacs-tui-select)
      (should (equal chosen "B")))))

(ert-deftest emacs-tui-mount-reflow-retains-native-focus-and-marks ()
  (emacs-tui-mount-test--application
      (:views (list (emacs-tui-view :id 'a :items '("A"))
                    (emacs-tui-view :id 'b :multi-select t :items '("B1" "B2"))))
    (emacs-tui-next-view session)
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-cycle-layout session)
    (should (eq (current-buffer) (emacs-tui--view-buffer (cadr (emacs-tui--workspace-views session)))))
    (should (equal '("B2") (emacs-tui-marked-items session)))
    (should (equal "B2" (emacs-tui-current-item session)))))

(ert-deftest emacs-tui-mount-refresh-preserves-unrelated-selection ()
  (emacs-tui-mount-test--application
      (:views (list (emacs-tui-view :id 'a :items '("A"))))
    (let ((window (emacs-tui--workspace-origin-window session)))
      (select-window window)
      (emacs-tui-refresh session)
      (should (eq window (selected-window))))))

(ert-deftest emacs-tui-mount-repurposed-surface-is-preserved ()
  (let ((foreign (generate-new-buffer " *mount-foreign*")))
    (unwind-protect
        (emacs-tui-mount-test--application
            (:views (list (emacs-tui-view :id 'a :items '("A"))))
          (let ((root (emacs-tui--workspace-root session)))
            (set-window-buffer root foreign)
            (should-not (emacs-tui-refresh session))
            (should (window-live-p root))
            (should (eq foreign (window-buffer root)))))
      (kill-buffer foreign))))

(ert-deftest emacs-tui-mount-async-startup-and-close-order ()
  (let (publish received-query closed (cancelled 0))
    (emacs-tui-mount-test--application
        (:views (list (emacs-tui-view :id 'a)) :debounce 60
         :provider (lambda (_ query emit _fail)
                     (setq received-query query publish emit)
                     (funcall emit 'a :items '("Async"))
                     (lambda () (cl-incf cancelled)))
         :on-close (lambda (app) (setq closed (list (emacs-tui-live-p app) cancelled))))
      (let* ((request (emacs-tui--workspace-request session))
             (timer (emacs-tui--request-timer request)))
        (cancel-timer timer)
        (emacs-tui--start-provider request))
      (should (equal "" received-query))
      (should (equal "Async" (emacs-tui-current-item session)))
      (emacs-tui-close session)
      (should (equal '(nil 1) closed))
      (should-not (funcall publish 'a :items '("Late"))))))

(ert-deftest emacs-tui-close-callback-once-for-both-lifecycles ()
  (dolist (opener '(emacs-tui-open emacs-tui-mount))
    (save-window-excursion
      (delete-other-windows)
      (let ((count 0) session)
        (unwind-protect
            (progn
              (setq session (funcall opener :backend 'windows
                                     :views (list (emacs-tui-view :id 'a :items '("A")))
                                     :on-close (lambda (app)
                                                 (should-not (emacs-tui-live-p app))
                                                 (cl-incf count))))
              (emacs-tui-close session)
              (emacs-tui-close session)
              (should (= 1 count)))
          (when session (emacs-tui-close session)))))))

(ert-deftest emacs-tui-mount-killed-view-runs-close-callback ()
  (let ((count 0))
    (emacs-tui-mount-test--application
        (:views (list (emacs-tui-view :id 'a :items '("A")))
         :on-close (lambda (_) (cl-incf count)))
      (kill-buffer (emacs-tui--view-buffer (car (emacs-tui--workspace-views session))))
      (should-not (emacs-tui-live-p session))
      (should (= 1 count)))))

(ert-deftest emacs-tui-mount-startup-failure-closes-allocated-resources ()
  (let ((before (buffer-list)) (count 0))
    (cl-letf (((symbol-function 'emacs-tui--make-surface) (lambda (&rest _) (error "Failure"))))
      (should-error
       (emacs-tui-mount :views (list (emacs-tui-view :id 'a))
                        :on-close (lambda (_) (cl-incf count)))))
    (should (= 1 count))
    (should (equal before (buffer-list)))))

(ert-deftest emacs-tui-mount-close-callback-failure-does-not-leak ()
  (dolist (condition '(error quit))
    (emacs-tui-mount-test--application
        (:views (list (emacs-tui-view :id 'a))
         :on-close (lambda (_) (signal condition '("Close failed"))))
      (let ((buffer (emacs-tui--view-buffer (car (emacs-tui--workspace-views session)))))
        (emacs-tui-close session)
        (should-not (buffer-live-p buffer))
        (should-not (memq session emacs-tui--sessions))))))

(provide 'emacs-tui-mount-test)
;;; emacs-tui-mount-test.el ends here
