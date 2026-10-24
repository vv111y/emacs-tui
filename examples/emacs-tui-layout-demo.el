;;; emacs-tui-layout-demo.el --- Layout and native editing playground -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6-astra-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Four panels demonstrate layout selection, maximize/restore, hidden-panel
;; focus, trees, native input/undo, Unicode and text properties.  Resize the
;; terminal freely.  C-c e focuses the editor even when another panel is maximized.

;;; Code:
(require 'emacs-tui)

(defun emacs-tui-layout-demo--preview (app _id value)
  "Render APP's scratch editor VALUE without saving it."
  (emacs-tui-update app 'preview :text
                    (concat (propertize "Live native text preview" 'face 'bold)
                            "\n\n" value
                            "\n\nC-c C-l cycles layouts; C-u C-c C-l chooses one.\n"
                            "C-c C-f maximizes/restores; TAB visits hidden panels.\n"
                            "C-c e focuses the editor. C-c C-q closes.\n"
                            "Try undo, paste, wide text 日本語 and combining text é.")))

;;;###autoload
(defun emacs-tui-layout-demo ()
  "Open four panels for interactive layout, tree and editing experiments.
Controls select layouts without restarting the interface.  Scratch editing
and tree marks survive layout changes; closing discards the scratch text."
  (interactive)
  (let ((map (make-sparse-keymap)) (initial "Hello, Emacs!\n日本語 / café / é") app ready)
    (define-key map (kbd "C-c e")
                (lambda () (interactive)
                  (emacs-tui-focus-view (emacs-tui-current-session) 'editor)))
    (unwind-protect
        (progn
          (setq app
                (emacs-tui-mount
                 :backend 'auto :layout 'grid :keymap map
                 :views
                 (list
                  (emacs-tui-view
                   :id 'controls :title "Layout controls | RET applies"
                   :items '((:id columns :label "Columns") (:id rows :label "Rows")
                            (:id grid :label "Grid") (:id editor :label "Focus editor")
                            (:id maximize :label "Maximize this panel"))
                   :on-select (lambda (session item)
                                (pcase (plist-get item :id)
                                  ('editor (emacs-tui-focus-view session 'editor))
                                  ('maximize (emacs-tui-toggle-maximize session))
                                  (layout (emacs-tui-set-layout session layout)))))
                  (emacs-tui-tree
                   :id 'outline :title "Tree | SPC expand | C-c C-m mark | C-c + expand all"
                   :multi-select t
                   :items '((:id world :label "World"
                              :children ((:id japan :label "日本語") (:id cafe :label "Café")))
                            (:id tools :label "Tools"
                             :children ((:id emacs :label "Emacs") (:id lisp :label "Lisp")))))
                  (emacs-tui-input :id 'editor :title "Editor | native typing and undo"
                                   :value initial :on-change #'emacs-tui-layout-demo--preview)
                  (emacs-tui-view :id 'preview :title "Preview | scroll and resize" :text ""))))
          (emacs-tui-layout-demo--preview app nil initial)
          (setq ready t)
          app)
      (unless ready (when app (emacs-tui-close app))))))

(provide 'emacs-tui-layout-demo)
;;; emacs-tui-layout-demo.el ends here
