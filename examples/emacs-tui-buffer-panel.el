;;; emacs-tui-buffer-panel.el --- Embedded buffer browser -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Run M-x emacs-tui-buffer-panel to temporarily display a buffer browser in
;; the selected application window.  RET displays a buffer elsewhere; q
;; restores the application's original buffer and position in the same window.

;;; Code:
(require 'emacs-tui)
(require 'seq)

;;;###autoload
(defun emacs-tui-buffer-panel ()
  "Embed a buffer browser in the selected window.
Use n/p to navigate, RET to display a buffer in another window, and q
to restore this window's original buffer.  Buffer contents are not edited."
  (interactive)
  (emacs-tui-embed
   :view
   (emacs-tui-view
    :id 'buffers :title "Buffers | RET display elsewhere | q restore"
    :items (mapcar (lambda (buffer)
                     (list :id buffer :label (buffer-name buffer) :value buffer))
                   (seq-filter (lambda (buffer)
                                 (not (string-prefix-p " " (buffer-name buffer))))
                               (buffer-list)))
    :on-select (lambda (_app item)
                 (let ((buffer (plist-get item :value)))
                   (unless (buffer-live-p buffer) (user-error "Buffer was killed"))
                   (display-buffer buffer '(nil (inhibit-same-window . t))))))))

(provide 'emacs-tui-buffer-panel)
;;; emacs-tui-buffer-panel.el ends here
