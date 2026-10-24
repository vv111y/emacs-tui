;;; emacs-tui-composer.el --- Persistent text composition demo -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Edit a prefix and multiline text with normal Emacs commands.  A preview
;; updates as you type.  C-c C-c copies the result to the kill ring explicitly;
;; the application stays open.  C-c C-q closes and discards the scratch inputs.

;;; Code:
(require 'emacs-tui)

(defun emacs-tui-composer--result (session)
  "Return SESSION's composition without changing application or buffer state."
  (let ((prefix (emacs-tui-input-value session 'prefix))
        (body (emacs-tui-input-value session 'body)))
    (mapconcat (lambda (line) (concat prefix line)) (split-string body "\n") "\n")))

(defun emacs-tui-composer--changed (session _id _value)
  "Refresh SESSION's preview after a scratch input edit."
  (emacs-tui-update session 'preview :text (emacs-tui-composer--result session)))

(defun emacs-tui-composer-copy ()
  "Copy the current composition to the kill ring, keeping the interface open."
  (interactive)
  (kill-new (emacs-tui-composer--result (emacs-tui-current-session)))
  (message "Composition copied"))

(defvar emacs-tui-composer-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'emacs-tui-composer-copy)
    map)
  "Application commands shared by input and preview views.")

;;;###autoload
(defun emacs-tui-composer ()
  "Open a persistent composer with two editable inputs and a live preview.
Normal typing, newline and undo edit the inputs.
Use `emacs-tui-composer-copy' to copy the result and `emacs-tui-close' to exit."
  (interactive)
  (let ((session
         (emacs-tui-mount
          :layout 'rows :keymap emacs-tui-composer-map
          :views (list (emacs-tui-input :id 'prefix :title "Prefix" :value "* "
                                       :on-change #'emacs-tui-composer--changed)
                       (emacs-tui-input :id 'body :title "Text" :value "First line\nSecond line"
                                       :on-change #'emacs-tui-composer--changed)
                       (emacs-tui-view :id 'preview :title "Preview | C-c C-c copy"
                                       :text "")))))
    (emacs-tui-composer--changed session nil nil)
    session))

(provide 'emacs-tui-composer)
;;; emacs-tui-composer.el ends here
