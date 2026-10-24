;;; emacs-tui-tty-focus-test.el --- Terminal input routing boundaries -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Model distinct terminals for event routing; tty-clients-smoke.el supplies
;; actual native child-frame input on Emacs 31.1 Linux and macOS.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-tty-focus-test--with (&rest body)
  "Run BODY with two terminal trees and live owned sessions a and b."
  (declare (indent 0) (debug t))
  `(let* ((a (emacs-tui--make-workspace :active t :frame 'ac :origin-frame 'ar :tty-focus t))
          (b (emacs-tui--make-workspace :active t :frame 'bc :origin-frame 'br :tty-focus t))
          (emacs-tui--sessions (list b a))
          (selected 'bc) (owned (list a b))
          (frames (copy-sequence '(ar ac an br bc other gui)))
          (parents (copy-tree '((ac . ar) (an . ac) (bc . br))))
          (terminals (copy-tree '((ar . A) (ac . A) (an . A) (other . A) (br . B) (bc . B) (gui . G)))))
     (cl-letf (((symbol-function 'selected-frame) (lambda () selected))
               ((symbol-function 'frame-live-p) (lambda (frame) (memq frame frames)))
               ((symbol-function 'frame-parent) (lambda (frame) (cdr (assq frame parents))))
               ((symbol-function 'frame-terminal) (lambda (frame) (cdr (assq frame terminals))))
               ((symbol-function 'display-graphic-p) (lambda (frame) (eq frame 'gui)))
               ((symbol-function 'emacs-tui--subtree) (lambda (app) (memq app owned))))
       ,@body)))

(ert-deftest emacs-tui-tty-focus-returning-terminal-restores-child-without-mutating-event ()
  (emacs-tui-tty-focus-test--with
    (let* ((event (list 'switch-frame 'ar))
           (arguments (list event))
           (current-prefix-arg '(4)) (prefix-arg '(16)))
      (should (equal '((switch-frame ac)) (emacs-tui--tty-switch-frame arguments)))
      (should (equal '(switch-frame ar) event))
      (should (eq 'bc selected))
      (should (equal '(4) current-prefix-arg))
      (should (equal '(16) prefix-arg))
      (setq selected 'ac)
      (progn
        (should (equal '((switch-frame bc))
                       (emacs-tui--tty-switch-frame '((switch-frame br)))))))))

(ert-deftest emacs-tui-tty-focus-explicit-parent-selection-and-background-memory ()
  (emacs-tui-tty-focus-test--with
    (emacs-tui--remember-tty-focus)
    (should (emacs-tui--workspace-tty-focus a))
    (should (emacs-tui--workspace-tty-focus b))
    (setq selected 'ar)
    (let ((event '((switch-frame ac))))
      (should (eq event (emacs-tui--tty-switch-frame event))))
    (emacs-tui--remember-tty-focus)
    (should-not (emacs-tui--workspace-tty-focus a))
    (should (emacs-tui--workspace-tty-focus b))
    (setq selected 'bc)
    (let ((event '((switch-frame ar))))
      (should (eq event (emacs-tui--tty-switch-frame event))))))

(ert-deftest emacs-tui-tty-focus-foreign-dead-graphic-and-unrelated-events-retain-routing ()
  (emacs-tui-tty-focus-test--with
    (dolist (event '((focus-in ar) (switch-frame other) (switch-frame gui) (switch-frame dead)))
      (let ((arguments (list event)))
        (should (eq arguments (emacs-tui--tty-switch-frame arguments)))))
    (setq owned (list b))
    (let ((event '((switch-frame ar))))
      (should (eq event (emacs-tui--tty-switch-frame event))))
    (setq owned (list a b) frames (delq 'ac frames))
    (let ((event '((switch-frame ar))))
      (should (eq event (emacs-tui--tty-switch-frame event))))))

(ert-deftest emacs-tui-tty-focus-rejects-cross-terminal-child-even-with-bad-ancestry ()
  (emacs-tui-tty-focus-test--with
    (setf (alist-get 'ac terminals) 'B)
    (let ((event '((switch-frame ar))))
      (should (eq event (emacs-tui--tty-switch-frame event))))))

(ert-deftest emacs-tui-tty-focus-nested-child-and-background-close-restore-owned-ancestor ()
  (emacs-tui-tty-focus-test--with
    (let ((nested (emacs-tui--make-workspace :active t :frame 'an :origin-frame 'ac)))
      (push nested emacs-tui--sessions) (push nested owned)
      (setq selected 'an)
      (emacs-tui--remember-tty-focus)
      (should (emacs-tui--workspace-tty-focus nested))
      (should-not (emacs-tui--workspace-tty-focus a))
      (setq selected 'bc)
      (should (equal '((switch-frame an)) (emacs-tui--tty-switch-frame '((switch-frame ar)))))
      (setq emacs-tui--sessions (delq nested emacs-tui--sessions))
      (emacs-tui--restore-tty-focus nested)
      (should (emacs-tui--workspace-tty-focus a))
      (should (eq 'bc selected))
      (should (equal '((switch-frame ac)) (emacs-tui--tty-switch-frame '((switch-frame ar)))))
      (setf (emacs-tui--workspace-tty-focus a) nil
            (emacs-tui--workspace-tty-focus nested) nil)
      (emacs-tui--restore-tty-focus nested)
      (should-not (emacs-tui--workspace-tty-focus a)))))

(ert-deftest emacs-tui-tty-focus-ancestor-restoration-rejects-repurposed-surface ()
  (emacs-tui-tty-focus-test--with
    (let ((nested (emacs-tui--make-workspace :frame 'an :origin-frame 'ac :tty-focus t)))
      (setf (emacs-tui--workspace-tty-focus a) nil)
      (setq owned (list b))
      (emacs-tui--restore-tty-focus nested)
      (should-not (emacs-tui--workspace-tty-focus a)))))

(ert-deftest emacs-tui-tty-focus-hook-lifetime-preserves-other-advice-and-window-sessions ()
  (emacs-tui-tty-focus-test--with
    (let ((post-command-hook (list #'ignore))
          (other-advice (lambda (&rest _) nil)))
      (unwind-protect
          (progn
            (advice-add #'handle-switch-frame :before other-advice)
            (emacs-tui--sync-tty-focus-hooks)
            (emacs-tui--sync-tty-focus-hooks)
            (should (= 1 (cl-count #'emacs-tui--remember-tty-focus post-command-hook)))
            (should (advice-member-p #'emacs-tui--tty-switch-frame #'handle-switch-frame))
            (setf (emacs-tui--workspace-frame a) nil)
            (emacs-tui--sync-tty-focus-hooks)
            (should (advice-member-p #'emacs-tui--tty-switch-frame #'handle-switch-frame))
            (setf (emacs-tui--workspace-frame b) nil)
            (emacs-tui--sync-tty-focus-hooks)
            (should-not (advice-member-p #'emacs-tui--tty-switch-frame #'handle-switch-frame))
            (should (advice-member-p other-advice #'handle-switch-frame))
            (should (equal '(ignore) post-command-hook)))
        (advice-remove #'handle-switch-frame #'emacs-tui--tty-switch-frame)
        (advice-remove #'handle-switch-frame other-advice)))))

;;; emacs-tui-tty-focus-test.el ends here
