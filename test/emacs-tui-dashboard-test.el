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

(provide 'emacs-tui-dashboard-test)
;;; emacs-tui-dashboard-test.el ends here
