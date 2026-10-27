;;; emacs-tui-board-demo.el --- Three-lane task board -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; A persistent application with three independent lists, no query and no
;; preview.  Move one task or a marked batch with > and < (or the action menu).
;; All task data is copied per session and discarded when the board closes.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)

(defconst emacs-tui-board-demo--tasks
  '((:id keyboard :label "[P1] Key bindings" :lane todo)
    (:id contrast :label "[P2] Text contrast" :lane todo)
    (:id guide :label "[P2] Quick start" :lane todo)
    (:id resize :label "[P1] Resize tests" :lane doing)
    (:id unicode :label "[P2] 日本語 / café" :lane doing)
    (:id prototype :label "[P1] Prototype" :lane done))
  "Initial task data; each board uses its own copy.")

(defun emacs-tui-board-demo--advance ()
  "Move the current board's selected or marked tasks one lane forward."
  (interactive)
  (emacs-tui-act (emacs-tui-current-session) 'advance))

(defun emacs-tui-board-demo--retreat ()
  "Move the current board's selected or marked tasks one lane backward."
  (interactive)
  (emacs-tui-act (emacs-tui-current-session) 'retreat))

;;;###autoload
(defun emacs-tui-board-demo ()
  "Open a three-column task board with explicit batch movement.
Use > to advance and < to move back.  `emacs-tui-toggle-mark' marks tasks,
`emacs-tui-act' offers named actions, and TAB changes lane.  Closing discards
this board's task changes."
  (interactive)
  (let ((tasks (copy-tree emacs-tui-board-demo--tasks))
        (lanes '(todo doing done))
        (map (make-sparse-keymap)))
    (define-key map (kbd ">") #'emacs-tui-board-demo--advance)
    (define-key map (kbd "<") #'emacs-tui-board-demo--retreat)
    (cl-labels
        ((in-lane (lane)
           (cl-remove-if-not (lambda (task) (eq lane (plist-get task :lane))) tasks))
         (title (lane)
           (format "%s (%d) | < > move"
                   (pcase lane ('todo "To do") ('doing "Doing") (_ "Done"))
                   (length (in-lane lane))))
         (move-tasks (app items destination)
           (dolist (item items)
             (setf (plist-get item :lane) destination))
           (dolist (lane lanes)
             (emacs-tui-update app lane :items (in-lane lane) :title (title lane)))
           (emacs-tui-focus-view app destination)
           (emacs-tui-set-selection app destination (plist-get (car items) :id)))
         (action (id label destination)
           (emacs-tui-action
            :id id :title label
            :enabled (lambda (_app items) (and destination (consp items)))
            :run (lambda (app items) (move-tasks app items destination))))
         (view (lane)
           (let ((index (cl-position lane lanes)))
             (emacs-tui-view
              :id lane :title (title lane) :items (in-lane lane) :multi-select t
              :actions (list (action 'advance "Move to next lane" (nth (1+ index) lanes))
                             (action 'retreat "Move to previous lane"
                                     (and (> index 0) (nth (1- index) lanes))))))))
      (emacs-tui-mount :backend 'auto :layout 'columns :keymap map
                       :views (mapcar #'view lanes)))))

(provide 'emacs-tui-board-demo)
;;; emacs-tui-board-demo.el ends here
