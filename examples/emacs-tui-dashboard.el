;;; emacs-tui-dashboard.el --- Persistent buffer and process dashboard -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Load this file and run M-x emacs-tui-dashboard.  This persistent application
;; has no query input or origin-buffer commit.  It displays buffers and processes,
;; previews selected objects and refreshes every second until closed or paused.
;; It does not edit buffers, start processes or terminate existing processes.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)

(defun emacs-tui-dashboard--buffers ()
  "Return items for visible-name live buffers."
  (cl-loop for buffer in (buffer-list)
           for name = (buffer-name buffer)
           unless (string-prefix-p " " name)
           collect (list :id buffer :label name :value buffer
                         :size (with-current-buffer buffer (buffer-size))
                         :mode (with-current-buffer buffer (symbol-name major-mode)))))

(defun emacs-tui-dashboard--processes ()
  "Return items for current processes."
  (mapcar (lambda (process)
            (list :id process :label (process-name process) :value process
                  :status (symbol-name (process-status process))
                  :command (mapconcat #'identity (process-command process) " ")))
          (process-list)))

(defun emacs-tui-dashboard--inspect-buffer (session item)
  "Display a bounded excerpt of ITEM's live buffer in SESSION."
  (let ((buffer (plist-get item :value)))
    (emacs-tui-update
     session 'preview
     :text (if (buffer-live-p buffer)
               (with-current-buffer buffer
                 (save-restriction
                   (widen)
                   (format "%s\n\n%s" (buffer-name)
                           (buffer-substring-no-properties
                            (point-min) (min (point-max) (+ (point-min) 1024))))))
             "This buffer has been killed; refresh the list."))))

(defun emacs-tui-dashboard--inspect-process (session item)
  "Display ITEM's process metadata in SESSION."
  (let ((process (plist-get item :value)))
    (emacs-tui-update session 'preview
                      :text (format "%s\nStatus: %s\nCommand: %S"
                                    (process-name process) (process-status process)
                                    (process-command process)))))

(defun emacs-tui-dashboard--process-buffer (items)
  "Return the named live buffer associated with a single process in ITEMS."
  (when (= (length items) 1)
    (let* ((process (plist-get (car items) :value))
           (buffer (and (processp process) (process-buffer process))))
      (when (and (buffer-live-p buffer)
                 (not (string-prefix-p " " (buffer-name buffer))))
        buffer))))

;;;###autoload
(defun emacs-tui-dashboard ()
  "Open a persistent dashboard of buffers and processes.
\\<emacs-tui-view-mode-map>\\[emacs-tui-next-view] changes view;
\\[emacs-tui-next-item]/\\[emacs-tui-previous-item] navigate items, and
\\[emacs-tui-select] inspects an object or invokes the selected action.
The Actions view refreshes or pauses/resumes updates without closing.
The g key refreshes and P pauses/resumes updates from any view.
In a table, s selects a sort column; a prefix argument sorts descending.
The process table's actions menu can inspect its associated buffer in the
Buffers view, clearing that view's local filter while retaining the dashboard
and all application buffer contents.
\\[emacs-tui-close] closes the interface and cancels its update timer."
  (interactive)
  (let ((keymap (make-sparse-keymap)) session timer paused initialized)
    (cl-labels
        ((refresh
           ()
           (when (emacs-tui-live-p session)
             (let ((buffers (emacs-tui-dashboard--buffers))
                   (processes (emacs-tui-dashboard--processes)))
               (emacs-tui-update session 'buffers :items buffers
                                 :title (format "Buffers (%d)" (length buffers)))
               (emacs-tui-update session 'processes :items processes
                                 :title (format "Processes (%d)" (length processes))))
             (emacs-tui-update
              session 'actions :title (if paused "Updates paused" "Updates running")
              :items (list '(:id refresh :label "Refresh now")
                           (list :id 'toggle :label (if paused "Resume updates" "Pause updates"))))))
         (tick
           ()
           (when (and (not paused) (emacs-tui-live-p session))
             (condition-case err (refresh)
               (error (message "emacs-tui dashboard: %s" (error-message-string err)))))))
      (define-key keymap (kbd "g") (lambda () (interactive) (refresh)))
      (define-key keymap (kbd "P")
                  (lambda () (interactive) (setq paused (not paused)) (refresh)))
      (unwind-protect
          (progn
            (setq session
                  (emacs-tui-mount
                   :layout 'grid
                   :keymap keymap
                   :views
                   (list
                    (emacs-tui-view :id 'buffers :title "Buffers"
                                    :columns
                                    (list (emacs-tui-column :id 'name :title "Buffer"
                                                            :width 24 :value :label)
                                          (emacs-tui-column :id 'size :title "Chars"
                                                            :width 9 :value :size :align 'right)
                                          (emacs-tui-column :id 'mode :title "Mode"
                                                            :width 20 :value :mode))
                                    :on-select #'emacs-tui-dashboard--inspect-buffer)
                    (emacs-tui-view :id 'processes :title "Processes"
                                    :actions
                                    (list
                                     (emacs-tui-action
                                      :id 'buffer :title "Inspect process buffer"
                                      :enabled (lambda (_app items)
                                                 (emacs-tui-dashboard--process-buffer items))
                                      :run (lambda (app items)
                                             (let ((buffer (emacs-tui-dashboard--process-buffer items)))
                                               (unless buffer (user-error "No associated named live buffer"))
                                               (refresh)
                                               (emacs-tui-set-query app 'buffers "")
                                               (emacs-tui-set-selection app 'buffers buffer)
                                               (emacs-tui-focus-view app 'buffers)
                                               (emacs-tui-select app)))))
                                    :columns
                                    (list (emacs-tui-column :id 'name :title "Process"
                                                            :width 20 :value :label)
                                          (emacs-tui-column :id 'status :title "Status"
                                                            :width 8 :value :status)
                                          (emacs-tui-column :id 'command :title "Command"
                                                            :width 30 :value :command))
                                    :on-select #'emacs-tui-dashboard--inspect-process)
                    (emacs-tui-view :id 'preview :title "Preview"
                                    :text "Select a buffer or process to inspect it.")
                    (emacs-tui-view
                     :id 'actions :title "Actions"
                     :on-select (lambda (_app item)
                                  (when (eq (plist-get item :id) 'toggle)
                                    (setq paused (not paused)))
                                  (refresh))))
                   :on-close (lambda (_app)
                               (when timer (cancel-timer timer) (setq timer nil)))))
            (refresh)
            (setq timer (run-at-time 1 1 #'tick)
                  initialized t)
            session)
        (unless initialized
          (when session (emacs-tui-close session)))))))

(provide 'emacs-tui-dashboard)
;;; emacs-tui-dashboard.el ends here
