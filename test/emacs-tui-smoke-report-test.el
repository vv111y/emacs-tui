;;; emacs-tui-smoke-report-test.el --- Noninteractive diagnostics -*- lexical-binding: t; -*-
;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later
(require 'ert)
(require 'cl-lib)
(let ((emacs-startup-hook nil))
  (load (expand-file-name "test/tty-showcase-smoke.el") nil t))

(ert-deftest emacs-tui-showcase-failure-writes-unicode-without-prompting ()
  (let ((path (make-temp-file "tui-failure-"))
        (process-environment (copy-sequence process-environment))
        (existing-warnings (get-buffer "*Warnings*"))
        (warnings (get-buffer-create "*Warnings*"))
        (message-log-max nil)
        (inhibit-read-only t)
        (coding-system-for-write 'us-ascii)
        warning-start status)
    (unwind-protect
        (progn
          (with-current-buffer warnings
            (goto-char (point-max))
            (setq warning-start (point))
            (insert "Warning: café → λ\n"))
          (setenv "EMACS_TUI_SMOKE_REPORT" path)
          (cl-letf (((symbol-function 'kill-emacs) (lambda (code) (setq status code)))
                    ((symbol-function 'read-coding-system)
                     (lambda (&rest _) (error "Unexpected encoding prompt"))))
            (emacs-tui-showcase--fail '(error "Failure: 界")))
          (should (equal status 1))
          (with-temp-buffer
            (let ((coding-system-for-read 'utf-8-unix)) (insert-file-contents path))
            (should (string-match-p "FAIL showcase phase .*Failure: 界" (buffer-string)))
            (should (string-match-p "Warning: café → λ" (buffer-string)))))
      (delete-file path)
      (if existing-warnings
          (with-current-buffer warnings
            (when warning-start
              (delete-region warning-start
                             (+ warning-start (length "Warning: café → λ\n")))))
        (kill-buffer warnings)))))
(provide 'emacs-tui-smoke-report-test)
;;; emacs-tui-smoke-report-test.el ends here
