;;; emacs-tui-provider-test.el --- Provider lifecycle regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Deterministic provider callback delivery with real owned debounce timers.
;; The integration suite separately covers actual asynchronous process output.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-provider-test--workspace (options &rest body)
  "Open a workspace with OPTIONS and evaluate BODY, then close it."
  (declare (indent 1) (debug (form body)))
  `(save-window-excursion
     (delete-other-windows)
     (let ((source (generate-new-buffer " *tui-provider-source*")) session)
       (unwind-protect
           (progn
             (switch-to-buffer source)
             (insert "origin")
             (setq session
                   (emacs-tui-open
                    :backend 'windows
                    :views (list (emacs-tui-view :id 'results)
                                 (emacs-tui-view :id 'static :text "Static help"))
                    ,@options))
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p source) (kill-buffer source))))))

(defun emacs-tui-provider-test--deliver (session)
  "Deliver SESSION's currently pending timer without waiting for wall time."
  (let* ((request (emacs-tui--workspace-request session))
         (timer (emacs-tui--request-timer request)))
    (should (timerp timer))
    (cancel-timer timer)
    (emacs-tui--start-provider request)))

(ert-deftest emacs-tui-provider-debounce-supersedes-pending-timer ()
  (let (queries)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider (lambda (_ query _publish _fail) (push query queries) nil))
      (let* ((previous (emacs-tui--workspace-request session))
             (timer (emacs-tui--request-timer previous)))
        (should (memq timer timer-list))
        (insert "latest")
        (should-not (memq timer timer-list))
        (should-not (emacs-tui--request-current-p previous))
        (should-not queries)
        (emacs-tui-provider-test--deliver session)
        (should (equal '("latest") queries))))))

(ert-deftest emacs-tui-provider-zero-delay-still-defers-start ()
  (let (started)
    (emacs-tui-provider-test--workspace
        (:debounce 0 :provider (lambda (&rest _) (setq started t) nil))
      (should-not started)
      (should (timerp (emacs-tui--request-timer (emacs-tui--workspace-request session))))
      (emacs-tui-provider-test--deliver session)
      (should started))))

(ert-deftest emacs-tui-provider-streams-replacements-and-preserves-identity ()
  (let (publish)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider (lambda (_ _query emit _fail) (setq publish emit) nil))
      (insert "semantic query")
      (emacs-tui-provider-test--deliver session)
      (should (funcall publish 'results :items '((:id 1 :label "A") (:id 2 :label "B"))))
      (emacs-tui-next-item session)
      (should (funcall publish 'results :items '((:id 2 :label "New B") (:id 3 :label "C"))))
      (should (= 2 (plist-get (emacs-tui-current-item session) :id)))
      (with-current-buffer source (should (equal "origin" (buffer-string)))))))

(ert-deftest emacs-tui-provider-clears-owned-results-before-next-start ()
  (let (publish)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider (lambda (_ _query emit _fail) (setq publish emit) nil))
      (emacs-tui-provider-test--deliver session)
      (funcall publish 'results :items '("old"))
      (insert "new")
      (should-not (emacs-tui-current-item session))
      (should-error (emacs-tui-select session) :type 'user-error)
      (should (equal "Static help"
                     (emacs-tui--view-text
                      (cadr (emacs-tui--workspace-views session))))))))

(ert-deftest emacs-tui-provider-rejects-stale-results-and-errors ()
  (let (publish fail (cancelled 0))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (_ _query emit reject)
           (setq publish emit fail reject)
           (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (insert "next")
      (should (= 1 cancelled))
      (should-not (funcall publish 'results :items '("obsolete")))
      (should-not (funcall fail "obsolete error"))
      (should-not (emacs-tui-current-item session)))))

(ert-deftest emacs-tui-provider-cancel-cannot-publish-old-generation ()
  (let ((cancelled 0) accepted)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (_ _query publish _fail)
           (lambda ()
             (cl-incf cancelled)
             (setq accepted (funcall publish 'results :items '("cancelled"))))))
      (emacs-tui-provider-test--deliver session)
      (insert "next")
      (should (= 1 cancelled))
      (should-not accepted)
      (should-not (emacs-tui-current-item session)))))

(ert-deftest emacs-tui-provider-close-cancels-pending-timer ()
  (let (started)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider (lambda (&rest _) (setq started t) nil))
      (let* ((request (emacs-tui--workspace-request session))
             (timer (emacs-tui--request-timer request)))
        (emacs-tui-close session)
        (should-not (memq timer timer-list))
        (emacs-tui--start-provider request)
        (should-not started)
        (should-not (emacs-tui--workspace-request session))))))

(ert-deftest emacs-tui-provider-close-cancels-worker-once ()
  (let ((cancelled 0) publish)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (_ _query emit _fail)
           (setq publish emit)
           (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (emacs-tui-close session)
      (emacs-tui-close session)
      (should (= 1 cancelled))
      (should-not (funcall publish 'results :items '("late"))))))

(ert-deftest emacs-tui-provider-failure-cancels-and-next-query-recovers ()
  (let ((cancelled 0) publish fail)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (_ _query emit reject)
           (setq publish emit fail reject)
           (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (should (funcall fail "Connection failed"))
      (should (= 1 cancelled))
      (should-not (funcall publish 'results :items '("late")))
      (insert "retry")
      (emacs-tui-provider-test--deliver session)
      (should (funcall publish 'results :items '("Recovered")))
      (should (equal "Recovered" (emacs-tui-current-item session))))))

(ert-deftest emacs-tui-provider-invalid-publication-is-atomic ()
  (let ((cancelled 0) publish)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (_ _query emit _fail)
           (setq publish emit)
           (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (funcall publish 'results :items '("Valid"))
      (should-not (funcall publish 'results :items '("Bad") :text 42))
      (should (= 1 cancelled))
      (should (equal "Valid" (emacs-tui-current-item session))))))

(ert-deftest emacs-tui-provider-reentrant-query-disposes-returned-cancel ()
  (let ((cancelled 0))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (workspace _query _publish _fail)
           (with-current-buffer (emacs-tui--workspace-query-buffer workspace)
             (insert "newer"))
           (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (should (= 1 cancelled))
      (should (timerp (emacs-tui--request-timer (emacs-tui--workspace-request session)))))))

(ert-deftest emacs-tui-provider-reentrant-close-disposes-returned-cancel ()
  (let ((cancelled 0))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (workspace _query _publish _fail)
           (emacs-tui-close workspace)
           (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (should (= 1 cancelled))
      (should-not (emacs-tui--workspace-active session)))))

(ert-deftest emacs-tui-provider-synchronous-failure-disposes-returned-cancel ()
  (let ((cancelled 0))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (_ _query _publish fail)
           (funcall fail '(error "Startup failed"))
           (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (should (= 1 cancelled))
      (should-not (emacs-tui--workspace-request session)))))

(ert-deftest emacs-tui-provider-errors-and-quits-do-not-disable-input ()
  (dolist (signal '(error quit))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider (lambda (&rest _) (signal signal '("Failure"))))
      (emacs-tui-provider-test--deliver session)
      (should (emacs-tui--workspace-active session))
      (insert "retry")
      (should (memq #'emacs-tui--query-changed after-change-functions))
      (should (emacs-tui--workspace-request session)))))

(ert-deftest emacs-tui-provider-cancel-errors-and-quits-do-not-break-disposal ()
  (dolist (signal '(error quit))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (&rest _) (lambda () (signal signal '("Cancellation failed")))))
      (emacs-tui-provider-test--deliver session)
      (emacs-tui-close session)
      (should-not (emacs-tui--workspace-request session))
      (should (= 1 (length (window-list)))))))

(ert-deftest emacs-tui-provider-cancel-throw-leaves-no-owned-resources ()
  (emacs-tui-provider-test--workspace
      (:debounce 60 :provider (lambda (&rest _) (lambda () (throw 'cancel 'cancelled))))
    (emacs-tui-provider-test--deliver session)
    (should (eq 'cancelled (catch 'cancel (emacs-tui-close session))))
    (should-not (emacs-tui--workspace-active session))
    (should-not (emacs-tui--workspace-request session))
    (should (= 1 (length (window-list))))))

(ert-deftest emacs-tui-provider-start-throw-invalidates-generation ()
  (emacs-tui-provider-test--workspace
      (:debounce 60 :provider (lambda (&rest _) (throw 'cancel 'cancelled)))
    (should (eq 'cancelled (catch 'cancel (emacs-tui-provider-test--deliver session))))
    (should-not (emacs-tui--workspace-request session))
    (should (emacs-tui--workspace-active session))))

(ert-deftest emacs-tui-provider-configuration-validates-before-allocation ()
  (let ((buffers (buffer-list)) (view (emacs-tui-view :id 'a)))
    (should-error (emacs-tui-open :views (list view) :provider #'ignore :on-query #'ignore))
    (dolist (delay (list -1 'invalid 1.0e+INF 0.0e+NaN))
      (should-error (emacs-tui-open :views (list view) :provider #'ignore :debounce delay)))
    (should (equal buffers (buffer-list)))))

(ert-deftest emacs-tui-provider-cancels-before-scheduling-reentrant-query ()
  (let (queries (cancelled 0) timer-during-cancel)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (workspace query _publish _fail)
           (push query queries)
           (lambda ()
             (cl-incf cancelled)
             (when (= cancelled 1)
               (setq timer-during-cancel
                     (emacs-tui--request-timer (emacs-tui--workspace-request workspace)))
               (with-current-buffer (emacs-tui--workspace-query-buffer workspace)
                 (insert "-newest"))))))
      (emacs-tui-provider-test--deliver session)
      (insert "next")
      (should-not timer-during-cancel)
      (emacs-tui-provider-test--deliver session)
      (should (equal '("next-newest" "") queries)))))

(ert-deftest emacs-tui-provider-cancel-throw-removes-unscheduled-replacement ()
  (emacs-tui-provider-test--workspace
      (:debounce 60 :provider
       (lambda (&rest _) (lambda () (throw 'cancel 'cancelled))))
    (emacs-tui-provider-test--deliver session)
    (should (eq 'cancelled (catch 'cancel (insert "next"))))
    (should-not (emacs-tui--workspace-request session))
    (should (emacs-tui--workspace-active session))))

(ert-deftest emacs-tui-provider-close-disposal-error-still-cancels-worker ()
  (let ((cancelled 0))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider (lambda (&rest _) (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (let* ((buffers (cons (emacs-tui--workspace-query-buffer session)
                            (mapcar #'emacs-tui--view-buffer
                                    (emacs-tui--workspace-views session))))
             (hook (lambda () (error "Injected buffer disposal failure"))))
        (unwind-protect
            (progn
              (with-current-buffer (car buffers) (add-hook 'kill-buffer-hook hook nil t))
              (should-error (emacs-tui-close session))
              (should (= 1 cancelled))
              (should-not (emacs-tui--workspace-request session))
              (should-not (memq #'emacs-tui--window-state-changed window-state-change-hook)))
          (dolist (buffer buffers)
            (when (buffer-live-p buffer)
              (with-current-buffer buffer (remove-hook 'kill-buffer-hook hook t))
              (kill-buffer buffer)))
          (set-marker (emacs-tui--workspace-origin session) nil))))))

(ert-deftest emacs-tui-provider-refresh-does-not-restart-or-cancel-worker ()
  (let ((started 0) (cancelled 0))
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider
         (lambda (&rest _) (cl-incf started) (lambda () (cl-incf cancelled))))
      (emacs-tui-provider-test--deliver session)
      (emacs-tui-refresh session)
      (emacs-tui-cycle-layout session)
      (should (= 1 started))
      (should (= 0 cancelled)))))

(ert-deftest emacs-tui-provider-sessions-have-independent-generations ()
  (let* ((publishers (make-hash-table :test #'eq))
        (cancelled (make-hash-table :test #'eq))
        (provider (lambda (workspace _query publish _fail)
                    (puthash workspace publish publishers)
                    (lambda () (puthash workspace t cancelled))))
        second)
    (emacs-tui-provider-test--workspace
        (:debounce 60 :provider provider)
      (unwind-protect
          (progn
            (emacs-tui-provider-test--deliver session)
            (select-window (emacs-tui--workspace-origin-window session))
            (setq second (emacs-tui-open
                          :backend 'windows :debounce 60 :provider provider
                          :views (list (emacs-tui-view :id 'results))))
            (emacs-tui-provider-test--deliver second)
            (with-current-buffer (emacs-tui--workspace-query-buffer session)
              (insert "first only"))
            (should (gethash session cancelled))
            (should-not (gethash second cancelled))
            (should-not (funcall (gethash session publishers) 'results :items '("stale")))
            (should (funcall (gethash second publishers) 'results :items '("current")))
            (should (equal "current" (emacs-tui-current-item second))))
        (when second (emacs-tui-close second))))))

(provide 'emacs-tui-provider-test)
;;; emacs-tui-provider-test.el ends here
