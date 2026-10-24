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

(ert-deftest emacs-tui-tty-focus-public-focus-records-selection-before-next-command ()
  (emacs-tui-tty-focus-test--with
    (let* ((view (emacs-tui--make-view :id 'first :window 'wa))
           (nested (emacs-tui--make-workspace :active t :frame 'an :origin-frame 'ac)))
      (setf (emacs-tui--workspace-views a) (list view))
      (push nested emacs-tui--sessions) (push nested owned)
      (setq selected 'an)
      (emacs-tui--remember-tty-focus)
      (should (emacs-tui--workspace-tty-focus nested))
      (cl-letf (((symbol-function 'window-live-p) (lambda (window) (eq window 'wa)))
                ((symbol-function 'select-window) (lambda (_) (setq selected 'ac)))
                ((symbol-function 'emacs-tui--render-view) #'ignore))
        (should (eq a (emacs-tui-focus-view a 'first))))
      (should (emacs-tui--workspace-tty-focus a))
      (should-not (emacs-tui--workspace-tty-focus nested))
      (setq selected 'bc)
      (emacs-tui--remember-tty-focus)
      (should (equal '((switch-frame ac)) (emacs-tui--tty-switch-frame '((switch-frame ar))))))))

(ert-deftest emacs-tui-tty-focus-client-deletion-restores-only-implicit-survivor-selection ()
  (emacs-tui-tty-focus-test--with
    (let ((emacs-tui--tty-deleting-frames nil) (selections 0))
      (cl-letf (((symbol-function 'frame-selected-window) (lambda (frame) frame))
                ((symbol-function 'select-window)
                 (lambda (window) (cl-incf selections) (setq selected window))))
        (emacs-tui--tty-frame-deleting 'br)
        ;; A repeated pre-deletion notification must retain the original frame.
        (setq selected 'ar)
        (emacs-tui--tty-frame-deleting 'br)
        (emacs-tui--tty-frame-deleted 'br)
        (should (eq 'ac selected))
        (should (= 1 selections))
        (should-not emacs-tui--tty-deleting-frames)
        ;; Closing a background frame leaves native focus unchanged.
        (setq selected 'ar)
        (emacs-tui--tty-frame-deleting 'br)
        (emacs-tui--tty-frame-deleted 'br)
        (should (eq 'ar selected))
        (should (= 1 selections))
        ;; An application's focus change during a background deletion is explicit.
        (setq selected 'ac)
        (emacs-tui--tty-frame-deleting 'br)
        (setq selected 'ar)
        (emacs-tui--tty-frame-deleted 'br)
        (should (eq 'ar selected))
        (should (= 1 selections))
        ;; An explicitly focused parent must remain selected after deletion.
        (setf (emacs-tui--workspace-tty-focus a) nil)
        (setq selected 'bc)
        (emacs-tui--tty-frame-deleting 'br)
        (setq selected 'ar)
        (emacs-tui--tty-frame-deleted 'br)
        (should (eq 'ar selected))
        (should (= 1 selections))
        ;; Nor may a foreign subtree be recaptured by the fallback selection.
        (setf (emacs-tui--workspace-tty-focus a) t)
        (setq selected 'bc owned (list b))
        (emacs-tui--tty-frame-deleting 'br)
        (setq selected 'ar)
        (emacs-tui--tty-frame-deleted 'br)
        (should (eq 'ar selected))
        (should (= 1 selections))))))

(ert-deftest emacs-tui-tty-focus-close-callback-parent-choice-is-remembered ()
  (emacs-tui-tty-focus-test--with
    (let ((post-command-hook nil) (delete-frame-functions nil)
          (after-delete-frame-functions nil) (delete-terminal-functions nil)
          (emacs-tui--tty-deleting-frames nil)
          (closing (emacs-tui--make-workspace
                    :active t :on-close (lambda (_) (setq selected 'ar)))))
      (unwind-protect
          (progn
            (push closing emacs-tui--sessions)
            (emacs-tui-close closing)
            (should (eq 'ar selected))
            (should-not (emacs-tui--workspace-tty-focus a))
            (should (emacs-tui--workspace-tty-focus b))
            ;; An unchanged callback must not classify an implicit fallback as intent.
            (setf (emacs-tui--workspace-tty-focus a) t)
            (let ((noop (emacs-tui--make-workspace :active t :on-close #'ignore)))
              (push noop emacs-tui--sessions)
              (emacs-tui-close noop))
            (should (eq 'ar selected))
            (should (emacs-tui--workspace-tty-focus a)))
        (advice-remove #'handle-switch-frame #'emacs-tui--tty-switch-frame)))))

(ert-deftest emacs-tui-tty-focus-server-terminal-capture-survives-deferred-frame-hooks ()
  (emacs-tui-tty-focus-test--with
    (let ((emacs-tui--tty-deleting-frames nil) (selections 0))
      (cl-letf (((symbol-function 'frame-list) (lambda () (copy-sequence frames)))
                ((symbol-function 'frame-selected-window) (lambda (frame) frame))
                ((symbol-function 'select-window)
                 (lambda (window) (cl-incf selections) (setq selected window))))
        (emacs-tui--tty-terminal-deleting 'B)
        (should (nth 2 (assq 'br emacs-tui--tty-deleting-frames)))
        (setq frames (cl-set-difference frames '(br bc)) selected 'ar)
        ;; Post-command may arrive before either deferred frame hook.
        (emacs-tui--remember-tty-focus)
        (should (eq 'ac selected))
        (should (= 1 selections))
        (should-not emacs-tui--tty-deleting-frames)
        ;; A deferred after hook can precede a deferred before hook.
        (emacs-tui--tty-frame-deleted 'br)
        (emacs-tui--tty-frame-deleting 'br)
        (should-not emacs-tui--tty-deleting-frames)
        ;; The completed deletion must not recapture a later parent choice.
        (setq selected 'ar)
        (emacs-tui--remember-tty-focus)
        (should (eq 'ar selected))
        (should-not (emacs-tui--workspace-tty-focus a))))))

(ert-deftest emacs-tui-tty-focus-terminal-deletion-after-hook-first-and-background-focus ()
  (emacs-tui-tty-focus-test--with
    (let ((emacs-tui--tty-deleting-frames nil) (selections 0))
      (cl-letf (((symbol-function 'frame-list) (lambda () (copy-sequence frames)))
                ((symbol-function 'frame-selected-window) (lambda (frame) frame))
                ((symbol-function 'select-window)
                 (lambda (window) (cl-incf selections) (setq selected window))))
        (emacs-tui--tty-terminal-deleting 'B)
        (setq frames (cl-set-difference frames '(br bc)) selected 'ar)
        (emacs-tui--tty-frame-deleted 'br)
        (should (eq 'ac selected))
        (should (= 1 selections))
        (should-not emacs-tui--tty-deleting-frames)
        ;; A late application terminal hook's focus change is explicit.
        (setq frames (append frames '(br bc)) selected 'ar)
        (setf (emacs-tui--workspace-tty-focus a) nil)
        (emacs-tui--tty-terminal-deleting 'B)
        (setq frames (cl-set-difference frames '(br bc)))
        (emacs-tui--remember-tty-focus)
        (should (eq 'ar selected))
        (should (= 1 selections))
        (should-not emacs-tui--tty-deleting-frames)))))

(ert-deftest emacs-tui-tty-focus-hook-lifetime-preserves-other-advice-and-window-sessions ()
  (emacs-tui-tty-focus-test--with
    (let ((post-command-hook (list #'ignore))
          (delete-frame-functions (list #'ignore))
          (after-delete-frame-functions (list #'ignore))
          (delete-terminal-functions (list #'ignore))
          (emacs-tui--tty-deleting-frames nil)
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
            (should (equal '(ignore) post-command-hook))
            (should (equal '(ignore) delete-frame-functions))
            (should (equal '(ignore) after-delete-frame-functions))
            (should (equal '(ignore) delete-terminal-functions))
            ;; Emacs may still call a late hook from an earlier hook-list snapshot.
            (emacs-tui--tty-frame-deleting 'br)
            (should-not emacs-tui--tty-deleting-frames))
        (advice-remove #'handle-switch-frame #'emacs-tui--tty-switch-frame)
        (advice-remove #'handle-switch-frame other-advice)))))

;;; emacs-tui-tty-focus-test.el ends here
