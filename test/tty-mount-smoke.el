;;; tty-mount-smoke.el --- Exercise persistent native TTY views -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defvar emacs-tui-test--mount-session nil)
(defvar emacs-tui-test--mount-phase 1)
(defvar emacs-tui-test--mount-attempts 0)
(defvar emacs-tui-test--mount-small-width nil)
(defvar emacs-tui-test--mount-actions 0)
(defvar emacs-tui-test--mount-closed 0)

(defun emacs-tui-test--mount-failure (err)
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
    (insert (format "FAIL persistent: %S\n" err)))
  (kill-emacs 1))

(defun emacs-tui-test--mount-resized ()
  (condition-case err
      (let* ((session emacs-tui-test--mount-session)
             (parent (emacs-tui--workspace-origin-frame session))
             (child (emacs-tui--workspace-frame session))
             (backend (emacs-tui--workspace-backend session))
             (phase emacs-tui-test--mount-phase)
             (width (if (= phase 1) 90 140))
             (height (if (= phase 1) 30 45)))
        (cl-incf emacs-tui-test--mount-attempts)
        (when (> emacs-tui-test--mount-attempts 100)
          (error "Persistent resize phase %s did not settle" phase))
        (redisplay t)
        (when (and (= (frame-width parent) width)
                   (<= (- height 2) (frame-height parent) height)
                   ;; A frame can resize before the window-state hook reflows
                   ;; the owned surface.  Wait for that hook, without forcing it.
                   (equal (emacs-tui--workspace-geometry session)
                          (emacs-tui--geometry session))
                   (or (not child)
                       (and (< (frame-width child) width) (< (frame-height child) height)
                            (or (= phase 1) (> (frame-width child) emacs-tui-test--mount-small-width)))))
          (cl-assert (emacs-tui-live-p session))
          (cl-assert (null (emacs-tui--workspace-query-buffer session)))
          (cl-assert (null (emacs-tui--workspace-origin session)))
          (cl-assert (equal (emacs-tui--workspace-geometry session) (emacs-tui--geometry session)))
          (cl-assert (equal (emacs-tui-marked-items session 'items) '("beta")))
          (cl-assert (equal "Live 50%busy" (emacs-tui--view-title
                                          (car (emacs-tui--workspace-views session)))))
          (with-current-buffer (emacs-tui--view-buffer
                                (car (emacs-tui--workspace-views session)))
            (cl-assert (string-match-p (regexp-quote "Live 50%busy")
                                       (format-mode-line header-line-format))))
          (cl-assert (eq (window-buffer (selected-window))
                         (emacs-tui--view-buffer (cadr (emacs-tui--workspace-views session)))))
          (cl-assert (= emacs-tui-test--mount-actions 1))
          (cl-assert (= 3 (window-point (selected-window))))
          (if (= phase 1)
              (progn
                (setq emacs-tui-test--mount-small-width (when child (frame-width child))
                      emacs-tui-test--mount-phase 2
                      emacs-tui-test--mount-attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
            (execute-kbd-macro (kbd "<backtab> RET"))
            (cl-assert (= emacs-tui-test--mount-actions 2))
            (cl-assert (emacs-tui-live-p session))
            (execute-kbd-macro (kbd "q"))
            (cl-assert (not (emacs-tui-live-p session)))
            (cl-assert (= emacs-tui-test--mount-closed 1))
            (cl-assert (null emacs-tui--sessions))
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; real TTY; backend=%s; lifecycle=persistent; actions=2; resize=120x40->90x30->140x45\n"
                              emacs-version backend)))
            (kill-emacs 0))))
    ((error quit) (emacs-tui-test--mount-failure err))))

(defun emacs-tui-test--mount-start ()
  (condition-case err
      (let ((source (get-buffer-create "*Persistent smoke launcher*"))
            (backend (if (featurep 'tty-child-frames) 'child-frame 'windows)))
        (switch-to-buffer source)
        (erase-buffer)
        (insert "unchanged")
        (setq emacs-tui-test--mount-session
              (emacs-tui-mount
               :backend backend
               :views (list (emacs-tui-view
                             :id 'items :items '("alpha" "beta") :multi-select t
                             :on-select (lambda (app item)
                                          (cl-incf emacs-tui-test--mount-actions)
                                          (emacs-tui-update app 'preview :text item)))
                            (emacs-tui-view :id 'preview :text "pending"))
               :on-close (lambda (_) (cl-incf emacs-tui-test--mount-closed))))
        (emacs-tui-update emacs-tui-test--mount-session 'items :title "Live 50%busy")
        (execute-kbd-macro (kbd "C-c >"))
        (cl-assert (equal "beta" (emacs-tui-current-item emacs-tui-test--mount-session)))
        (execute-kbd-macro (kbd "C-c <"))
        (cl-assert (equal "alpha" (emacs-tui-current-item emacs-tui-test--mount-session)))
        (emacs-tui-set-selection emacs-tui-test--mount-session 'items "beta")
        (emacs-tui-focus-view emacs-tui-test--mount-session 'preview)
        (cl-assert (eq (emacs-tui-current-view emacs-tui-test--mount-session) 'preview))
        (cl-assert (equal (emacs-tui-current-item emacs-tui-test--mount-session 'items) "beta"))
        (cl-assert (zerop emacs-tui-test--mount-actions))
        (emacs-tui-focus-view emacs-tui-test--mount-session 'items)
        (emacs-tui-set-selection emacs-tui-test--mount-session 'items "alpha")
        (execute-kbd-macro (kbd "n C-c C-m RET TAB"))
        (goto-char 3)
        (execute-kbd-macro (kbd "TAB <backtab>"))
        (cl-assert (= 3 (point)))
        (cl-assert (equal (with-current-buffer source (buffer-string)) "unchanged"))
        (kill-buffer source)
        (cl-assert (emacs-tui-live-p emacs-tui-test--mount-session))
        (redisplay t)
        (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))
        (run-at-time 0.05 0.05 #'emacs-tui-test--mount-resized))
    ((error quit) (emacs-tui-test--mount-failure err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-test--mount-start)))
