;;; emacs-tui-title-test.el --- Live view metadata -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-title-test--with (views &rest body)
  "Mount VIEWS and evaluate BODY with session bound."
  (declare (indent 1) (debug t))
  `(save-window-excursion
     (let ((session (emacs-tui-mount :views ,views)))
       (unwind-protect (progn ,@body) (emacs-tui-close session)))))

(ert-deftest emacs-tui-title-only-keeps-table-content-and-projections ()
  (let (forbidden)
    (emacs-tui-title-test--with
        (list (emacs-tui-view :id 'rows :items '("alpha" "beta") :multi-select t
                              :columns (list (emacs-tui-column
                                              :id 'name :value (lambda (item)
                                                                (when forbidden (error "Projection")) item)))))
      (emacs-tui-set-query session 'rows "a")
      (emacs-tui-next-item session)
      (emacs-tui-toggle-mark session)
      (let* ((view (emacs-tui--focused-view session))
             (text (buffer-string)) (tick (buffer-modified-tick)) (pos (point))
             (overlay emacs-tui--selection-overlay))
        (setq forbidden t)
        (should (eq session (emacs-tui-update session 'rows :title "日本語 results")))
        (should (equal header-line-format "* 日本語 results | 1 marked"))
        (should (equal-including-properties text (buffer-string)))
        (should (= tick (buffer-modified-tick)))
        (should (= pos (point)))
        (should (eq overlay emacs-tui--selection-overlay))
        (should (equal "beta" (emacs-tui-current-item session)))
        (should (equal '("beta") (emacs-tui-marked-items session)))
        (should (equal "a" (emacs-tui-query session 'rows)))
        (should (equal "日本語 results" (emacs-tui--view-title view)))))))

(ert-deftest emacs-tui-title-only-preserves-field-undo-and-narrowing ()
  (let ((changes 0))
    (emacs-tui-title-test--with
        (list (emacs-tui-input :id 'field :value "hello"
                               :on-change (lambda (&rest _) (cl-incf changes))))
      (goto-char (point-max)) (insert "!") (undo-boundary)
      (narrow-to-region 2 5)
      (let ((undo buffer-undo-list) (pos (point)) (tick (buffer-modified-tick)))
        (emacs-tui-update session 'field :title "Editing")
        (should (eq undo buffer-undo-list))
        (should (buffer-narrowed-p))
        (should (= pos (point)))
        (should (= tick (buffer-modified-tick)))
        (should (= 1 changes))
        (widen) (undo-only 1)
        (should (equal "hello" (emacs-tui-input-value session 'field)))))))

(ert-deftest emacs-tui-title-combined-failure-retains-old-header-and-data ()
  (let (fail)
    (emacs-tui-title-test--with
        (list (emacs-tui-view :id 'rows :title "Old" :items '("alpha")
                              :columns (list (emacs-tui-column :id 'name
                                              :value (lambda (item)
                                                       (when fail (error "Projection")) item)))))
      (let ((header header-line-format) (text (buffer-string)))
        (setq fail t)
        (should-error (emacs-tui-update session 'rows :title "New" :items '("beta")))
        (should (equal "Old" (emacs-tui--view-title (emacs-tui--focused-view session))))
        (should (equal header header-line-format))
        (should (equal-including-properties text (buffer-string)))
        (should (equal "alpha" (emacs-tui-current-item session)))
        (setq fail nil)
        (emacs-tui-update session 'rows :title "New" :items '("beta"))
        (should (equal "* New" header-line-format))
        (should (equal "beta" (emacs-tui-current-item session)))))))

(ert-deftest emacs-tui-title-hidden-preview-survives-reveal ()
  (emacs-tui-title-test--with
      (list (emacs-tui-view :id 'rows :items '("a"))
            (emacs-tui-view :id 'preview :text "A long preview\nsecond line"))
    (emacs-tui-toggle-maximize session)
    (emacs-tui-update session 'preview :title "Preview ready")
    (should (eq 'rows (emacs-tui-current-view session)))
    (emacs-tui-focus-view session 'preview)
    (should (equal "* Preview ready | maximized" header-line-format))
    (emacs-tui-toggle-maximize session)
    (should (equal "* Preview ready" header-line-format))))

(ert-deftest emacs-tui-title-validates-before-changes-and-can-clear ()
  (emacs-tui-title-test--with (list (emacs-tui-view :id 'rows :title "Old" :items '("a")))
    (dolist (invalid '(nil 2 ("Title")))
      (should-error (emacs-tui-update session 'rows :title invalid :items '("b")))
      (should (equal "a" (emacs-tui-current-item session)))
      (should (equal "* Old" header-line-format)))
    (emacs-tui-update session 'rows :title "")
    (should (equal "* " header-line-format))
    (emacs-tui-update session 'rows :items '("b"))
    (should (equal "* " header-line-format))))

(ert-deftest emacs-tui-title-dashboard-displays-current-snapshot-counts-and-pause ()
  (load (expand-file-name "examples/emacs-tui-dashboard.el") nil t)
  (save-window-excursion
    (let ((session (emacs-tui-dashboard))
          (fixture (generate-new-buffer "*Live title fixture*")))
      (unwind-protect
          (progn
            (execute-kbd-macro (kbd "P g"))
            (dolist (entry '((buffers . "Buffers") (processes . "Processes")))
              (let ((view (emacs-tui--resolve-view session (car entry))))
                (should (equal (format "%s (%d)" (cdr entry)
                                       (length (emacs-tui--view-items view)))
                               (emacs-tui--view-title view)))))
            (should (cl-find fixture (emacs-tui--view-items
                                     (emacs-tui--resolve-view session 'buffers))
                             :key #'emacs-tui--item-id))
            (should (equal "Updates paused" (emacs-tui--view-title
                                              (emacs-tui--resolve-view session 'actions))))
            (execute-kbd-macro (kbd "P"))
            (should (equal "Updates running" (emacs-tui--view-title
                                               (emacs-tui--resolve-view session 'actions)))))
        (emacs-tui-close session)
        (kill-buffer fixture)))))
