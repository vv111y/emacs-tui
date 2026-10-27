;;; emacs-tui-popup-focus-test.el --- Graphical popup focus events -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Model frame events on every supported Emacs; gui-smoke.el verifies native X.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-popup-focus-test--with (&rest body)
  "Evaluate BODY with modeled graphical, terminal and foreign frames."
  (declare (indent 0) (debug t))
  `(let* ((app (emacs-tui--make-workspace
               :active t :frame 'popup :origin-frame 'parent :origin-window 'source
               :popup (emacs-tui--make-popup)))
          (emacs-tui--sessions (list app))
          (selected 'source) (owned t) (graphical t))
     (cl-letf (((symbol-function 'frame-live-p)
                (lambda (frame) (memq frame '(popup parent foreign))))
               ((symbol-function 'display-graphic-p) (lambda (&optional _) graphical))
               ((symbol-function 'selected-window) (lambda () selected))
               ((symbol-function 'emacs-tui--subtree) (lambda (_) owned)))
       ,@body)))

(ert-deftest emacs-tui-popup-focus-routes-owned-graphical-event-without-mutation ()
  (emacs-tui-popup-focus-test--with
    (let* ((event (list 'switch-frame 'popup))
           (arguments (list event 'norecord))
           (current-prefix-arg '(4)) (prefix-arg '(16)))
      (should (equal '((switch-frame parent) norecord)
                     (emacs-tui--popup-switch-frame arguments)))
      (should (equal '(switch-frame popup) event))
      (should (equal '((switch-frame popup) norecord) arguments))
      (should (eq selected 'source))
      (should (equal current-prefix-arg '(4)))
      (should (equal prefix-arg '(16))))))

(ert-deftest emacs-tui-popup-focus-leaves-unrelated-and-obsolete-events-alone ()
  (emacs-tui-popup-focus-test--with
    (dolist (event '(nil switch-frame (switch-frame) (switch-frame . popup)
                    (switch-frame popup extra) (focus-in popup)
                    (switch-frame foreign) (switch-frame dead)))
      (let ((arguments (list event)))
        (should (eq arguments (emacs-tui--popup-switch-frame arguments)))))
    (let ((arguments '((switch-frame popup))))
      (setq graphical nil)
      (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
      (setq graphical t owned nil)
      (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
      (setq owned t selected 'other-window)
      (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
      (setq selected 'source)
      (setf (emacs-tui--workspace-active app) nil)
      (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
      (setf (emacs-tui--workspace-active app) t
            (emacs-tui--workspace-popup app) nil)
      (should (eq arguments (emacs-tui--popup-switch-frame arguments))))))

(ert-deftest emacs-tui-popup-focus-hook-remains-until-last-graphical-popup ()
  (emacs-tui-popup-focus-test--with
    (let ((second (copy-emacs-tui--workspace app))
          (foreign-advice (lambda (arguments) arguments)))
      (unwind-protect
          (progn
            (advice-add 'handle-switch-frame :filter-args foreign-advice)
            (push second emacs-tui--sessions)
            (emacs-tui--sync-popup-focus-hook)
            (should (advice-member-p #'emacs-tui--popup-switch-frame #'handle-switch-frame))
            (setq emacs-tui--sessions (list second))
            (emacs-tui--sync-popup-focus-hook)
            (should (advice-member-p #'emacs-tui--popup-switch-frame #'handle-switch-frame))
            (setq emacs-tui--sessions nil)
            (emacs-tui--sync-popup-focus-hook)
            (should-not (advice-member-p #'emacs-tui--popup-switch-frame #'handle-switch-frame))
            (should (advice-member-p foreign-advice #'handle-switch-frame)))
        (advice-remove 'handle-switch-frame #'emacs-tui--popup-switch-frame)
        (advice-remove 'handle-switch-frame foreign-advice)))))

(ert-deftest emacs-tui-popup-focus-revalidates-real-source-and-view-ownership ()
  (save-window-excursion
    (let ((source (generate-new-buffer " *focus source*"))
          (view-buffer (generate-new-buffer " *focus view*")))
      (unwind-protect
          (progn
            (delete-other-windows)
            (switch-to-buffer source)
            (insert "pump")
            (let* ((origin (selected-window))
                   (root (split-window-below))
                   (parent (selected-frame))
                   (live (symbol-function 'frame-live-p))
                   (frame-parent-function (symbol-function 'frame-parent))
                   (terminal (symbol-function 'frame-terminal))
                   (app (emacs-tui--make-workspace
                         :active t :frame 'modeled-popup :origin-frame parent
                         :origin-window origin :root root :windows (list root)
                         :popup (emacs-tui--make-popup :buffer source
                                                      :begin (copy-marker 1)
                                                      :end (copy-marker 5)))))
              (set-window-buffer root view-buffer)
              (set-window-parameter root 'emacs-tui-session app)
              (with-current-buffer view-buffer (setq-local emacs-tui--session app))
              (let ((emacs-tui--sessions (list app))
                    (arguments '((switch-frame modeled-popup) norecord)))
                (cl-letf (((symbol-function 'frame-live-p)
                           (lambda (frame) (if (eq frame 'modeled-popup) t (funcall live frame))))
                          ((symbol-function 'display-graphic-p)
                           (lambda (&optional frame) (eq frame 'modeled-popup)))
                          ((symbol-function 'frame-parent)
                           (lambda (frame) (if (eq frame 'modeled-popup) parent
                                             (funcall frame-parent-function frame))))
                          ((symbol-function 'frame-terminal)
                           (lambda (frame) (funcall terminal (if (eq frame 'modeled-popup) parent frame)))))
                  (should (equal (list (list 'switch-frame parent) 'norecord)
                                 (emacs-tui--popup-switch-frame arguments)))
                  (set-window-parameter root 'emacs-tui-session nil)
                  (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
                  (set-window-parameter root 'emacs-tui-session app)
                  (set-window-buffer root source)
                  (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
                  (set-window-buffer root view-buffer)
                  (with-current-buffer source (narrow-to-region 2 5))
                  (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
                  (with-current-buffer source (widen))
                  (select-window root)
                  (should (eq arguments (emacs-tui--popup-switch-frame arguments)))
                  (select-window origin)
                  (should (equal (list (list 'switch-frame parent) 'norecord)
                                 (emacs-tui--popup-switch-frame arguments)))))))
        (kill-buffer source)
        (kill-buffer view-buffer)))))

(provide 'emacs-tui-popup-focus-test)
;;; emacs-tui-popup-focus-test.el ends here
