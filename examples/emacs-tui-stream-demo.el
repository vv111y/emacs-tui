;;; emacs-tui-stream-demo.el --- Deterministic streaming search -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6-astra-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Synthetic job records arrive in small timer batches.  Type build, test or
;; deploy to supersede a search, or !error to demonstrate partial-result failure.
;; Edit the query again to recover.  No processes or network requests are made.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)

(defun emacs-tui-stream-demo--provider (_app query publish fail)
  "Stream synthetic records matching QUERY using PUBLISH and FAIL.
Return cancellation which releases the pending timer.  Every batch yields to
Emacs; obsolete publications are rejected by the toolkit."
  (let ((cursor 0) matches timer stopped)
    (cl-labels
        ((step
          ()
          (setq timer nil)
          (unless stopped
            (condition-case err
                (progn
                  (dotimes (_ 5)
                    (cl-incf cursor)
                    (let* ((kind (nth (mod (1- cursor) 3) '("build" "test" "deploy")))
                           (label (format "%s-%02d" kind cursor)))
                      (when (or (equal query "!error")
                                (let ((case-fold-search t))
                                  (string-match-p (regexp-quote query) label)))
                        (push (list :id cursor :label label :kind kind
                                    :seconds (+ 2 (mod (* cursor 7) 31))) matches))))
                  (if (and (funcall publish 'jobs :items (reverse matches))
                           (funcall publish 'progress :text
                                    (format "Scanned %d / 60 records\nMatches: %d\n\n%s"
                                            cursor (length matches)
                                            (if (= cursor 60) "Complete. Edit the query to start again."
                                              "Streaming... Keep typing; previous work is cancelled."))))
                      (cond
                       ((and (equal query "!error") (= cursor 15))
                        (funcall publish 'progress :text
                                 "Simulated failure after 15 records.\nPartial results remain inspectable.\nEdit or clear !error to recover.")
                        (setq stopped t)
                        (funcall fail "Demonstration failure; edit the query to retry"))
                       ((< cursor 60)
                        (setq timer (run-at-time 0.15 nil #'step))))
                    (setq stopped t)))
              (error (setq stopped t) (funcall fail err))))))
      (setq timer (run-at-time 0 nil #'step)))
    (lambda ()
      (setq stopped t)
      (when timer (cancel-timer timer) (setq timer nil)))))

;;;###autoload
(defun emacs-tui-stream-demo ()
  "Explore streaming, debouncing, cancellation and recovery with sample jobs.
Type build, test or deploy; !error produces a deliberate partial-result error.
There is no commit action and source buffers are never modified."
  (interactive)
  (emacs-tui-open
   :layout 'grid :provider #'emacs-tui-stream-demo--provider :debounce 0.15
   :views
   (list
    (emacs-tui-view
     :id 'jobs :title "Synthetic jobs | type build, test, deploy or !error"
     :multi-select t
     :columns (list (emacs-tui-column :id 'name :title "Job" :width 'fill :value :label)
                    (emacs-tui-column :id 'seconds :title "Seconds" :width 8 :value :seconds :align 'right))
     :on-select (lambda (app item)
                  (emacs-tui-update app 'preview :text
                                    (format "Job: %s\nKind: %s\nDuration: %d seconds\n\nSynthetic data; no job is executed."
                                            (plist-get item :label) (plist-get item :kind)
                                            (plist-get item :seconds)))))
    (emacs-tui-view :id 'progress :title "Provider progress" :text "Waiting for the first batch...")
    (emacs-tui-view :id 'preview :title "Inspection | RET on a job"
                    :text "Type to replace the request while it streams.\nTry !error, inspect partial results, then clear the query.\nC-c C-q closes and cancels outstanding work."))))

(provide 'emacs-tui-stream-demo)
;;; emacs-tui-stream-demo.el ends here
