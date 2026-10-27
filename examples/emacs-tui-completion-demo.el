;;; emacs-tui-completion-demo.el --- Native Emacs Lisp completion in a popup -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; make completion-demo starts a disposable Emacs Lisp buffer.  Unlike the
;; literal-data popup demo, this uses Emacs's own elisp-completion-at-point.
;; In any supported source buffer, require emacs-tui-completion and enable
;; emacs-tui-completion-mode, then invoke completion-at-point normally.

;;; Code:
(require 'emacs-tui-completion)
(require 'elisp-mode)

(defun emacs-tui-completion-demo ()
  "Open a disposable Lisp source with native completion candidates.
Use `emacs-tui-completion-next' and `emacs-tui-completion-previous' to select,
`emacs-tui-completion-accept' to accept, `emacs-tui-completion-move' to move,
and `emacs-tui-completion-dismiss' to dismiss.
Ordinary `completion-at-point' starts another completion.  No code is evaluated
and no file is saved.  Disable `emacs-tui-completion-mode' to restore the prior
completion frontend in this buffer."
  (interactive)
  (unless (emacs-tui-popup-supported-p)
    (user-error "This demo needs graphical or native TTY child frames"))
  (switch-to-buffer (generate-new-buffer "*TUI native Lisp completion*"))
  (emacs-lisp-mode)
  (insert ";; Native Emacs Lisp completion, using your usual completion styles.\n"
          ";; C-M-i: begin   M-n/M-p: select   TAB: accept   C-g: dismiss\n"
          ";; C-c C-p: move around the word   C-/: undo acceptance\n"
          ";; Nothing here is evaluated. Close this disposable buffer when done.\n"
          (make-string 30 ?\n))
  (goto-char (point-min))
  (forward-line (max 5 (/ (window-body-height) 2)))
  (insert (make-string (max 0 (- (/ (window-body-width) 2) 4)) ?\s) "(map")
  (save-excursion (insert ")"))
  (setq buffer-undo-list nil)
  (set-buffer-modified-p nil)
  (emacs-tui-completion-mode 1)
  (completion-at-point))

(provide 'emacs-tui-completion-demo)
;;; emacs-tui-completion-demo.el ends here
