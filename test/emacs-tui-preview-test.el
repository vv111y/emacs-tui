;;; emacs-tui-preview-test.el --- Preview position regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Repainting unchanged previews must not move the user's reading position.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-preview-test--session (&rest body)
  "Run BODY in a two-view application and release it."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let ((text (mapconcat (lambda (n) (format "Line %03d: content" n))
                            (number-sequence 1 200) "\n")) session)
       (unwind-protect
           (progn
             (setq session (emacs-tui-mount
                            :views (list (emacs-tui-view :id 'preview :text text)
                                         (emacs-tui-view :id 'items :items '("A")))))
             ,@body)
         (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-preview-focus-round-trip-preserves-reading-position ()
  (emacs-tui-preview-test--session
    (forward-line 70)
    (set-window-start (selected-window) (save-excursion (forward-line -5) (point)) t)
    (set-window-hscroll (selected-window) 3)
    (let ((position (point)) (start (window-start)) (tick (buffer-chars-modified-tick)))
      (emacs-tui-next-view session)
      (emacs-tui-previous-view session)
      (should (= position (point)))
      (should (= start (window-start)))
      (should (= 3 (window-hscroll)))
      (should (= tick (buffer-chars-modified-tick)))
      (should (string-prefix-p "* " header-line-format)))))

(ert-deftest emacs-tui-preview-identical-update-keeps-window-and-buffer-state ()
  (emacs-tui-preview-test--session
    (forward-line 60)
    (let ((position (point)) (tick (buffer-chars-modified-tick)) (changes 0))
      (add-hook 'after-change-functions (lambda (&rest _) (cl-incf changes)) nil t)
      (emacs-tui-update session 'preview :text (copy-sequence text))
      (should (= position (point)))
      (should (= tick (buffer-chars-modified-tick)))
      (should (= 0 changes)))))

(ert-deftest emacs-tui-preview-changed-text-starts-at-beginning ()
  (emacs-tui-preview-test--session
    (forward-line 60)
    (emacs-tui-update session 'preview :text "Different object")
    (should (= 1 (point)))
    (should (equal "Different object" (buffer-string)))))

(ert-deftest emacs-tui-preview-property-only-update-is-rendered ()
  (emacs-tui-preview-test--session
    (emacs-tui-update session 'preview :text (propertize text 'face 'bold))
    (should (eq 'bold (get-text-property 1 'face)))
    (forward-line 60)
    (let ((position (point)) (tick (buffer-chars-modified-tick)))
      (emacs-tui-update session 'preview :text (propertize (copy-sequence text) 'face 'bold))
      (should (= position (point)))
      (should (= tick (buffer-chars-modified-tick))))
    (emacs-tui-update session 'preview :text text)
    (should-not (get-text-property 1 'face))))

(ert-deftest emacs-tui-preview-reflow-preserves-reading-position ()
  (emacs-tui-preview-test--session
    (forward-line 60)
    (let ((position (point)))
      (emacs-tui-cycle-layout session)
      (should (= position (point))))))

(ert-deftest emacs-tui-preview-unchanged-text-preserves-narrowing ()
  (emacs-tui-preview-test--session
    (narrow-to-region 40 200)
    (goto-char 120)
    (emacs-tui-next-view session)
    (emacs-tui-previous-view session)
    (should (= 40 (point-min)))
    (should (= 200 (point-max)))
    (should (= 120 (point)))))

(provide 'emacs-tui-preview-test)
;;; emacs-tui-preview-test.el ends here
