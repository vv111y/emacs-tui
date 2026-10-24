;;; tty-input-smoke.el --- Native editable views in a real TTY -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise multiline input, native undo, local filtering and real resizes.

;;; Code:
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defvar emacs-tui-test--input-session nil)
(defvar emacs-tui-test--input-phase 1)
(defvar emacs-tui-test--input-attempts 0)
(defvar emacs-tui-test--input-small-width nil)
(defvar emacs-tui-test--input-calls 0)
(defvar emacs-tui-test--input-expected-calls nil)
(defvar emacs-tui-test--input-tick nil)

(defun emacs-tui-test--input-failure (err)
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
    (insert (format "FAIL input: %S\n" err)))
  (kill-emacs 1))

(defun emacs-tui-test--input-resized ()
  (condition-case err
      (let* ((session emacs-tui-test--input-session)
             (parent (emacs-tui--workspace-origin-frame session))
             (child (emacs-tui--workspace-frame session))
             (phase emacs-tui-test--input-phase)
             (width (if (= phase 1) 90 140))
             (height (if (= phase 1) 30 45)))
        (cl-incf emacs-tui-test--input-attempts)
        (when (> emacs-tui-test--input-attempts 100) (error "Input resize did not settle"))
        (redisplay t)
        (when (and (= (frame-width parent) width)
                   (<= (- height 2) (frame-height parent) height)
                   (or (not child)
                       (and (< (frame-width child) width) (< (frame-height child) height)
                            (or (= phase 1) (> (frame-width child) emacs-tui-test--input-small-width)))))
          (cl-assert (emacs-tui-live-p session))
          (cl-assert (equal "alpha\nbeta" (emacs-tui-input-value session 'body)))
          (cl-assert (equal "alpha\nbeta" (emacs-tui-query session 'filtered)))
          (cl-assert (equal '("alpha beta")
                            (emacs-tui--view-visible-items
                             (emacs-tui--resolve-view session 'filtered))))
          (cl-assert (= 11 (window-point (selected-window))))
          (cl-assert (= emacs-tui-test--input-expected-calls emacs-tui-test--input-calls))
          (with-current-buffer (window-buffer (selected-window))
            (cl-assert (derived-mode-p 'emacs-tui-field-mode))
            (cl-assert (= emacs-tui-test--input-tick (buffer-chars-modified-tick)))
            (cl-assert buffer-undo-list))
          (if (= phase 1)
              (progn
                (setq emacs-tui-test--input-small-width (when child (frame-width child))
                      emacs-tui-test--input-phase 2
                      emacs-tui-test--input-attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
            (execute-kbd-macro (kbd "C-c C-q"))
            (cl-assert (not (emacs-tui-live-p session)))
            (cl-assert (null emacs-tui--sessions))
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; real TTY; backend=%s; input=multiline; filter=passed; undo=passed; resize=120x40->90x30->140x45\n"
                              emacs-version (emacs-tui--workspace-backend session))))
            (kill-emacs 0))))
    ((error quit) (emacs-tui-test--input-failure err))))

(defun emacs-tui-test--input-start ()
  (condition-case err
      (progn
        (setq emacs-tui-test--input-session
              (emacs-tui-mount
               :backend (if (featurep 'tty-child-frames) 'child-frame 'windows)
               :views (list (emacs-tui-input
                             :id 'body
                             :on-change (lambda (app _id value)
                                          (cl-incf emacs-tui-test--input-calls)
                                          (emacs-tui-update app 'preview :text (upcase value))
                                          (emacs-tui-set-query app 'filtered value)))
                            (emacs-tui-view :id 'preview :text "")
                            (emacs-tui-view :id 'filtered :items '("alpha beta" "gamma")))))
        (execute-kbd-macro (kbd "a l p h a RET b e t a"))
        (undo-boundary)
        (insert "!")
        (undo-boundary)
        (undo-only 1)
        (cl-assert (equal "alpha\nbeta" (emacs-tui-input-value emacs-tui-test--input-session)))
        (execute-kbd-macro (kbd "TAB"))
        (cl-assert (equal "ALPHA\nBETA" (buffer-string)))
        (execute-kbd-macro (kbd "<backtab>"))
        (setq emacs-tui-test--input-expected-calls emacs-tui-test--input-calls
              emacs-tui-test--input-tick (buffer-chars-modified-tick))
        (redisplay t)
        (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))
        (run-at-time 0.05 0.05 #'emacs-tui-test--input-resized))
    ((error quit) (emacs-tui-test--input-failure err))))

(add-hook 'emacs-startup-hook (lambda () (run-at-time 0.1 nil #'emacs-tui-test--input-start)))

;;; tty-input-smoke.el ends here
