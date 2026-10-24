;;; emacs-tui-buffer-tree.el --- Buffers grouped by mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Browse real buffer objects grouped by major mode.  Expand with right/space,
;; collapse or visit the parent with left.  RET previews, o displays the buffer
;; elsewhere, and g refreshes the snapshot while retaining stable identities.

;;; Code:
(require 'emacs-tui)

(defun emacs-tui-buffer-tree--items ()
  "Return a fresh mode-grouped snapshot of visible user buffers."
  (let ((groups (make-hash-table :test #'eq)) result)
    (dolist (buffer (buffer-list))
      (unless (string-prefix-p " " (buffer-name buffer))
        (with-current-buffer buffer
          (puthash major-mode
                   (cons (list :id buffer :label (buffer-name buffer) :value buffer)
                         (gethash major-mode groups)) groups))))
    (maphash (lambda (mode items)
               (push (list :id (list 'mode mode) :label (symbol-name mode)
                           :children (sort items (lambda (a b)
                                                   (string-lessp (plist-get a :label)
                                                                 (plist-get b :label))))) result))
             groups)
    (sort result (lambda (a b) (string-lessp (plist-get a :label) (plist-get b :label))))))

(defun emacs-tui-buffer-tree--preview (session item)
  "Preview ITEM from SESSION without changing its source buffer."
  (let ((buffer (plist-get item :value)))
    (emacs-tui-update
     session 'preview :text
     (if buffer
         (progn
           (unless (buffer-live-p buffer) (user-error "Buffer was killed; refresh the tree"))
           (with-current-buffer buffer
             (save-restriction
               (widen)
               (concat (format "%s | %s | %d characters\n\n" (buffer-name) major-mode (buffer-size))
                       (buffer-substring-no-properties (point-min) (min (point-max) 4001))))))
       (format "%s: %d buffers" (plist-get item :label) (length (plist-get item :children)))))))

(defun emacs-tui-buffer-tree-refresh ()
  "Refresh the buffer snapshot while preserving branch and selection state."
  (interactive)
  (emacs-tui-update (emacs-tui-current-session) 'buffers :items (emacs-tui-buffer-tree--items)))

(defun emacs-tui-buffer-tree-display ()
  "Display the selected buffer elsewhere without closing the tree."
  (interactive)
  (let ((buffer (plist-get (emacs-tui-current-item) :value)))
    (unless (buffer-live-p buffer) (user-error "Select a live buffer leaf"))
    (display-buffer buffer '(nil (inhibit-same-window . t)))))

(defvar emacs-tui-buffer-tree-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'emacs-tui-buffer-tree-refresh)
    (define-key map (kbd "o") #'emacs-tui-buffer-tree-display)
    map)
  "Commands for the buffer tree application.")

;;;###autoload
(defun emacs-tui-buffer-tree ()
  "Browse buffers by major mode in a persistent tree with a preview.
Use `emacs-tui-tree-expand' and `emacs-tui-tree-collapse' to navigate,
`emacs-tui-select' to preview, and `emacs-tui-buffer-tree-display' to display."
  (interactive)
  (emacs-tui-mount
   :keymap emacs-tui-buffer-tree-map
   :views (list (emacs-tui-tree :id 'buffers :title "Buffers | RET preview | o display | g refresh"
                               :items (emacs-tui-buffer-tree--items) :multi-select t
                               :on-select #'emacs-tui-buffer-tree--preview)
                (emacs-tui-view :id 'preview :text "Expand a mode group and select a buffer."))))

(provide 'emacs-tui-buffer-tree)
;;; emacs-tui-buffer-tree.el ends here
