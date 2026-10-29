;;; emacs-tui-render-lifetime-test.el --- Projection lifetime tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Application projections may yield or change the current buffer.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defun emacs-tui-render-test--buffer-switch (close)
  "Check isolation from a projection that switches buffers and optionally CLOSE."
  (progn
    (save-window-excursion
      (delete-other-windows)
      (let ((foreign (generate-new-buffer " *render-foreign*"))
            session armed)
        (unwind-protect
            (progn
              (switch-to-buffer foreign)
              (insert "unrelated text")
              (goto-char 4)
              (setq-local header-line-format "foreign header")
              (set-buffer-modified-p nil)
              (setq session
                    (emacs-tui-mount
                     :backend 'windows
                     :views
                     (list
                      (emacs-tui-view
                       :id 'rows :items '("old")
                       :columns
                       (list (emacs-tui-column
                              :id 'name :width 10
                              :value (lambda (item)
                                       (when armed
                                         (setq armed nil)
                                         (when close (emacs-tui-close session))
                                         (set-buffer foreign))
                                       item)))))))
              (setq armed t)
              (if close
                  (should-error (emacs-tui-update session 'rows :items '("new"))
                                :type 'user-error)
                (emacs-tui-update session 'rows :items '("new"))
                (should (equal "new" (emacs-tui-current-item session)))
                (with-current-buffer
                    (emacs-tui--view-buffer (car (emacs-tui--workspace-views session)))
                  (should (string-match-p "new" (buffer-string)))))
              (should (eq (not close) (not (null (emacs-tui-live-p session)))))
              (with-current-buffer foreign
                (should (equal "unrelated text" (buffer-string)))
                (should (= 4 (point)))
                (should (equal "foreign header" header-line-format))
                (should-not (buffer-modified-p))
                (should-not (overlays-in (point-min) (point-max)))))
          (when session (emacs-tui-close session))
          (when (buffer-live-p foreign) (kill-buffer foreign)))))))

(ert-deftest emacs-tui-render-isolates-projection-buffer-switch ()
  (emacs-tui-render-test--buffer-switch nil))

(ert-deftest emacs-tui-render-rejects-projection-closing-session ()
  (emacs-tui-render-test--buffer-switch t))

(provide 'emacs-tui-render-lifetime-test)
;;; emacs-tui-render-lifetime-test.el ends here
