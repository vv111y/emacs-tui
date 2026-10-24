;;; emacs-tui-filter-demo.el --- Persistent search over a table -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; A native input filters an unchanged buffer table.  Mark objects, narrow the
;; display, and clear the input: hidden marks survive.  TAB visits the table,
;; RET previews, and C-c C-r refreshes source snapshots without clearing filters.

;;; Code:
(require 'emacs-tui)

(defun emacs-tui-filter-demo--items ()
  "Return buffer objects with searchable name, mode and size metadata."
  (let (items)
    (dolist (buffer (buffer-list))
      (unless (string-prefix-p " " (buffer-name buffer))
        (with-current-buffer buffer
          (push (list :id buffer :label (buffer-name buffer) :value buffer
                      :mode (symbol-name major-mode) :size (buffer-size)) items))))
    (nreverse items)))

(defun emacs-tui-filter-demo-refresh ()
  "Refresh the table snapshot without replacing its local search."
  (interactive)
  (emacs-tui-update (emacs-tui-current-session) 'buffers :items (emacs-tui-filter-demo--items)))

(defun emacs-tui-filter-demo--preview (session item)
  "Show ITEM's source in SESSION's preview without moving its cursor."
  (let ((buffer (plist-get item :value)))
    (unless (buffer-live-p buffer) (user-error "Buffer was killed; refresh the table"))
    (emacs-tui-update session 'preview :text
                      (with-current-buffer buffer
                        (save-restriction
                          (widen)
                          (buffer-substring-no-properties (point-min) (min (point-max) 4001)))))))

(defvar emacs-tui-filter-demo-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-r") #'emacs-tui-filter-demo-refresh)
    map)
  "Explicit application refresh command, preserving native input keys.")

;;;###autoload
(defun emacs-tui-filter-demo ()
  "Open a persistent native search input, buffer table and preview.
Type name or mode terms, switch views with `emacs-tui-next-view', and preview
with `emacs-tui-select'.  Hidden marks and sorting survive local queries."
  (interactive)
  (emacs-tui-mount
   :keymap emacs-tui-filter-demo-map
   :views
   (list (emacs-tui-input :id 'search :title "Search buffers | TAB table | C-c C-r refresh"
                          :on-change (lambda (app _id value)
                                       (emacs-tui-set-query app 'buffers value)))
         (emacs-tui-view :id 'buffers :title "Buffers | RET preview" :multi-select t
                         :items (emacs-tui-filter-demo--items)
                         :columns (list (emacs-tui-column :id 'name :title "Name" :width 24 :value :label)
                                        (emacs-tui-column :id 'mode :title "Mode" :width 20 :value :mode)
                                        (emacs-tui-column :id 'size :title "Size" :width 9 :value :size :align 'right))
                         :on-select #'emacs-tui-filter-demo--preview)
         (emacs-tui-view :id 'preview :text "Select a buffer to preview its contents."))))

(provide 'emacs-tui-filter-demo)
;;; emacs-tui-filter-demo.el ends here
