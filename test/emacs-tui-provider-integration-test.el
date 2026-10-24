;;; emacs-tui-provider-integration-test.el --- Real async I/O tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise real debounce timers and process filters without mocking the event loop.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defun emacs-tui-test--await (predicate)
  "Allow asynchronous I/O until PREDICATE succeeds, with a five-second bound."
  (let ((deadline (+ (float-time) 5)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.01))
    (should (funcall predicate))))

(ert-deftest emacs-tui-provider-real-process-streaming-and-disposal ()
  (skip-unless (executable-find "cat"))
  (save-window-excursion
    (delete-other-windows)
    (let ((source (generate-new-buffer " *tui-process-source*"))
          session processes cancellations stale-publish)
      (unwind-protect
          (progn
            (switch-to-buffer source)
            (insert "origin:")
            (setq session
                  (emacs-tui-open
                   :backend 'windows :debounce 0.01
                   :views (list (emacs-tui-view :id 'results))
                   :provider
                   (lambda (_ query publish fail)
                     (let ((partial "") items process)
                       (unless stale-publish (setq stale-publish publish))
                       (setq process
                             (make-process
                              :name "emacs-tui-test-cat" :buffer nil
                              :command (list (executable-find "cat"))
                              :connection-type 'pipe :noquery t
                              :filter
                              (lambda (_process output)
                                (condition-case err
                                    (progn
                                      (setq partial (concat partial output))
                                      (while (string-match "\n" partial)
                                        (let ((end (match-beginning 0)))
                                          (setq items (append items (list (substring partial 0 end)))
                                                partial (substring partial (1+ end)))))
                                      (funcall publish 'results :items items))
                                  (error (funcall fail err))))))
                       (push process processes)
                       (process-send-string process (concat query "first\n"))
                       (lambda ()
                         (push process cancellations)
                         (when (process-live-p process) (delete-process process)))))
                   :on-commit (lambda (_ item marker) (goto-char marker) (insert item))))
            (emacs-tui-test--await
             (lambda () (equal (emacs-tui-current-item session) "first")))
            (with-current-buffer (emacs-tui--workspace-query-buffer session)
              (insert "new-"))
            (should-not (emacs-tui-current-item session))
            (should-not (process-live-p (car processes)))
            (should-not (funcall stale-publish 'results :items '("obsolete")))
            (emacs-tui-test--await
             (lambda () (equal (emacs-tui-current-item session) "new-first")))
            (process-send-string (car processes) "second\n")
            (emacs-tui-test--await
             (lambda ()
               (= 2 (length (emacs-tui--view-visible-items
                             (car (emacs-tui--workspace-views session)))))))
            (emacs-tui-next-item session)
            (should (equal (emacs-tui-current-item session) "second"))
            (should (equal (with-current-buffer source (buffer-string)) "origin:"))
            (emacs-tui-commit session)
            (should (equal (with-current-buffer source (buffer-string)) "origin:second"))
            (should (= 2 (length processes)))
            (should (= 2 (length cancellations)))
            (should-not (cl-some #'process-live-p processes)))
        (when session (emacs-tui-close session))
        (dolist (process processes)
          (when (process-live-p process) (delete-process process)))
        (when (buffer-live-p source) (kill-buffer source))))))

(provide 'emacs-tui-provider-integration-test)
;;; emacs-tui-provider-integration-test.el ends here
