;;; emacs-tui-resize-test.el --- Reflow regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise real window geometry changes.  Batch tests explicitly deliver the
;; redisplay state-change hook; interactive PTY tests cover automatic delivery.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-resize-test--workspace (&rest body)
  "Evaluate BODY in a workspace with an isolated source buffer."
  (declare (indent 0) (debug (body)))
  `(save-window-excursion
     (delete-other-windows)
     (let ((source (generate-new-buffer " *tui-resize-source*")) session)
       (unwind-protect
           (progn
             (switch-to-buffer source)
             (insert "origin")
             (setq session
                   (emacs-tui-open
                    :backend 'windows
                    :views (list (emacs-tui-view :id 'a :items '("alpha" "beta"))
                                 (emacs-tui-view :id 'b :items '("a1" "a2")))))
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p source) (kill-buffer source))))))

(ert-deftest emacs-tui-resize-preserves-query-focus-and-selection ()
  (emacs-tui-resize-test--workspace
    (insert "a")
    (goto-char (point-min))
    (emacs-tui-next-view session)
    (emacs-tui-next-item session)
    (let* ((query (current-buffer))
           (root (selected-window))
           (bounds (window-edges (emacs-tui--subtree session)))
           (old-height (- (nth 3 bounds) (nth 1 bounds))))
      (window-resize (emacs-tui--subtree session) 2)
      (run-hooks 'window-state-change-hook)
      (should (emacs-tui--workspace-active session))
      (should (eq query (current-buffer)))
      (should (eq root (selected-window)))
      (should (= 1 (point)))
      (should (equal "a" (emacs-tui-query session)))
      (should (equal "a2" (emacs-tui-current-item session)))
      (let ((new (window-edges (emacs-tui--subtree session))))
        (should (= (+ old-height 2) (- (nth 3 new) (nth 1 new))))))
    (with-current-buffer source (should (equal "origin" (buffer-string))))))

(ert-deftest emacs-tui-resize-hook-does-not-repeat-unchanged-layout ()
  (emacs-tui-resize-test--workspace
    (let ((arrange (symbol-function 'emacs-tui--arrange)) (calls 0))
      (cl-letf (((symbol-function 'emacs-tui--arrange)
                 (lambda (workspace)
                   (cl-incf calls)
                   (funcall arrange workspace))))
        (dotimes (_ 4) (run-hooks 'window-state-change-hook))
        (should (= 0 calls))
        (window-resize (emacs-tui--subtree session) 1)
        (run-hooks 'window-state-change-hook)
        (should (= 1 calls))
        (dotimes (_ 4) (run-hooks 'window-state-change-hook))
        (should (= 1 calls))))))

(ert-deftest emacs-tui-resize-preserves-unrelated-selection-and-window ()
  (emacs-tui-resize-test--workspace
    (let* ((origin (emacs-tui--workspace-origin-window session))
           (foreign (split-window origin nil 'right)))
      (select-window foreign)
      (window-resize (emacs-tui--subtree session) 1)
      (run-hooks 'window-state-change-hook)
      (should (emacs-tui--workspace-active session))
      (should (eq foreign (selected-window)))
      (should (eq source (window-buffer foreign))))))

(ert-deftest emacs-tui-resize-closes-around-foreign-window-inside-surface ()
  (emacs-tui-resize-test--workspace
    (let* ((query (emacs-tui--workspace-root session))
           (foreign (split-window query nil 'right)))
      (set-window-buffer foreign source)
      (select-window foreign)
      (run-hooks 'window-state-change-hook)
      (should-not (emacs-tui--workspace-active session))
      (should (window-live-p foreign))
      (should (eq foreign (selected-window)))
      (should (eq source (window-buffer foreign))))))

(ert-deftest emacs-tui-resize-preserves-repurposed-owned-window ()
  (emacs-tui-resize-test--workspace
    (let ((window (emacs-tui--view-window (emacs-tui--focused-view session))))
      (set-window-buffer window source)
      (select-window window)
      (run-hooks 'window-state-change-hook)
      (should-not (emacs-tui--workspace-active session))
      (should (window-live-p window))
      (should (eq window (selected-window)))
      (should-not (window-parameter window 'emacs-tui-session)))))

(ert-deftest emacs-tui-resize-deleted-query-window-closes-cleanly ()
  (emacs-tui-resize-test--workspace
    (delete-window (emacs-tui--workspace-root session))
    (run-hooks 'window-state-change-hook)
    (should-not (emacs-tui--workspace-active session))
    (should (= 1 (length (window-list))))))

(ert-deftest emacs-tui-resize-deleted-origin-window-closes-cleanly ()
  (emacs-tui-resize-test--workspace
    (delete-window (emacs-tui--workspace-origin-window session))
    (run-hooks 'window-state-change-hook)
    (should-not (emacs-tui--workspace-active session))
    (should (= 1 (length (window-list))))
    (should (eq source (window-buffer)))))

(ert-deftest emacs-tui-resize-layout-error-cleans-owned-resources ()
  (emacs-tui-resize-test--workspace
    (let ((arrange (symbol-function 'emacs-tui--arrange)))
      (cl-letf (((symbol-function 'emacs-tui--arrange)
                 (lambda (workspace)
                   (funcall arrange workspace)
                   (error "Injected resize failure"))))
        (should-not (emacs-tui-refresh session))))
    (should-not (emacs-tui--workspace-active session))
    (should (= 1 (length (window-list))))
    (should-not (memq #'emacs-tui--window-state-changed window-state-change-hook))))

(ert-deftest emacs-tui-resize-nonlocal-exit-cleans-owned-resources ()
  (emacs-tui-resize-test--workspace
    (cl-letf (((symbol-function 'emacs-tui--arrange)
               (lambda (_) (throw 'cancel 'cancelled))))
      (should (eq 'cancelled (catch 'cancel (emacs-tui-refresh session)))))
    (should-not (emacs-tui--workspace-active session))
    (should (= 1 (length (window-list))))))

(ert-deftest emacs-tui-resize-preserves-preview-scroll ()
  (emacs-tui-resize-test--workspace
    (emacs-tui-update session 'b :text (make-string 300 ?x))
    (let* ((view (cadr (emacs-tui--workspace-views session)))
           (window (emacs-tui--view-window view)))
      (set-window-point window 80)
      (set-window-hscroll window 12)
      (emacs-tui-refresh session)
      (should (= 80 (window-point (emacs-tui--view-window view))))
      (should (= 12 (window-hscroll (emacs-tui--view-window view)))))))

(provide 'emacs-tui-resize-test)
;;; emacs-tui-resize-test.el ends here
