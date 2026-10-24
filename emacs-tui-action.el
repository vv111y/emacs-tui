;;; emacs-tui-action.el --- Application-owned context actions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Named actions describe explicit application operations.  Rendering and
;; navigation never evaluate their availability predicates or run callbacks.

;;; Code:
(require 'cl-lib)

(cl-defstruct (emacs-tui--action (:constructor emacs-tui--make-action))
  id title run enabled)

(cl-defun emacs-tui-action (&key id title run (enabled t))
  "Describe an application action with unique ID and optional TITLE.
RUN receives (SESSION ITEMS) on explicit invocation.  ITEMS are marked objects
in source order, including hidden marks, or the selected object as a one-item
list when no marks exist.  With no targets, ITEMS is nil.  The callback owns
all data changes and persistence and may keep the interface open or close it.
ENABLED is t by default, nil to disable, or a pure availability function
receiving the same arguments.  It must return promptly and is called only
when choosing or invoking actions,
never during rendering.  Availability and targets are checked again after a
menu choice so provider updates cannot dispatch stale item objects.
Action descriptions are shared configuration; do not mutate them after use."
  (unless (and id (or (symbolp id) (stringp id)))
    (error "Action ID must be a non-nil symbol or string"))
  (unless (or (null title) (stringp title)) (error "Action title must be a string"))
  (unless (functionp run) (error "Action RUN must be a function"))
  (unless (or (memq enabled '(nil t)) (functionp enabled))
    (error "Action ENABLED must be t, nil or a function"))
  (emacs-tui--make-action :id id :title (or title (format "%s" id)) :run run :enabled enabled))

(defun emacs-tui--validate-actions (actions)
  "Validate ACTIONS as a list of descriptions with distinct IDs."
  (unless (and (proper-list-p actions) (cl-every #'emacs-tui--action-p actions))
    (error "Actions must be a list of emacs-tui-action descriptions"))
  (let ((ids (mapcar #'emacs-tui--action-id actions)))
    (unless (= (length ids) (length (delete-dups (copy-sequence ids))))
      (error "Action IDs must be unique within a view"))))

(provide 'emacs-tui-action)

;; Local Variables:
;; package-lint-main-file: "emacs-tui.el"
;; End:

;;; emacs-tui-action.el ends here
