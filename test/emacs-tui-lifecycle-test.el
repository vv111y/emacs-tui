;;; emacs-tui-lifecycle-test.el --- Repeated resource ownership checks -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise real timer dispatch and application-owned pipe processes across
;; repeated ephemeral, persistent and embedded lifetimes.  Also reused by the
;; interactive terminal fixture so native child-frame disposal is exercised.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defun emacs-tui-test--await (predicate)
  "Dispatch events until PREDICATE succeeds, or fail after two seconds."
  (let ((deadline (+ (float-time) 2)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.01))
    (should (funcall predicate))))

(defun emacs-tui-test--lifecycle-cycles (count backend)
  "Exercise COUNT lifetimes with BACKEND and an unrelated live embedded panel."
  (save-window-excursion
    (delete-other-windows)
    (let* ((source (generate-new-buffer " *tui-stress-source*"))
           (anchor-source (generate-new-buffer " *tui-stress-anchor*"))
           (source-window (selected-window))
           (anchor-window (split-window-right))
           (sessions (copy-sequence emacs-tui--sessions))
           (frame-hook (copy-sequence delete-frame-functions))
           (window-hook (copy-sequence window-state-change-hook))
           anchor)
      (unwind-protect
          (progn
            (switch-to-buffer source)
            (insert "origin")
            (set-window-buffer anchor-window anchor-source)
            (setq anchor
                  (emacs-tui-embed
                   :window anchor-window
                   :view (emacs-tui-view :id 'anchor :items '("alpha" "beta")
                                         :multi-select t)))
            (emacs-tui-toggle-mark anchor)
            (emacs-tui-set-selection anchor 'anchor "beta")
            (dotimes (index count)
              (let* ((kind (mod index 3))
                     (pending (= (mod index 5) 0))
                     (closed 0) (started 0) (cancelled 0)
                     (frames (frame-list))
                     (windows (window-list (window-frame source-window) nil source-window))
                     session buffers markers request debounce resources origin-hook)
                (unwind-protect
                    (progn
                      (select-window source-window)
                      (set-window-buffer source-window source)
                      (with-current-buffer source (erase-buffer) (insert "origin"))
                      (goto-char 4)
                      (let* ((view (emacs-tui-view :id 'items :multi-select t))
                             (provider
                              (lambda (_session _query publish fail)
                                (cl-incf started)
                                (let* ((buffer (generate-new-buffer " *tui-stress-worker*"))
                                       (process (make-pipe-process
                                                 :name "tui-stress" :buffer buffer :noquery t))
                                       (timer (run-at-time 60 60 #'ignore)))
                                  (push (list process timer buffer publish fail) resources)
                                  (funcall publish 'items :items '("alpha" "beta"))
                                  (lambda ()
                                    (cl-incf cancelled)
                                    (cancel-timer timer)
                                    (delete-process process)
                                    (kill-buffer buffer)))))
                             (options (list :provider provider :debounce (if pending 60 0)
                                            :on-close (lambda (_) (cl-incf closed)))))
                        (setq session
                              (if (= kind 2)
                                  (apply #'emacs-tui-embed :view view :window source-window options)
                                (apply (if (= kind 0) #'emacs-tui-open #'emacs-tui-mount)
                                       :backend backend :views (list view) options))))
                      (setq origin-hook (emacs-tui--workspace-origin-kill-hook session)
                            request (emacs-tui--workspace-request session)
                            debounce (emacs-tui--request-timer request)
                            buffers (delq nil (cons (emacs-tui--workspace-query-buffer session)
                                                   (mapcar #'emacs-tui--view-buffer
                                                           (emacs-tui--workspace-views session))))
                            markers
                            (if (= kind 2)
                                (let ((host (emacs-tui--workspace-host session)))
                                  (list (emacs-tui--host-point host) (emacs-tui--host-start host)))
                              (delq nil (list (emacs-tui--workspace-origin session)))))
                      (if pending
                          (should (memq debounce timer-list))
                        (emacs-tui-test--await (lambda () (= started 1)))
                        (emacs-tui-set-selection session 'items "beta")
                        (when (= kind 0)
                          ;; Supersede real work, then try the obsolete generation
                          ;; while the replacement is live, not just after close.
                          (let ((old (car resources)))
                            (with-current-buffer (emacs-tui--workspace-query-buffer session)
                              (goto-char (point-max)) (insert "a"))
                            (should (= cancelled 1))
                            (should-not (funcall (nth 3 old) 'items :items '("obsolete")))
                            (should-not (funcall (nth 4 old) "obsolete failure"))
                            (emacs-tui-test--await (lambda () (= started 2)))
                            (should (equal "alpha" (emacs-tui-current-item session 'items))))))
                      (when (= kind 2)
                        ;; Host edits belong to the application and must survive.
                        (with-current-buffer source (goto-char 1) (insert "new")))
                      (if (= (mod index 2) 0)
                          (emacs-tui-close session)
                        (kill-buffer (car buffers)))
                      (emacs-tui-close session)
                      (should-not (emacs-tui-live-p session))
                      (should (= closed 1))
                      (should (= cancelled started))
                      (should-not (emacs-tui--request-current-p request))
                      (should-not (emacs-tui--workspace-request session))
                      (when origin-hook
                        (should-not (memq origin-hook
                                          (buffer-local-value 'kill-buffer-hook source))))
                      (should-not (memq debounce timer-list))
                      (dolist (buffer buffers) (should-not (buffer-live-p buffer)))
                      (dolist (marker markers) (should-not (marker-buffer marker)))
                      (dolist (resource resources)
                        (should-not (process-live-p (nth 0 resource)))
                        (should-not (memq (nth 0 resource) (process-list)))
                        (should-not (memq (nth 1 resource) timer-list))
                        (should-not (buffer-live-p (nth 2 resource)))
                        (should-not (funcall (nth 3 resource) 'items :items '("late")))
                        (should-not (funcall (nth 4 resource) "late failure")))
                      (should (equal frames (frame-list)))
                      (should (equal windows (window-list (window-frame source-window) nil source-window)))
                      (should (eq source (window-buffer source-window)))
                      (should-not (window-parameter source-window 'emacs-tui-session))
                      (should (equal (if (= kind 2) "neworigin" "origin")
                                     (with-current-buffer source (buffer-string))))
                      (when (= kind 2) (should (= 7 (window-point source-window))))
                      (should (emacs-tui-live-p anchor))
                      (should (eq anchor (buffer-local-value 'emacs-tui--session
                                                            (window-buffer anchor-window))))
                      (should (equal "beta" (emacs-tui-current-item anchor 'anchor)))
                      (should (equal '("alpha") (emacs-tui-marked-items anchor 'anchor)))
                      (should (equal (cons anchor sessions) emacs-tui--sessions)))
                  (when session (emacs-tui-close session))
                  ;; Failure cleanup must not leave the test runner with work.
                  (dolist (resource resources)
                    (cancel-timer (nth 1 resource))
                    (when (process-live-p (nth 0 resource)) (delete-process (nth 0 resource)))
                    (when (buffer-live-p (nth 2 resource)) (kill-buffer (nth 2 resource)))))))
            (emacs-tui-close anchor)
            (should (equal sessions emacs-tui--sessions))
            (should (equal frame-hook delete-frame-functions))
            (should (equal window-hook window-state-change-hook))
            (should (eq anchor-source (window-buffer anchor-window))))
        (when anchor (emacs-tui-close anchor))
        (when (buffer-live-p source) (kill-buffer source))
        (when (buffer-live-p anchor-source) (kill-buffer anchor-source))))))

(ert-deftest emacs-tui-lifecycle-repeated-ownership-and-cancellation ()
  (emacs-tui-test--lifecycle-cycles 75 'windows))

(provide 'emacs-tui-lifecycle-test)
;;; emacs-tui-lifecycle-test.el ends here
