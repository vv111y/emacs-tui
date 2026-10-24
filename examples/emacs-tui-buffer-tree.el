;;; emacs-tui-buffer-tree.el --- Buffers grouped by mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Browse real buffer objects grouped by major mode.  Expand with right/space,
;; collapse or visit the parent with left.  RET previews, a offers named actions,
;; and o displays the buffer
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

(defun emacs-tui-buffer-tree--display (item)
  "Display ITEM's buffer elsewhere, rejecting non-buffer nodes."
  (let ((buffer (plist-get item :value)))
    (unless (buffer-live-p buffer) (user-error "Select a live buffer leaf"))
    (display-buffer buffer '(nil (inhibit-same-window . t)))))

(defun emacs-tui-buffer-tree-display ()
  "Display the selected buffer elsewhere without closing the tree."
  (interactive)
  (emacs-tui-buffer-tree--display (emacs-tui-current-item)))

(defun emacs-tui-buffer-tree--actions ()
  "Return explicit single-object and batch actions for the buffer tree."
  (list
   (emacs-tui-action
    :id 'preview :title "Preview"
    :enabled (lambda (_app items) (= 1 (length items)))
    :run (lambda (app items) (emacs-tui-buffer-tree--preview app (car items))))
   (emacs-tui-action
    :id 'display :title "Display buffer"
    :enabled (lambda (_app items)
               (and (= 1 (length items)) (buffer-live-p (plist-get (car items) :value))))
    :run (lambda (_app items) (emacs-tui-buffer-tree--display (car items))))
   (emacs-tui-action
    :id 'copy :title "Copy names"
    :enabled (lambda (_app items) (consp items))
    :run (lambda (_app items)
           (kill-new (mapconcat (lambda (item) (plist-get item :label)) items "\n"))))
   (emacs-tui-action
    :id 'refresh :title "Refresh"
    :run (lambda (app _items)
           (emacs-tui-update app 'buffers :items (emacs-tui-buffer-tree--items))))))

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
   :views (list (emacs-tui-tree :id 'buffers :title "Buffers | RET preview | a actions | g refresh"
                               :items (emacs-tui-buffer-tree--items) :multi-select t
                               :actions (emacs-tui-buffer-tree--actions)
                               :on-select #'emacs-tui-buffer-tree--preview)
                (emacs-tui-view :id 'preview :text "Expand a mode group and select a buffer."))))

(provide 'emacs-tui-buffer-tree)
;;; emacs-tui-buffer-tree.el ends here
