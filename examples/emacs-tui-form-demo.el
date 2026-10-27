;;; emacs-tui-form-demo.el --- Validated settings form -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Native editable fields, checkbox-style choices and live validation compose
;; a persistent settings form.  Apply changes only this session's saved record;
;; Revert restores that record.  No files or actual Emacs settings are changed.

;;; Code:
(require 'cl-lib)
(require 'subr-x)
(require 'emacs-tui)

(defun emacs-tui-form-demo--errors (name retries)
  "Return validation messages for draft NAME and RETRIES strings."
  (append
   (when (or (string-empty-p (string-trim name))
             (> (length name) 60) (string-match-p "[\n\r]" name))
     '("Name: enter one nonblank line, at most 60 characters."))
   (unless (and (string-match-p "\\`[0-9]+\\'" retries)
                (<= (length retries) 2) (<= (string-to-number retries) 10))
     '("Retries: enter a whole number from 0 through 10."))))

(defun emacs-tui-form-demo--apply ()
  "Apply the current form's valid draft explicitly."
  (interactive)
  (emacs-tui-act (emacs-tui-current-session) 'apply))

(defun emacs-tui-form-demo--revert ()
  "Restore the current form's last applied settings."
  (interactive)
  (emacs-tui-act (emacs-tui-current-session) 'revert))

(defun emacs-tui-form-demo--toggle ()
  "Toggle the current form's selected draft option."
  (interactive)
  (emacs-tui-act (emacs-tui-current-session) 'toggle))

;;;###autoload
(defun emacs-tui-form-demo ()
  "Open a persistent settings form with live validation and explicit Apply.
Edit Name and Retries with native Emacs commands.  In Options, SPC toggles
the selected checkbox.  `emacs-tui-form-demo--apply' applies a valid draft;
`emacs-tui-form-demo--revert' restores the last applied record.  Changed
fields reset undo; unchanged fields retain their undo history.
Closing discards session settings."
  (interactive)
  (let* ((options '((:id wrap :label "Wrap text" :checked t)
                    (:id numbers :label "Line numbers" :checked nil)))
         (applied (list :name "Local demo" :retries "3"
                        :options (copy-tree options)))
         (map (make-sparse-keymap)) (option-map (make-sparse-keymap))
         busy app)
    (define-key map (kbd "C-c C-c") #'emacs-tui-form-demo--apply)
    (define-key map (kbd "C-c C-r") #'emacs-tui-form-demo--revert)
    (define-key option-map (kbd "SPC") #'emacs-tui-form-demo--toggle)
    (cl-labels
        ((draft (session)
           (list :name (emacs-tui-input-value session 'name)
                 :retries (emacs-tui-input-value session 'retries)
                 :options (copy-tree options)))
         (errors (record)
           (emacs-tui-form-demo--errors (plist-get record :name)
                                       (plist-get record :retries)))
         (status (record saved)
           (let ((problems (errors record)))
             (concat
              (if problems (concat "Draft invalid\n" (string-join problems "\n"))
                (if (equal record saved) "Draft valid: no changes"
                  "Draft valid: unapplied changes"))
              "\n\nApplied settings (session only)\nName: " (plist-get saved :name)
              "\nRetries: " (plist-get saved :retries)
              "\nOptions: "
              (mapconcat (lambda (option)
                           (format "%s=%s" (plist-get option :label)
                                   (if (plist-get option :checked) "on" "off")))
                         (plist-get saved :options) ", ")
              "\n\nC-c C-c Apply | C-c C-r Revert | C-c C-q Close")))
         (refresh (session &rest _ignored)
           (emacs-tui-update session 'status :text (status (draft session) applied)))
         (apply-draft (session _items)
           (when busy (user-error "A form action is already publishing"))
           (let* ((record (draft session)) (problems (errors record)))
             (when problems (user-error "%s" (car problems)))
             (setq busy t)
             (unwind-protect
                 (progn
                   (emacs-tui-update session 'status :text (status record record))
                   (when (emacs-tui-live-p session)
                     (unless (equal record (draft session))
                       (refresh session)
                       (user-error "Draft changed during Apply; review it and apply again"))
                     (setq applied record)))
               (setq busy nil))))
         (revert-draft (session _items)
           (when busy (user-error "A form action is already publishing"))
           (setq busy t)
           (unwind-protect
               (progn
                 (emacs-tui-update session 'name :text (plist-get applied :name))
                 (emacs-tui-update session 'retries :text (plist-get applied :retries))
                 (emacs-tui-update session 'options :items (plist-get applied :options))
                 (setq options (copy-tree (plist-get applied :options)))
                 (refresh session))
             (setq busy nil)))
         (toggle (session items)
           (when busy (user-error "A form action is already publishing"))
           (let* ((id (plist-get (car items) :id)) (next (copy-tree options))
                  (option (cl-find id next :key (lambda (item) (plist-get item :id)))))
             (unless option (user-error "Select an option to toggle"))
             (setf (plist-get option :checked) (not (plist-get option :checked)))
             (setq busy t)
             (unwind-protect
                 (progn
                   (emacs-tui-update session 'options :items next)
                   (setq options next)
                   (refresh session))
               (setq busy nil)))))
      (let ((actions (list (emacs-tui-action :id 'apply :title "Apply valid draft"
                                            :run #'apply-draft)
                           (emacs-tui-action :id 'revert :title "Revert draft"
                                            :run #'revert-draft))))
        (unwind-protect
            (progn
              (setq app
                    (emacs-tui-mount
                     :layout 'grid :keymap map
                     :views
                     (list (emacs-tui-input :id 'name :title "Name" :value "Local demo"
                                            :on-change #'refresh :actions actions)
                           (emacs-tui-input :id 'retries :title "Retries (0–10)" :value "3"
                                            :on-change #'refresh :actions actions)
                           (emacs-tui-view
                            :id 'options :title "Options | SPC toggle" :items options
                            :keymap option-map
                            :columns
                            (list (emacs-tui-column
                                   :id 'choice :title "Option" :width 'fill
                                   :value (lambda (option)
                                            (format "[%s] %s"
                                                    (if (plist-get option :checked) "x" " ")
                                                    (plist-get option :label)))))
                            :actions (cons (emacs-tui-action :id 'toggle :title "Toggle option"
                                                            :run #'toggle) actions))
                           (emacs-tui-view :id 'status :title "Validation and applied record"
                                           :text "" :actions actions))))
              (refresh app)
              (prog1 app (setq app nil)))
          (when app (emacs-tui-close app)))))))

(provide 'emacs-tui-form-demo)
;;; emacs-tui-form-demo.el ends here
