;;; emacs-tui-layout-selection-test.el --- Named layouts -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Direct and interactive layout choices retain native editing and app policy.

;;; Code:
(require 'ert)
(require 'emacs-tui)
(declare-function emacs-tui-dashboard "emacs-tui-dashboard" ())

(defmacro emacs-tui-layout-selection-test--with (&rest body)
  "Mount input, list and preview as session, then execute BODY."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let ((calls 0) session)
       (unwind-protect
           (progn
             (setq session
                   (emacs-tui-mount
                    :views (list (emacs-tui-input :id 'body :value "original"
                                                 :on-change (lambda (&rest _) (cl-incf calls)))
                                 (emacs-tui-view :id 'items :items '("alpha" "beta") :multi-select t
                                                 :on-select (lambda (&rest _) (cl-incf calls)))
                                 (emacs-tui-view :id 'preview
                                                 :text (mapconcat #'number-to-string
                                                                  (number-sequence 1 100) "\n")))))
             ,@body)
         (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-layout-selection-preserves-input-query-marks-and-focus ()
  (emacs-tui-layout-selection-test--with
    (goto-char (point-max))
    (undo-boundary) (insert "!") (undo-boundary)
    (narrow-to-region 2 (point-max))
    (let ((position (point)) (undo (copy-tree buffer-undo-list))
          (tick (buffer-chars-modified-tick)) (expected-calls calls)
          (buffers (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session))))
      (emacs-tui-set-query session 'items "beta")
      (emacs-tui-mark-all session 'items)
      (emacs-tui-set-query session 'items "alpha")
      (dolist (layout '(rows grid columns))
        (should (eq session (emacs-tui-set-layout session layout)))
        (should (eq layout (emacs-tui--workspace-layout session)))
        (should (eq 'body (emacs-tui-current-view session)))
        (should (= position (point)))
        (should (= 2 (point-min)))
        (should (= tick (buffer-chars-modified-tick)))
        (should (equal undo buffer-undo-list))
        (should (= expected-calls calls))
        (should (equal "alpha" (emacs-tui-query session 'items)))
        (should (equal '("beta") (emacs-tui-marked-items session 'items)))
        (should (equal "alpha" (emacs-tui-current-item session 'items)))
        (should (equal buffers (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session)))))
      (widen) (undo-only 1)
      (should (equal "original" (emacs-tui-input-value session 'body))))))

(ert-deftest emacs-tui-layout-selection-unchanged-and-maximized-do-not-render ()
  (emacs-tui-layout-selection-test--with
    (let ((window (selected-window)))
      (cl-letf (((symbol-function 'emacs-tui-refresh) (lambda (&rest _) (ert-fail "Unexpected reflow")))
                ((symbol-function 'emacs-tui--render-view) (lambda (&rest _) (ert-fail "Unexpected render"))))
        (should (eq session (emacs-tui-set-layout session 'columns))))
      (should (eq window (selected-window))))
    (emacs-tui-focus-view session 'preview)
    (forward-line 50)
    (set-window-hscroll (selected-window) 3)
    (emacs-tui-toggle-maximize session)
    (let ((window (selected-window)) (position (point)))
      (cl-letf (((symbol-function 'emacs-tui-refresh) (lambda (&rest _) (ert-fail "Unexpected reflow"))))
        (should (eq session (emacs-tui-set-layout session 'rows))))
      (should (eq window (selected-window)))
      (should (= position (point)))
      (should (emacs-tui--workspace-maximized session))
      (emacs-tui-toggle-maximize session)
      (should (eq 'rows (emacs-tui--workspace-layout session)))
      (should (= position (point)))
      (should (= 3 (window-hscroll)))
      (let ((views (emacs-tui--workspace-views session)))
        (should (apply #'= (mapcar (lambda (view) (window-total-width (emacs-tui--view-window view))) views)))
        (should (< (nth 1 (window-edges (emacs-tui--view-window (car views))))
                   (nth 1 (window-edges (emacs-tui--view-window (cadr views))))))))))

(ert-deftest emacs-tui-layout-selection-rejects-invalid-values-without-mutation ()
  (emacs-tui-layout-selection-test--with
    (let ((window (selected-window)) (buffer (current-buffer)))
      (dolist (bad '(nil diagonal "grid" (rows)))
        (should-error (emacs-tui-set-layout session bad))
        (should (eq 'columns (emacs-tui--workspace-layout session)))
        (should (eq window (selected-window)))
        (should (eq buffer (current-buffer)))
        (should (emacs-tui-live-p session)))
      (emacs-tui-close session)
      (should-error (emacs-tui-set-layout session 'rows) :type 'user-error))))

(ert-deftest emacs-tui-layout-selection-rejects-foreign-surface-before-state-change ()
  (emacs-tui-layout-selection-test--with
    (let* ((root (emacs-tui--workspace-root session))
           (owned (window-buffer root))
           (foreign (generate-new-buffer " *layout-foreign*")))
      (unwind-protect
          (progn
            (with-current-buffer foreign (insert "foreign content"))
            (set-window-buffer root foreign) (set-window-point root 5)
            (should-error (emacs-tui-set-layout session 'rows) :type 'user-error)
            (should-error (emacs-tui-cycle-layout session) :type 'user-error)
            (should (eq 'columns (emacs-tui--workspace-layout session)))
            (should (eq foreign (window-buffer root)))
            (should (= 5 (window-point root)))
            (should (equal "foreign content" (with-current-buffer foreign (buffer-string)))))
        (set-window-buffer root owned)
        (kill-buffer foreign)))))

(ert-deftest emacs-tui-layout-selection-native-prefix-chooser-and-cancellation ()
  (emacs-tui-layout-selection-test--with
    (let ((prompts 0))
      (cl-letf (((symbol-function 'completing-read)
                 (lambda (&rest _) (cl-incf prompts) "grid")))
        (execute-kbd-macro (kbd "C-u C-c C-l")))
      (should (= 1 prompts))
      (should (eq 'grid (emacs-tui--workspace-layout session)))
      (execute-kbd-macro (kbd "C-c C-l"))
      (should (eq 'columns (emacs-tui--workspace-layout session)))
      (let (cancelled)
        (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) (signal 'quit nil))))
          (condition-case nil (call-interactively #'emacs-tui-set-layout)
            (quit (setq cancelled t))))
        (should cancelled)
        (should (eq 'columns (emacs-tui--workspace-layout session)))))))

(ert-deftest emacs-tui-layout-selection-revalidates-after-native-prompt ()
  (emacs-tui-layout-selection-test--with
    (cl-letf (((symbol-function 'completing-read)
               (lambda (&rest _) (emacs-tui-close session) "rows")))
      (should-error (call-interactively #'emacs-tui-set-layout) :type 'user-error))
    (should (eq 'columns (emacs-tui--workspace-layout session)))))

(ert-deftest emacs-tui-layout-selection-ephemeral-query-and-origin-remain-independent ()
  (save-window-excursion
    (delete-other-windows)
    (let ((host (generate-new-buffer " *layout-origin*")) (calls 0) session)
      (unwind-protect
          (progn
            (switch-to-buffer host) (insert "origin") (goto-char 4)
            (setq session
                  (emacs-tui-open
                   :backend 'windows
                   :views (list (emacs-tui-view :id 'items :items '("alpha" "beta"))
                                (emacs-tui-view :id 'preview :text "preview"))
                   :on-query (lambda (&rest _) (cl-incf calls))
                   :on-commit (lambda (&rest _) (ert-fail "Implicit commit"))))
            (execute-kbd-macro (kbd "a l p h a"))
            (let ((query (current-buffer)) (position (point)) (expected calls))
              (dolist (layout '(rows grid columns))
                (emacs-tui-set-layout session layout)
                (should (eq query (current-buffer)))
                (should (= position (point)))
                (should (equal "alpha" (emacs-tui-query session)))
                (should (= expected calls))
                (should (= 4 (marker-position (emacs-tui--workspace-origin session))))
                (should (equal "origin" (with-current-buffer host (buffer-string)))))))
        (when session (emacs-tui-close session))
        (kill-buffer host)))))

(ert-deftest emacs-tui-layout-selection-dashboard-actions-retain-paused-application ()
  (load (expand-file-name "examples/emacs-tui-dashboard.el") nil t)
  (save-window-excursion
    (delete-other-windows)
    (let ((session (emacs-tui-dashboard)))
      (unwind-protect
          (progn
            (emacs-tui-focus-view session 'actions)
            (execute-kbd-macro (kbd "P"))
            (let ((buffers (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session)))
                  (items (emacs-tui--view-items (emacs-tui--resolve-view session 'buffers))))
              (dolist (layout '(rows columns grid))
                (emacs-tui-set-selection session 'actions layout)
                (emacs-tui-select session)
                (should (eq layout (emacs-tui--workspace-layout session)))
                (should (emacs-tui-live-p session))
                (should (eq 'actions (emacs-tui-current-view session)))
                (should (equal "Updates paused" (emacs-tui--view-title (emacs-tui--resolve-view session 'actions))))
                (should (eq items (emacs-tui--view-items (emacs-tui--resolve-view session 'buffers))))
                (should (equal buffers (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session)))))))
        (emacs-tui-close session)))))

;;; emacs-tui-layout-selection-test.el ends here
