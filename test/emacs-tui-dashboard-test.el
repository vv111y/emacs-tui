;;; emacs-tui-dashboard-test.el --- Persistent example integration -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise application actions and the real periodic update lifecycle.

;;; Code:
(require 'ert)
(require 'emacs-tui-dashboard (expand-file-name "examples/emacs-tui-dashboard.el"))

(ert-deftest emacs-tui-dashboard-actions-do-not-close-or-edit-source ()
  (save-window-excursion
    (delete-other-windows)
    (let ((source (generate-new-buffer "*Dashboard test source*")) session)
      (unwind-protect
          (progn
            (switch-to-buffer source)
            (insert "Unchanged")
            (setq session (emacs-tui-dashboard))
            (should-not (emacs-tui--workspace-query-buffer session))
            (dotimes (_ 3) (emacs-tui-next-view session))
            (should (eq 'refresh (plist-get (emacs-tui-current-item session) :id)))
            (emacs-tui-select session)
            (emacs-tui-next-item session)
            (should (equal "Pause updates" (plist-get (emacs-tui-current-item session) :label)))
            (execute-kbd-macro (kbd "P"))
            (should (equal "Resume updates" (plist-get (emacs-tui-current-item session) :label)))
            (execute-kbd-macro (kbd "P g"))
            (should (equal "Pause updates" (plist-get (emacs-tui-current-item session) :label)))
            (emacs-tui-select session)
            (should (equal "Resume updates" (plist-get (emacs-tui-current-item session) :label)))
            (emacs-tui-select session)
            (should (equal "Pause updates" (plist-get (emacs-tui-current-item session) :label)))
            (should (emacs-tui-live-p session))
            (should (equal "Unchanged" (with-current-buffer source (buffer-string)))))
        (when session (emacs-tui-close session))
        (kill-buffer source)))))

(ert-deftest emacs-tui-dashboard-periodic-refresh-outlives-launcher-and-stops ()
  (save-window-excursion
    (delete-other-windows)
    (let ((source (generate-new-buffer " *Dashboard launcher*"))
          (before (copy-sequence timer-list)) session fresh timers)
      (unwind-protect
          (progn
            (switch-to-buffer source)
            (setq session (emacs-tui-dashboard)
                  timers (cl-set-difference timer-list before)
                  fresh (generate-new-buffer "*New dashboard buffer*"))
            (should (= 1 (length timers)))
            (kill-buffer source)
            (let ((deadline (+ (float-time) 3)) found)
              (while (and (not found) (< (float-time) deadline))
                (accept-process-output nil 0.05)
                (setq found (cl-find fresh
                                     (emacs-tui--view-items
                                      (car (emacs-tui--workspace-views session)))
                                     :key (lambda (item) (plist-get item :id)) :test #'eq)))
              (should found))
            (should (emacs-tui-live-p session))
            (emacs-tui-close session)
            (should-not (cl-intersection timers timer-list))
            (should (buffer-live-p fresh)))
        (when session (emacs-tui-close session))
        (when (buffer-live-p source) (kill-buffer source))
        (when (buffer-live-p fresh) (kill-buffer fresh))))))

(ert-deftest emacs-tui-dashboard-initial-refresh-error-releases-application ()
  (save-window-excursion
    (delete-other-windows)
    (let ((buffers (buffer-list)) (timers (copy-sequence timer-list)))
      (cl-letf (((symbol-function 'emacs-tui-dashboard--buffers)
                 (lambda () (error "Injected snapshot failure"))))
        (should-error (emacs-tui-dashboard)))
      (should (equal buffers (buffer-list)))
      (should (equal timers timer-list))
      (should-not emacs-tui--sessions))))

(ert-deftest emacs-tui-dashboard-buffer-table-sorts-numeric-snapshots ()
  (save-window-excursion
    (delete-other-windows)
    (let ((small (generate-new-buffer "*Dashboard small*"))
          (large (generate-new-buffer "*Dashboard large*")) session)
      (unwind-protect
          (progn
            (with-current-buffer small (insert "xx"))
            (with-current-buffer large (insert "xxxxxxxxxx"))
            (setq session (emacs-tui-dashboard))
            (emacs-tui-sort session 'buffers 'size)
            (let ((buffers (mapcar (lambda (row) (plist-get row :value))
                                   (emacs-tui--view-visible-items
                                    (car (emacs-tui--workspace-views session))))))
              (should (< (cl-position small buffers) (cl-position large buffers)))))
        (when session (emacs-tui-close session))
        (kill-buffer small)
        (kill-buffer large)))))

(ert-deftest emacs-tui-dashboard-process-action-routes-to-buffer-without-editing ()
  (save-window-excursion
    (let* ((buffer (generate-new-buffer "*Dashboard process output*"))
           (process (make-pipe-process :name "dashboard-output" :buffer buffer :noquery t))
           session)
      (unwind-protect
          (progn
            (with-current-buffer buffer (insert "Unchanged process output"))
            (setq session (emacs-tui-dashboard))
            (emacs-tui-set-query session 'buffers "excluded-by-local-query")
            (emacs-tui-focus-view session 'processes)
            (emacs-tui-set-selection session 'processes process)
            (emacs-tui-act session 'buffer)
            (should (eq (emacs-tui-current-view session) 'buffers))
            (should (equal (emacs-tui-query session 'buffers) ""))
            (should (eq (plist-get (emacs-tui-current-item session) :value) buffer))
            (should (eq (emacs-tui-current-session) session))
            (should (emacs-tui-live-p session))
            (should (process-live-p process))
            (should (equal (with-current-buffer buffer (buffer-string))
                           "Unchanged process output"))
            (let ((preview (emacs-tui--resolve-view session 'preview)))
              (should (string-match-p "Unchanged process output"
                                      (with-current-buffer (emacs-tui--view-buffer preview)
                                        (buffer-string))))))
        (when session (emacs-tui-close session))
        (delete-process process)
        (kill-buffer buffer)))))

(ert-deftest emacs-tui-dashboard-process-action-refuses-hidden-or-killed-buffer ()
  (save-window-excursion
    (let* ((buffer (generate-new-buffer " *Hidden dashboard output*"))
           (process (make-pipe-process :name "dashboard-hidden" :buffer buffer :noquery t))
           session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-dashboard))
            (emacs-tui-focus-view session 'processes)
            (emacs-tui-set-selection session 'processes process)
            (should-error (emacs-tui-act session 'buffer) :type 'user-error)
            (should (eq (emacs-tui-current-view session) 'processes))
            (kill-buffer buffer)
            (should-error (emacs-tui-act session 'buffer) :type 'user-error)
            (should (emacs-tui-live-p session)))
        (when session (emacs-tui-close session))
        (when (process-live-p process) (delete-process process))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(provide 'emacs-tui-dashboard-test)
;;; emacs-tui-dashboard-test.el ends here
