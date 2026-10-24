;;; tty-embed-smoke.el --- Exercise embedded native TTY views -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defvar emacs-tui-test--embed-session nil)
(defvar emacs-tui-test--embed-phase 1)
(defvar emacs-tui-test--embed-attempts 0)
(defvar emacs-tui-test--embed-small-width nil)
(defvar emacs-tui-test--embed-actions 0)
(defvar emacs-tui-test--embed-closed 0)
(defvar emacs-tui-test--embed-host nil)
(defvar emacs-tui-test--embed-window nil)
(defvar emacs-tui-test--embed-command-session nil)

(defun emacs-tui-test--embed-failure (err)
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
    (insert (format "FAIL embedded: %S\n" err)))
  (kill-emacs 1))

(defun emacs-tui-test--embed-resized ()
  (condition-case err
      (let* ((session emacs-tui-test--embed-session)
             (parent (emacs-tui--workspace-origin-frame session))
             (child (emacs-tui--workspace-frame session))
             (backend (emacs-tui--workspace-backend session))
             (phase emacs-tui-test--embed-phase)
             (width (if (= phase 1) 90 140))
             (height (if (= phase 1) 30 45)))
        (cl-incf emacs-tui-test--embed-attempts)
        (when (> emacs-tui-test--embed-attempts 100)
          (error "Embedded resize phase %s did not settle" phase))
        (redisplay t)
        (when (and (= (frame-width parent) width)
                   (<= (- height 2) (frame-height parent) height)
                   ;; Wait for the automatic hook, within the existing bound.
                   (equal (emacs-tui--workspace-geometry session)
                          (emacs-tui--geometry session))
                   (or (not child)
                       (and (< (frame-width child) width) (< (frame-height child) height)
                            (or (= phase 1) (> (frame-width child) emacs-tui-test--embed-small-width)))))
          (cl-assert (emacs-tui-live-p session))
          (cl-assert (null (emacs-tui--workspace-query-buffer session)))
          (cl-assert (null (emacs-tui--workspace-origin session)))
          (cl-assert (equal (emacs-tui--workspace-geometry session) (emacs-tui--geometry session)))
          (cl-assert (equal (emacs-tui-marked-items session 'items) '("beta")))
          (cl-assert (eq (window-buffer (selected-window))
                         (emacs-tui--view-buffer (car (emacs-tui--workspace-views session)))))
          (cl-assert (= emacs-tui-test--embed-actions 1))
          (if (= phase 1)
              (progn
                (setq emacs-tui-test--embed-small-width (when child (frame-width child))
                      emacs-tui-test--embed-phase 2
                      emacs-tui-test--embed-attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
            (execute-kbd-macro (kbd "<backtab> RET"))
            (cl-assert (= emacs-tui-test--embed-actions 2))
            (cl-assert (emacs-tui-live-p session))
            (execute-kbd-macro (kbd "q"))
            (cl-assert (not (emacs-tui-live-p session)))
            (cl-assert (= emacs-tui-test--embed-closed 1))
            (cl-assert (null emacs-tui--sessions))
            (cl-assert (window-live-p emacs-tui-test--embed-window))
            (cl-assert (eq emacs-tui-test--embed-host
                           (window-buffer emacs-tui-test--embed-window)))
            (cl-assert (equal (with-current-buffer emacs-tui-test--embed-host
                                (buffer-string)) "unchanged"))
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; real TTY; backend=%s; lifecycle=embedded; actions=2; resize=120x40->90x30->140x45\n"
                              emacs-version backend)))
            (kill-emacs 0))))
    ((error quit) (emacs-tui-test--embed-failure err))))

(defun emacs-tui-test--embed-start ()
  (condition-case err
      (let ((source (get-buffer-create "*Embedded smoke host*"))
            (keymap (make-sparse-keymap)))
        (define-key keymap (kbd "r")
          (lambda () (interactive)
            (setq emacs-tui-test--embed-command-session (emacs-tui-current-session))))
        (switch-to-buffer source)
        (erase-buffer)
        (insert "unchanged")
        (setq emacs-tui-test--embed-host source
              emacs-tui-test--embed-window (selected-window)
              emacs-tui-test--embed-session
              (emacs-tui-embed
               :keymap keymap
               :view (emacs-tui-view
                      :id 'items :items '("alpha" "beta") :multi-select t
                      :on-select (lambda (_app _item)
                                   (cl-incf emacs-tui-test--embed-actions)))
               :on-close (lambda (_) (cl-incf emacs-tui-test--embed-closed))))
        (execute-kbd-macro (kbd "n C-c C-m RET r"))
        (cl-assert (eq emacs-tui-test--embed-command-session emacs-tui-test--embed-session))
        (cl-assert (= 1 (length (window-list))))
        (cl-assert (equal (with-current-buffer source (buffer-string)) "unchanged"))
        (redisplay t)
        (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))
        (run-at-time 0.05 0.05 #'emacs-tui-test--embed-resized))
    ((error quit) (emacs-tui-test--embed-failure err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-test--embed-start)))
