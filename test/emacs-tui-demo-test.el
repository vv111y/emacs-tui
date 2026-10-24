;;; emacs-tui-demo-test.el --- Exercise the graph application -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Test the example through its public commands and explicit commit boundary.

;;; Code:
(require 'ert)
(require 'emacs-tui-demo (expand-file-name "examples/emacs-tui-demo.el"))

(defmacro emacs-tui-demo-test--workspace (&rest body)
  "Open the graph demo, evaluate BODY, then release its resources."
  (declare (indent 0) (debug body))
  `(save-window-excursion
     (delete-other-windows)
     (let ((source (generate-new-buffer " *tui-demo-test*")) session)
       (unwind-protect
           (progn
             (switch-to-buffer source)
             (insert "Origin:")
             (setq session (emacs-tui-demo))
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p source) (kill-buffer source))))))

(ert-deftest emacs-tui-demo-batch-commit-is-explicit-and-source-ordered ()
  (emacs-tui-demo-test--workspace
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-previous-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-select session)
    (should (equal (with-current-buffer source (buffer-string)) "Origin:"))
    (emacs-tui-commit session)
    (should (equal (with-current-buffer source (buffer-string))
                   "Origin:[[demo:emacs][Emacs]]\n[[demo:org][Org]]"))))

(ert-deftest emacs-tui-demo-node-query-does-not-hide-forward-links ()
  (emacs-tui-demo-test--workspace
    (insert "Emacs")
    (emacs-tui-select session)
    (emacs-tui-next-view session)
    (emacs-tui-next-view session)
    (should (equal (plist-get (emacs-tui-current-item session) :id) "org"))
    (emacs-tui-next-item session)
    (should (equal (plist-get (emacs-tui-current-item session) :id) "lisp"))
    (should (equal (with-current-buffer source (buffer-string)) "Origin:"))))

(ert-deftest emacs-tui-demo-bulk-marks-commit-filtered-graph-results-explicitly ()
  (emacs-tui-demo-test--workspace
    (execute-kbd-macro (kbd "E m a c s C-c *"))
    (should (equal "Emacs" (emacs-tui-query session)))
    (should (equal '("emacs" "lisp")
                   (mapcar (lambda (item) (plist-get item :id))
                           (emacs-tui-marked-items session 'nodes))))
    (should (equal "RET to inspect a node"
                   (emacs-tui--view-text (emacs-tui--resolve-view session 'preview))))
    (execute-kbd-macro (kbd "C-c C-t"))
    (should-not (emacs-tui-marked-items session 'nodes))
    (execute-kbd-macro (kbd "C-c * RET"))
    (should (equal "Origin:" (with-current-buffer source (buffer-string))))
    (emacs-tui-commit session)
    (should (equal "Origin:[[demo:emacs][Emacs]]\n[[demo:lisp][Emacs Lisp]]"
                   (with-current-buffer source (buffer-string))))))

(provide 'emacs-tui-demo-test)
;;; emacs-tui-demo-test.el ends here
