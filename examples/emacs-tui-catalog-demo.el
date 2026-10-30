;;; emacs-tui-catalog-demo.el --- Searchable sample catalog -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6-astra-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; A self-contained table application: native search, numeric sorting, equal fill
;; columns, hidden marks, explicit batch actions and formatted object previews.
;; The collection is session-local; no files, network or clipboard are changed.

;;; Code:
(require 'emacs-tui)

(defconst emacs-tui-catalog-demo--items
  '((:id atlas :label "Atlas" :kind "Map" :size 48 :description "An atlas of imaginary islands.")
    (:id birch :label "Birch" :kind "Note" :size 7 :description "Field notes from a northern forest.")
    (:id comet :label "Comet" :kind "Image" :size 120 :description "A long exposure of the night sky.")
    (:id delta :label "Delta" :kind "Map" :size 32 :description "River channels and walking routes.")
    (:id echo :label "Echo" :kind "Audio" :size 256 :description "A recording of a quiet canyon.")
    (:id fern :label "Fern" :kind "Note" :size 12 :description "A small botanical notebook.")
    (:id garden :label "日本語 garden" :kind "Image" :size 80 :description "Wide characters share the same table.")
    (:id cafe :label "Café sketches" :kind "Note" :size 18 :description "Unicode text remains searchable."))
  "Immutable sample objects shared by catalog sessions.")

(defun emacs-tui-catalog-demo--preview (app item)
  "Show the original ITEM's details in APP."
  (emacs-tui-update
   app 'details :text
   (concat (propertize (plist-get item :label) 'face 'bold)
           (format "\n\nType: %s\nSize: %d KiB\n\n%s\n\n"
                   (plist-get item :kind) (plist-get item :size)
                   (plist-get item :description))
           "RET only inspects. Mark rows with C-c C-m; use a for batch actions.\n"
           "Search for Note, mark all with C-c *, then search Map.\n"
           "Hidden marks remain action targets. Clear marks with C-c C-u.")))

;;;###autoload
(defun emacs-tui-catalog-demo ()
  "Browse sample objects and explicitly collect marked or selected items.
Search, sorting and inspection do not change the collection.  Closing discards
it.  Use the table's actions menu to collect items or clear the collection."
  (interactive)
  (let (collected)
    (emacs-tui-mount
     :backend 'auto :layout 'grid
     :views
     (list
      (emacs-tui-input
       :id 'search :title "Search | try Note or 日本語 | TAB table"
       :on-change (lambda (app _id value)
                    (emacs-tui-set-query app 'catalog value)))
      (emacs-tui-view
       :id 'catalog :title "Catalog | RET inspect | C-c C-m mark | s sort | a actions"
       :items emacs-tui-catalog-demo--items :multi-select t
       :columns (list (emacs-tui-column :id 'name :title "Name" :width 'fill :value :label)
                      (emacs-tui-column :id 'description :title "Description"
                                        :width 'fill :value :description)
                      (emacs-tui-column :id 'kind :title "Type" :width 6 :value :kind)
                      (emacs-tui-column :id 'size :title "KiB" :width 5 :value :size :align 'right))
       :on-select #'emacs-tui-catalog-demo--preview
       :actions
       (list
        (emacs-tui-action
         :id 'collect :title "Collect marked or selected objects"
         :enabled (lambda (_app items) (consp items))
         :run (lambda (app items)
                (dolist (item items)
                  (unless (memq item collected)
                    (setq collected (append collected (list item)))))
                (emacs-tui-update app 'collection :text
                                  (concat "Collected (session only):\n\n"
                                          (mapconcat (lambda (item) (plist-get item :label))
                                                     collected "\n")))))
        (emacs-tui-action
         :id 'clear :title "Clear collection"
         :enabled (lambda (_app _items) (consp collected))
         :run (lambda (app _items)
                (setq collected nil)
                (emacs-tui-update app 'collection :text "Collection empty.")))))
      (emacs-tui-view :id 'details :title "Object details"
                      :text "TAB to the catalog; RET inspects an object.\nNo action writes to disk.")
      (emacs-tui-view :id 'collection :title "Collection | explicit actions only"
                      :text "Collection empty.")))))

(provide 'emacs-tui-catalog-demo)
;;; emacs-tui-catalog-demo.el ends here
