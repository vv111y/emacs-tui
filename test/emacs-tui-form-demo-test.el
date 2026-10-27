;;; emacs-tui-form-demo-test.el --- Validated settings journeys -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Verify draft/applied separation, native editing and session isolation.

;;; Code:
(require 'ert)
(require 'emacs-tui-form-demo (expand-file-name "examples/emacs-tui-form-demo.el"))

(defmacro emacs-tui-form-test--with (&rest body)
  "Create APP and evaluate BODY, cleaning up even after assertion failure."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let ((before emacs-tui--sessions) app)
       (unwind-protect
           (progn (setq app (emacs-tui-form-demo)) ,@body)
         (dolist (session (copy-sequence emacs-tui--sessions))
           (unless (memq session before) (emacs-tui-close session)))))))

(defun emacs-tui-form-test--status (app)
  "Read APP's visible status without changing its selected pane."
  (let ((id (emacs-tui-current-view app)))
    (unwind-protect
        (progn (emacs-tui-focus-view app 'status) (buffer-string))
      (emacs-tui-focus-view app id))))

(defun emacs-tui-form-test--edit (app id text)
  "Replace APP field ID using ordinary editing with TEXT."
  (emacs-tui-focus-view app id)
  (erase-buffer)
  (insert text))

(ert-deftest emacs-tui-form-invalid-draft-never-applies ()
  (emacs-tui-form-test--with
    (emacs-tui-form-test--edit app 'name "")
    (emacs-tui-form-test--edit app 'retries "11")
    (should (string-match-p "Name: enter" (emacs-tui-form-test--status app)))
    (should (string-match-p "Retries: enter" (emacs-tui-form-test--status app)))
    (should-error (emacs-tui-act app 'apply) :type 'user-error)
    (emacs-tui-act app 'revert)
    (should (equal "Local demo" (emacs-tui-input-value app 'name)))
    (should (equal "3" (emacs-tui-input-value app 'retries)))
    (should (string-match-p "no changes" (emacs-tui-form-test--status app)))
    (should (emacs-tui-live-p app))))

(ert-deftest emacs-tui-form-apply-and-revert-include-options ()
  (emacs-tui-form-test--with
    (emacs-tui-form-test--edit app 'name "日本語 settings")
    (emacs-tui-form-test--edit app 'retries "10")
    (emacs-tui-focus-view app 'options)
    (emacs-tui-form-demo--toggle)
    (should-not (plist-get (emacs-tui-current-item app) :checked))
    (should (string-match-p "Name: Local demo" (emacs-tui-form-test--status app)))
    (emacs-tui-act app 'apply)
    (should (string-match-p "Name: 日本語 settings" (emacs-tui-form-test--status app)))
    (should (string-match-p "Wrap text=off" (emacs-tui-form-test--status app)))
    (emacs-tui-form-test--edit app 'name "Unapplied")
    (emacs-tui-focus-view app 'options)
    (emacs-tui-act app 'toggle)
    (emacs-tui-act app 'revert)
    (should (equal "日本語 settings" (emacs-tui-input-value app 'name)))
    (should-not (plist-get (emacs-tui-current-item app) :checked))
    (should (string-match-p "no changes" (emacs-tui-form-test--status app)))))

(ert-deftest emacs-tui-form-typing-undo-and-apply-preserve-native-state ()
  (emacs-tui-form-test--with
    (emacs-tui-focus-view app 'name)
    (goto-char (point-max))
    (execute-kbd-macro (kbd "SPC n p q"))
    (undo-boundary)
    (let ((undo (copy-tree buffer-undo-list)) (position (point))
          (window (selected-window)))
      (emacs-tui-form-demo--apply)
      (should (equal undo buffer-undo-list))
      (should (= position (point)))
      (should (eq window (selected-window))))
    (undo-only 1)
    (should (string-match-p "unapplied changes" (emacs-tui-form-test--status app)))
    (emacs-tui-form-demo--revert)
    (should (equal "Local demo npq" (emacs-tui-input-value app 'name)))
    (emacs-tui-focus-view app 'name)
    (should-not buffer-undo-list)))

(ert-deftest emacs-tui-form-validation-boundaries ()
  (dolist (name '("" "  " "two\nlines"))
    (should (emacs-tui-form-demo--errors name "3")))
  (should (emacs-tui-form-demo--errors (make-string 61 ?a) "3"))
  (dolist (retries '("" "-1" "11" "1.0" "3\n" "99999999999999999999"))
    (should (emacs-tui-form-demo--errors "Valid" retries)))
  (should-not (emacs-tui-form-demo--errors (make-string 60 ?a) "0"))
  (should-not (emacs-tui-form-demo--errors "Valid" "10")))

(ert-deftest emacs-tui-form-sessions-do-not-share-settings ()
  (emacs-tui-form-test--with
    (emacs-tui-form-test--edit app 'name "First session")
    (emacs-tui-act app 'apply)
    (let ((other (emacs-tui-form-demo)))
      (should (equal "Local demo" (emacs-tui-input-value other 'name)))
      (emacs-tui-form-test--edit other 'name "Second draft")
      (emacs-tui-act other 'revert)
      (should (equal "Local demo" (emacs-tui-input-value other 'name)))
      (should (equal "First session" (emacs-tui-input-value app 'name))))))

(ert-deftest emacs-tui-form-failed-apply-retains-saved-record ()
  (emacs-tui-form-test--with
    (emacs-tui-form-test--edit app 'name "Uncommitted")
    (emacs-tui-focus-view app 'status)
    (let ((hook (lambda (&rest _) (error "Injected render failure"))))
      (add-hook 'before-change-functions hook nil t)
      (unwind-protect
          (should-error (emacs-tui-act app 'apply))
        (remove-hook 'before-change-functions hook t)))
    (emacs-tui-act app 'revert)
    (should (equal "Local demo" (emacs-tui-input-value app 'name)))
    (emacs-tui-form-test--edit app 'name "Recovered")
    (emacs-tui-act app 'apply)
    (should (string-match-p "Name: Recovered" (emacs-tui-form-test--status app)))))

(ert-deftest emacs-tui-form-no-op-revert-preserves-native-undo ()
  (emacs-tui-form-test--with
    (goto-char (point-max))
    (insert " changed")
    (undo-boundary)
    (emacs-tui-act app 'apply)
    (let ((undo (copy-tree buffer-undo-list)) (position (point)))
      (emacs-tui-act app 'revert)
      (should (equal undo buffer-undo-list))
      (should (= position (point))))))

(ert-deftest emacs-tui-form-stale-apply-rejects-native-hook-edit ()
  (emacs-tui-form-test--with
    (emacs-tui-form-test--edit app 'name "Candidate")
    (let ((input (current-buffer)) entered)
      (emacs-tui-focus-view app 'status)
      (let ((hook (lambda (&rest _)
                    (unless entered
                      (setq entered t)
                      (with-current-buffer input (insert "\ninvalid"))))))
        (add-hook 'before-change-functions hook nil t)
        (unwind-protect
            (should-error (emacs-tui-act app 'apply) :type 'user-error)
          (remove-hook 'before-change-functions hook t)))
      (should (string-match-p "Draft invalid" (emacs-tui-form-test--status app)))
      (should (string-match-p "Name: Local demo" (emacs-tui-form-test--status app)))
      (emacs-tui-set-layout app 'rows)
      (should (equal "Candidate\ninvalid" (emacs-tui-input-value app 'name)))
      (emacs-tui-act app 'revert)
      (should (equal "Local demo" (emacs-tui-input-value app 'name))))))

(provide 'emacs-tui-form-demo-test)
;;; emacs-tui-form-demo-test.el ends here
