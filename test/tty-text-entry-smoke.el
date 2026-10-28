;;; tty-text-entry-smoke.el --- Terminal paste and input methods -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Receive actual PTY bytes, not keyboard macros or direct Lisp insertion.

;;; Code:
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'json)
(require 'emacs-tui)

(defconst emacs-tui-entry--paste "PASTE 日本語 é\nsecond line")
(defvar emacs-tui-entry--app nil)
(defvar emacs-tui-entry--phase 'paste)
(defvar emacs-tui-entry--attempts 0)
(defvar emacs-tui-entry--calls 0)
(defvar emacs-tui-entry--tick nil)
(defvar emacs-tui-entry--expected-calls nil)
(defvar emacs-tui-entry--host nil)
(defvar emacs-tui-entry--completed-phase nil)

(defun emacs-tui-entry--send (id text)
  "Ask the PTY driver to deliver TEXT once for ID."
  (let* ((path (getenv "EMACS_TUI_SMOKE_INPUT"))
         (temporary (concat path ".tmp")))
    (with-temp-file temporary
      (insert (json-encode `((id . ,id) (text . ,text)))))
    (rename-file temporary path t)
    (setq emacs-tui-entry--attempts 0)))

(defun emacs-tui-entry--command-completed ()
  "Record a terminal cursor command after Quail has committed its preedit."
  (when (eq this-command 'forward-char)
    (setq emacs-tui-entry--completed-phase emacs-tui-entry--phase)))

(defun emacs-tui-entry--fail (err)
  "Report ERR and stop this isolated process."
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
    (insert (format "FAIL text entry phase=%S: %S; input=%S; preview=%S\n"
                    emacs-tui-entry--phase err
                    (ignore-errors
                      (emacs-tui-input-value emacs-tui-entry--app 'body))
                    (ignore-errors
                      (with-current-buffer (emacs-tui--view-buffer
                                            (emacs-tui--resolve-view emacs-tui-entry--app 'preview))
                        (buffer-string))))))
  (kill-emacs 1))

(defun emacs-tui-entry--check ()
  "Advance after real command-loop input or terminal resize has completed."
  (condition-case err
      (let* ((app emacs-tui-entry--app)
             (value (emacs-tui-input-value app 'body)))
        (cl-incf emacs-tui-entry--attempts)
        (when (> emacs-tui-entry--attempts 100)
          (error "Text entry did not settle: %S %S" emacs-tui-entry--phase value))
        (cl-assert (eq 'body (emacs-tui-current-view app)))
        (pcase emacs-tui-entry--phase
          ('paste
           (when (equal value emacs-tui-entry--paste)
             (cl-assert (equal value (with-current-buffer
                                        (emacs-tui--view-buffer
                                         (emacs-tui--resolve-view app 'preview))
                                      (buffer-string))))
             (cl-assert (> emacs-tui-entry--calls 0))
             (redisplay t)
             (with-temp-file (getenv "EMACS_TUI_SMOKE_PAINT") (insert "PASTE"))
             (setq emacs-tui-entry--phase 'undo)
             (emacs-tui-entry--send "undo-paste" "\37")))
          ('undo
           (when (equal value "")
             (activate-input-method "latin-postfix")
             (setq emacs-tui-entry--phase 'compose)
             ;; A cursor command commits Quail's preedit.  Timers can run while
             ;; preedit text is visible but no application edit has committed.
             ;; Real bytes exercise the input method; keyboard macros bypass it.
             (emacs-tui-entry--send "compose" "a' \C-b\C-f")))
          ('compose
           (when (and (eq emacs-tui-entry--completed-phase 'compose)
                      (equal value "á "))
             (cl-assert (equal current-input-method "latin-postfix"))
             (setq emacs-tui-entry--tick (buffer-chars-modified-tick)
                   emacs-tui-entry--expected-calls emacs-tui-entry--calls)
             (emacs-tui-refresh app)
             (emacs-tui-cycle-layout app)
             (cl-assert (equal (emacs-tui-input-value app 'body) "á "))
             (cl-assert (= (point) 3))
             (cl-assert (equal current-input-method "latin-postfix"))
             (cl-assert (= emacs-tui-entry--tick (buffer-chars-modified-tick)))
             (cl-assert (= emacs-tui-entry--expected-calls emacs-tui-entry--calls))
             (setq emacs-tui-entry--phase 'small
                   emacs-tui-entry--attempts 0)
             (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))))
          ((or 'small 'large)
           (redisplay t)
           (when (and (= (frame-width (emacs-tui--workspace-origin-frame app))
                         (if (eq emacs-tui-entry--phase 'small) 90 140))
                      (equal (emacs-tui--workspace-geometry app)
                             (emacs-tui--geometry app)))
             (cl-assert (equal value "á "))
             (cl-assert (equal current-input-method "latin-postfix"))
             (cl-assert (= (point) 3))
             (cl-assert (= emacs-tui-entry--tick (buffer-chars-modified-tick)))
             (cl-assert (= emacs-tui-entry--expected-calls emacs-tui-entry--calls))
             (if (eq emacs-tui-entry--phase 'small)
                 (progn
                   (setq emacs-tui-entry--phase 'large emacs-tui-entry--attempts 0)
                   (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
               (setq emacs-tui-entry--phase 'continued)
               (emacs-tui-entry--send "compose-after-resize" "o' \C-b\C-f"))))
          ('continued
           (when (and (eq emacs-tui-entry--completed-phase 'continued)
                      (equal value "á ó "))
             (cl-assert (> emacs-tui-entry--calls emacs-tui-entry--expected-calls))
             (cl-assert (equal value (with-current-buffer
                                        (emacs-tui--view-buffer
                                         (emacs-tui--resolve-view app 'preview))
                                      (buffer-string))))
             (let ((buffers (mapcar #'emacs-tui--view-buffer
                                    (emacs-tui--workspace-views app))))
               (emacs-tui-close app)
               (cl-assert (cl-every (lambda (b) (not (buffer-live-p b))) buffers)))
             (cl-assert (null emacs-tui--sessions))
             (cl-assert (eq (current-buffer) emacs-tui-entry--host))
             (cl-assert (equal (buffer-string) "Source unchanged"))
             (cl-assert (null current-input-method))
             (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
               (insert (format "PASS Emacs %s; actual PTY UTF-8 bracketed paste; native undo; latin-postfix composition before/after refresh/layout/120->90->140 resize; callbacks; source isolation; cleanup\n" emacs-version)))
             (kill-emacs 0)))))
    ((error quit) (emacs-tui-entry--fail err))))

(defun emacs-tui-entry--start ()
  "Mount a native field and receive bracketed paste from the driver."
  (condition-case err
      (progn
        (switch-to-buffer (get-buffer-create "*Text entry source*"))
        (insert "Source unchanged")
        (setq emacs-tui-entry--host (current-buffer)
              emacs-tui-entry--app
              (emacs-tui-mount
               :backend (if (featurep 'tty-child-frames) 'child-frame 'windows)
               :views (list
                       (emacs-tui-input
                        :id 'body
                        :on-change (lambda (app _id value)
                                     (cl-incf emacs-tui-entry--calls)
                                     (emacs-tui-update app 'preview :text value)))
                       (emacs-tui-view :id 'preview :text ""))))
        (add-hook 'post-command-hook #'emacs-tui-entry--command-completed nil t)
        (emacs-tui-entry--send "paste" (concat "\e[200~" emacs-tui-entry--paste "\e[201~"))
        (run-at-time 0.05 0.05 #'emacs-tui-entry--check))
    ((error quit) (emacs-tui-entry--fail err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-entry--start)))

;;; tty-text-entry-smoke.el ends here
