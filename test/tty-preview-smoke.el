;;; tty-preview-smoke.el --- Read wide previews in ordinary TTY windows -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise real redisplay on every supported Emacs, without child frames.

;;; Code:
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defvar emacs-tui-preview-smoke--app nil)
(defvar emacs-tui-preview-smoke--phase 1)
(defvar emacs-tui-preview-smoke--attempts 0)
(defvar emacs-tui-preview-smoke--input nil)
(defvar emacs-tui-preview-smoke--point nil)
(defvar emacs-tui-preview-smoke--host nil)
(defvar emacs-tui-preview-smoke--closed 0)

(defun emacs-tui-preview-smoke--fail (error)
  "Report ERROR and terminate the isolated test process."
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
    (insert (format "FAIL preview: %S\n" error)))
  (kill-emacs 1))

(defun emacs-tui-preview-smoke--check ()
  "Assert horizontal reading and input preservation after native redisplay."
  (let* ((app emacs-tui-preview-smoke--app)
         (view (emacs-tui--resolve-view app 'preview))
         (window (emacs-tui--view-window view)))
    (redisplay t)
    (cl-assert (eq 'windows (emacs-tui--workspace-backend app)))
    (cl-assert (null (emacs-tui--workspace-frame app)))
    (cl-assert (eq 'draft (emacs-tui-current-view app)))
    (cl-assert (eq emacs-tui-preview-smoke--input (current-buffer)))
    (cl-assert (= emacs-tui-preview-smoke--point (point)))
    (cl-assert (equal "xDraft" (emacs-tui-input-value app 'draft)))
    (cl-assert (= 40 (window-hscroll window)))
    (with-current-buffer (emacs-tui--view-buffer view)
      (save-excursion
        (goto-char (point-min))
        (search-forward "PAN-TARGET")
        (cl-assert (pos-visible-in-window-p (- (point) 10) window))))))

(defun emacs-tui-preview-smoke--resized ()
  "Finish the two actual terminal resize phases, then dispose all resources."
  (condition-case err
      (let* ((app emacs-tui-preview-smoke--app)
             (phase emacs-tui-preview-smoke--phase)
             (width (if (= phase 1) 90 140)))
        (cl-incf emacs-tui-preview-smoke--attempts)
        (when (> emacs-tui-preview-smoke--attempts 100)
          (error "Preview resize did not settle"))
        (redisplay t)
        (when (and (= width (frame-width))
                   (equal (emacs-tui--workspace-geometry app)
                          (emacs-tui--geometry app)))
          (emacs-tui-preview-smoke--check)
          (if (= phase 1)
              (progn
                (setq emacs-tui-preview-smoke--phase 2
                      emacs-tui-preview-smoke--attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
            (emacs-tui-set-layout app 'rows)
            (emacs-tui-preview-smoke--check)
            (emacs-tui-toggle-maximize app)
            (emacs-tui-toggle-maximize app)
            (emacs-tui-preview-smoke--check)
            (emacs-tui-refresh app)
            ;; A native cursor command triggers automatic horizontal scrolling;
            ;; inactive panes alone do not expose a lost manual minimum.
            (emacs-tui-focus-view app 'preview)
            (execute-kbd-macro (kbd "C-a C-f"))
            (redisplay t)
            (cl-assert (= 40 (window-hscroll (selected-window))))
            (emacs-tui-focus-view app 'draft)
            (emacs-tui-preview-smoke--check)
            (emacs-tui-scroll-view app 'preview 3)
            (let ((window (emacs-tui--view-window
                           (emacs-tui--resolve-view app 'preview))))
              (redisplay t)
              (cl-assert (> (window-start window) 1))
              (cl-assert (= 40 (window-hscroll window)))
              (emacs-tui-update app 'preview :text "A different object")
              (redisplay t)
              (cl-assert (= 0 (window-hscroll window))))
            (execute-kbd-macro (kbd "C-/"))
            (cl-assert (equal "Draft" (emacs-tui-input-value app 'draft)))
            (let ((buffers (mapcar #'emacs-tui--view-buffer
                                   (emacs-tui--workspace-views app))))
              (emacs-tui-close app)
              (cl-assert (cl-every (lambda (b) (not (buffer-live-p b))) buffers)))
            (cl-assert (= 1 emacs-tui-preview-smoke--closed))
            (cl-assert (null emacs-tui--sessions))
            (cl-assert (= 1 (length (window-list))))
            (cl-assert (eq emacs-tui-preview-smoke--host
                           (window-buffer (car (window-list)))))
            (cl-assert (equal "original source" (with-current-buffer
                                                    emacs-tui-preview-smoke--host
                                                  (buffer-string))))
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; ordinary TTY preview; horizontal payload visible; native input/undo; resize=120->90->140; rows/maximize/refresh; preview focus/cursor/return; vertical composition; changed-content reset; cleanup\n" emacs-version)))
            (kill-emacs 0))))
    ((error quit) (emacs-tui-preview-smoke--fail err))))

(defun emacs-tui-preview-smoke--start ()
  "Mount an input and wide preview, then pan using a native command key."
  (condition-case err
      (let ((map (make-sparse-keymap)))
        (switch-to-buffer (get-buffer-create "*Preview source*"))
        (insert "original source")
        (setq emacs-tui-preview-smoke--host (current-buffer))
        (define-key map (kbd "C-c >")
          (lambda () (interactive)
            (emacs-tui-scroll-view-horizontally
             emacs-tui-preview-smoke--app 'preview 40)))
        (setq emacs-tui-preview-smoke--app
              (emacs-tui-mount
               :backend 'windows :keymap map
               :views (list (emacs-tui-input :id 'draft :value "Draft")
                            (emacs-tui-view :id 'preview
                                            :text (mapconcat
                                                   (lambda (i)
                                                     (concat (format "%03d " i)
                                                             (make-string 66 ?.)
                                                             "PAN-TARGET 日本語 é"))
                                                   (number-sequence 1 100) "\n")))
               :on-close (lambda (_) (cl-incf emacs-tui-preview-smoke--closed))))
        (execute-kbd-macro (kbd "x C-c >"))
        (setq emacs-tui-preview-smoke--input (current-buffer)
              emacs-tui-preview-smoke--point (point))
        (emacs-tui-preview-smoke--check)
        (with-temp-file (getenv "EMACS_TUI_SMOKE_PAINT") (insert "PAN-TARGET"))
        (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))
        (run-at-time 0.05 0.05 #'emacs-tui-preview-smoke--resized))
    ((error quit) (emacs-tui-preview-smoke--fail err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-preview-smoke--start)))

;;; tty-preview-smoke.el ends here
