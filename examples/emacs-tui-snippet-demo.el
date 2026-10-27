;;; emacs-tui-snippet-demo.el --- Embedded snippet picker -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Borrow the selected window for a single snippet list.  RET explicitly inserts
;; a snippet at the tracked original point and restores the host.  q cancels.
;; Native undo in the original buffer reverses the insertion.

;;; Code:
(require 'emacs-tui)

(defconst emacs-tui-snippet-demo--snippets
  '((:id checklist :label "Checklist — three unchecked tasks"
     :text "- [ ] First task\n- [ ] Second task\n- [ ] Third task\n")
    (:id org :label "Org heading — TODO with notes"
     :text "* TODO A new task\n  Notes go here.\n")
    (:id markdown :label "Markdown — heading and paragraph"
     :text "## A new section\n\nWrite your paragraph here.\n")
    (:id json :label "JSON — name and enabled fields"
     :text "{\n  \"name\": \"example\",\n  \"enabled\": true\n}\n"))
  "Literal snippets; selecting one inserts text without evaluating it.")

;;;###autoload
(defun emacs-tui-snippet-demo ()
  "Borrow the current window for a snippet picker.
RET inserts a literal snippet at the original point, then restores the host
window.  q or `emacs-tui-close' cancels without editing.  Normal undo reverses
insertion.  No files are saved and the kill ring is untouched."
  (interactive)
  (let ((target (copy-marker (point))) app ready)
    (unwind-protect
        (progn
          (setq app
                (emacs-tui-embed
                 :view
                 (emacs-tui-view
                  :id 'snippets :title "Insert snippet | RET insert | q cancel"
                  :items emacs-tui-snippet-demo--snippets
                  :on-select
                  (lambda (session item)
                    (let ((buffer (marker-buffer target)))
                      (unless (buffer-live-p buffer) (user-error "Original buffer was killed"))
                      (with-current-buffer buffer
                        (barf-if-buffer-read-only)
                        (save-excursion
                          (save-restriction
                            (widen)
                            (goto-char target)
                            (atomic-change-group (insert (plist-get item :text)))))))
                    (emacs-tui-close session)))
                 :on-close (lambda (_session) (set-marker target nil))))
          (setq ready t)
          app)
      (unless ready
        (if app (emacs-tui-close app) (set-marker target nil))))))

(provide 'emacs-tui-snippet-demo)
;;; emacs-tui-snippet-demo.el ends here
