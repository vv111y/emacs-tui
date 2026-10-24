;;; emacs-tui-maximize-test.el --- View maximization behavior -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Preserve native edit/reading state while views move through one panel.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-maximize-test--with (&rest body)
  "Mount three views as session, run BODY and release owned resources."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let ((text (mapconcat (lambda (n) (format "Line %s: long preview content" n))
                            (number-sequence 1 200) "\n")) session)
       (unwind-protect
           (progn
             (setq session (emacs-tui-mount
                            :views (list (emacs-tui-input :id 'input :value text)
                                         (emacs-tui-view :id 'preview :text text)
                                         (emacs-tui-view :id 'list :items '("a" "b") :multi-select t))))
             ,@body)
         (when session (emacs-tui-close session))))))

(defun emacs-tui-maximize-test--visible (session)
  "Return the visible view identities in SESSION."
  (mapcar #'emacs-tui--view-id
          (cl-remove-if-not (lambda (view) (window-live-p (emacs-tui--view-window view)))
                            (emacs-tui--workspace-views session))))

(ert-deftest emacs-tui-maximize-all-views-remain-accessible-and-layout-restores ()
  (emacs-tui-maximize-test--with
    (let ((buffers (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session))))
      (should (equal '(input preview list) (emacs-tui-maximize-test--visible session)))
      (execute-kbd-macro (kbd "C-c C-f"))
      (should (equal '(input) (emacs-tui-maximize-test--visible session)))
      (execute-kbd-macro (kbd "TAB"))
      (should (equal '(preview) (emacs-tui-maximize-test--visible session)))
      (should (string-match-p "maximized" header-line-format))
      (execute-kbd-macro (kbd "TAB n C-c C-m"))
      (should (equal '(list) (emacs-tui-maximize-test--visible session)))
      (should (equal '("b") (emacs-tui-marked-items session)))
      (execute-kbd-macro (kbd "C-c C-l C-c C-f"))
      (should (eq 'rows (emacs-tui--workspace-layout session)))
      (should (equal '(input preview list) (emacs-tui-maximize-test--visible session)))
      (should (equal "b" (emacs-tui-current-item session)))
      (should (equal buffers (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session)))))))

(ert-deftest emacs-tui-maximize-preserves-input-undo-and-reading-state ()
  (emacs-tui-maximize-test--with
    (forward-line 60)
    (insert "X")
    (undo-boundary)
    (set-window-hscroll (selected-window) 3)
    (let ((input-position (point)) (input-undo (copy-tree buffer-undo-list)))
      (emacs-tui-toggle-maximize session)
      (emacs-tui-next-view session)
      (forward-line 80)
      (set-window-hscroll (selected-window) 5)
      (set-window-start (selected-window) (save-excursion (forward-line -5) (point)) t)
      (let ((preview-position (point)) (preview-start (window-start)))
        (emacs-tui-next-view session)
        (emacs-tui-previous-view session)
        (should (= preview-position (point)))
        (should (= preview-start (window-start)))
        (should (= 5 (window-hscroll)))
        (emacs-tui-previous-view session)
        (should (= input-position (point)))
        (should (= 3 (window-hscroll)))
        (should (equal input-undo buffer-undo-list))
        (emacs-tui-toggle-maximize session)
        (let ((preview-window (emacs-tui--view-window
                               (cadr (emacs-tui--workspace-views session)))))
          (should (= preview-position (window-point preview-window)))
          (should (= 5 (window-hscroll preview-window))))
        (undo-only 1)
        (should (equal text (emacs-tui-input-value session 'input)))))))

(ert-deftest emacs-tui-maximize-hidden-preview-update-resets-old-position ()
  (emacs-tui-maximize-test--with
    (emacs-tui-next-view session)
    (forward-line 70)
    (emacs-tui-toggle-maximize session)
    (emacs-tui-next-view session)
    (emacs-tui-update session 'preview :text "New object")
    (emacs-tui-previous-view session)
    (should (= 1 (point)))
    (should (equal "New object" (buffer-string)))))

(ert-deftest emacs-tui-maximize-ephemeral-query-remains-native ()
  (save-window-excursion
    (let (session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-open :backend 'windows
                                         :views (list (emacs-tui-view :id 'a :items '("alpha"))
                                                      (emacs-tui-view :id 'b :items '("alphabet")))))
            (insert "alph")
            (let ((query (current-buffer)) (position (point)))
              (execute-kbd-macro (kbd "C-c C-f TAB"))
              (should (eq query (current-buffer)))
              (should (= position (point)))
              (should (equal '(b) (emacs-tui-maximize-test--visible session)))
              (insert "a")
              (should (equal "alpha" (emacs-tui-query session)))
              (execute-kbd-macro (kbd "C-c C-f"))
              (should (equal '(a b) (emacs-tui-maximize-test--visible session)))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-maximize-does-not-run-application-callbacks ()
  (let ((calls 0) session)
    (save-window-excursion
      (unwind-protect
          (progn
            (setq session (emacs-tui-mount
                           :views (list (emacs-tui-input :id 'a :on-change (lambda (&rest _) (cl-incf calls)))
                                        (emacs-tui-view :id 'b :items '("x")
                                                        :on-select (lambda (&rest _) (cl-incf calls))))))
            (emacs-tui-toggle-maximize session)
            (emacs-tui-next-view session)
            (emacs-tui-toggle-maximize session)
            (should (= 0 calls)))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-maximize-single-embedded-view-is-unchanged ()
  (save-window-excursion
    (let ((host (window-buffer)) session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a :text "Panel")))
            (let ((window (selected-window)))
              (should (eq session (emacs-tui-toggle-maximize session)))
              (should (eq window (selected-window)))
              (should-not (emacs-tui--workspace-maximized session)))
            (emacs-tui-close session)
            (should (eq host (window-buffer))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-maximize-close-preserves-launcher-and-releases-buffers ()
  (emacs-tui-maximize-test--with
    (let ((buffers (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session))))
      (emacs-tui-toggle-maximize session)
      (emacs-tui-close session)
      (should-not (emacs-tui-live-p session))
      (should-not (cl-some #'buffer-live-p buffers))
      (should-not (memq session emacs-tui--sessions)))))

(ert-deftest emacs-tui-maximize-preserves-narrowed-input ()
  (emacs-tui-maximize-test--with
    (narrow-to-region 40 200)
    (goto-char 120)
    (emacs-tui-toggle-maximize session)
    (emacs-tui-next-view session)
    (emacs-tui-toggle-maximize session)
    (emacs-tui-previous-view session)
    (should (= 40 (point-min)))
    (should (= 200 (point-max)))
    (should (= 120 (point)))))

(ert-deftest emacs-tui-maximize-keeps-unrelated-window-contents-and-geometry ()
  (emacs-tui-maximize-test--with
    (let* ((outside (emacs-tui--workspace-origin-window session))
           (buffer (window-buffer outside)) (edges (window-edges outside)))
      (emacs-tui-toggle-maximize session)
      (emacs-tui-next-view session)
      (emacs-tui-toggle-maximize session)
      (should (eq buffer (window-buffer outside)))
      (should (equal edges (window-edges outside))))))

(provide 'emacs-tui-maximize-test)
;;; emacs-tui-maximize-test.el ends here
