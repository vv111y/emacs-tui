;;; tty-lifecycle-smoke.el --- Repeated native TTY disposal -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Run the resource assertions at three actual terminal sizes.  The existing
;; PTY coordinator supplies SIGWINCH and requires both resize handshakes.

;;; Code:
(setq load-prefer-newer t)
(load "test/emacs-tui-lifecycle-test.el" nil t)
(declare-function emacs-tui-test--lifecycle-cycles "emacs-tui-lifecycle-test" (count backend))

(defvar emacs-tui-test--stress-phase 0)
(defvar emacs-tui-test--stress-attempts 0)
(defvar emacs-tui-test--stress-timer nil)

(defun emacs-tui-test--stress-step ()
  "Run repeated lifetimes once the next terminal size has settled."
  (condition-case err
      (let* ((phase emacs-tui-test--stress-phase)
             (width (nth phase '(120 90 140)))
             (height (nth phase '(40 30 45)))
             (backend (if (featurep 'tty-child-frames) 'child-frame 'windows)))
        (cl-incf emacs-tui-test--stress-attempts)
        (when (> emacs-tui-test--stress-attempts 100)
          (error "Lifecycle terminal resize did not settle"))
        (redisplay t)
        (when (and (= (frame-width) width)
                   (<= (- height 2) (frame-height) height))
          ;; Each batch has five ephemeral, persistent and embedded sessions,
          ;; plus one live embedded anchor, with real providers and cancellations.
          (emacs-tui-test--lifecycle-cycles 15 backend)
          (if (< phase 2)
              (progn
                (cl-incf emacs-tui-test--stress-phase)
                (setq emacs-tui-test--stress-attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY")
                  (insert (number-to-string emacs-tui-test--stress-phase))))
            (cancel-timer emacs-tui-test--stress-timer)
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; real TTY; backend=%s; lifetimes=45; sizes=120x40,90x30,140x45; resources=timers,processes,buffers,markers,windows,frames; live-session-isolation\n"
                              emacs-version backend)))
            (kill-emacs 0))))
    ((error quit)
     (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
       (insert (format "FAIL lifecycle phase=%s: %S\n" emacs-tui-test--stress-phase err)))
     (kill-emacs 1))))

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq emacs-tui-test--stress-timer
                  (run-at-time 0.1 0.05 #'emacs-tui-test--stress-step))))

;;; tty-lifecycle-smoke.el ends here
