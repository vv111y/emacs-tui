;;; emacs-tui-async-demo.el --- Cancellable buffer search demo -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Load this file and run M-x emacs-tui-async-demo.  Search uses snapshots of
;; buffer names and the first 1024 characters, processing at most 16 buffers
;; per timer tick.  RET previews a snapshot; no source buffer is modified.

;;; Code:

(require 'cl-lib)
(require 'emacs-tui)

(defun emacs-tui-async-demo--snapshots ()
  "Return search items containing current buffer names and excerpts."
  (cl-loop for buffer in (buffer-list)
           for name = (buffer-name buffer)
           unless (string-prefix-p " " name)
           collect
           (with-current-buffer buffer
             (save-restriction
               (widen)
               (list :id name :label name
                     :annotation (format "%d chars" (buffer-size))
                     :value (buffer-substring-no-properties
                             (point-min) (min (point-max)
                                              (+ (point-min) 1024))))))))

(defun emacs-tui-async-demo--provider (snapshots)
  "Return a cancellable search provider over SNAPSHOTS."
  (lambda (_session query publish fail)
    (let ((remaining snapshots)
          (pattern (regexp-quote query))
          matches timer cancelled)
      (cl-labels
          ((step
            ()
            (setq timer nil)
            (unless cancelled
              (condition-case err
                  (let ((case-fold-search t))
                    (dotimes (_ 16)
                      (when remaining
                        (let ((item (pop remaining)))
                          (when (or (string-match-p pattern (plist-get item :label))
                                    (string-match-p pattern (plist-get item :value)))
                            (push item matches)))))
                    (when (and (funcall publish 'buffers :items (reverse matches))
                               remaining (not cancelled))
                      (setq timer (run-at-time 0.01 nil #'step))))
                (error (setq cancelled t)
                       (funcall fail err))))))
        (setq timer (run-at-time 0 nil #'step)))
      (lambda ()
        (setq cancelled t)
        (when (timerp timer)
          (cancel-timer timer)
          (setq timer nil))))))

;;;###autoload
(defun emacs-tui-async-demo ()
  "Search snapshots of current buffer names and initial text.
Results arrive in batches while the query remains editable.  Changing
the query cancels the previous search.
\\<emacs-tui-input-mode-map>\\[emacs-tui-select] previews a captured excerpt;
\\[emacs-tui-close] closes the workspace.  This demo does not modify source buffers."
  (interactive)
  (let ((snapshots (emacs-tui-async-demo--snapshots)))
    (emacs-tui-open
     :debounce 0.08
     :provider (emacs-tui-async-demo--provider snapshots)
     :views
     (list
      (emacs-tui-view
       :id 'buffers :title "Buffer snapshots"
       :on-select
       (lambda (session item)
         (emacs-tui-update
          session 'preview
          :text (format "%s\n\n%s" (plist-get item :label)
                        (plist-get item :value)))))
      (emacs-tui-view
       :id 'preview :title "Captured excerpt"
       :text "Search buffer names and their first 1024 characters.\nRET previews a snapshot.")))))

(provide 'emacs-tui-async-demo)
;;; emacs-tui-async-demo.el ends here
