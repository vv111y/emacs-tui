;;; tty-reflow-probe.el --- Inject terminal reflow faults -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Set EMACS_TUI_REFLOW_FIXTURE to a resize fixture path, and
;; EMACS_TUI_REFLOW_FAULT to delay or disabled.  Load through run-tty-smoke.py.
;; Delay must pass; disabled must fail at the fixture's original polling bound.
;; The default smoke matrix checks representative delay and disabled cases.

;;; Code:
(setq load-prefer-newer t)
(require 'emacs-tui)

(defvar emacs-tui-test--reflow-pending nil)
(defvar emacs-tui-test--reflow-width nil)

(defun emacs-tui-test--delay-reflow (original &rest arguments)
  "Defer ORIGINAL with ARGUMENTS once per tested terminal resize."
  (let* ((session (car emacs-tui--sessions))
         (parent (and session (emacs-tui--workspace-origin-frame session)))
         (width (frame-width (if (frame-live-p parent) parent (selected-frame)))))
    (cond
     (emacs-tui-test--reflow-pending nil)
     ((and (memq width '(90 140)) (not (eql width emacs-tui-test--reflow-width)))
      (setq emacs-tui-test--reflow-width width
            emacs-tui-test--reflow-pending t)
      (run-at-time 0.3 nil
                   (lambda ()
                     (setq emacs-tui-test--reflow-pending nil)
                     (apply original arguments))))
     (t (apply original arguments)))))

(let ((fixture (getenv "EMACS_TUI_REFLOW_FIXTURE"))
      (fault (getenv "EMACS_TUI_REFLOW_FAULT")))
  (unless (and fixture (file-readable-p fixture))
    (error "Set EMACS_TUI_REFLOW_FIXTURE to a readable resize fixture"))
  (pcase fault
    ("delay" (advice-add 'emacs-tui--window-state-changed :around
                          #'emacs-tui-test--delay-reflow))
    ("disabled" (advice-add 'emacs-tui--window-state-changed :override #'ignore))
    (_ (error "EMACS_TUI_REFLOW_FAULT must be delay or disabled")))
  (load (expand-file-name fixture) nil t))

;;; tty-reflow-probe.el ends here
