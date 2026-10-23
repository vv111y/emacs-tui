;;; emacs-tui-test.el --- Workspace regression tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Headless tests exercise real Emacs buffers and windows.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-test--workspace (options &rest body)
  "Open a workspace with OPTIONS, evaluate BODY, then release it."
  (declare (indent 1) (debug (form body)))
  `(save-window-excursion
     (delete-other-windows)
     (let ((source (generate-new-buffer " *tui-test-source*")) session)
       (unwind-protect
           (progn
             (switch-to-buffer source)
             (insert "unchanged source")
             (goto-char 6)
             (set-buffer-modified-p nil)
             (setq session (emacs-tui-open :backend 'windows ,@options))
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p source) (kill-buffer source))))))

(ert-deftest emacs-tui-cancel-preserves-source ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'results :items '("alpha" "beta"))))
    (insert "alp")
    (should (equal "alpha" (emacs-tui-current-item session)))
    (should (equal "alp" (emacs-tui-query session)))
    (emacs-tui-close session)
    (with-current-buffer source
      (should (equal "unchanged source" (buffer-string)))
      (should (= (point) 6))
      (should-not (buffer-modified-p)))
    (should (= 1 (length (window-list))))))

(ert-deftest emacs-tui-default-filter-is-literal-and-order-independent ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'results
                                    :items '("Alpha [graph] beta" "graph"))))
    (insert "BETA [")
    (should (equal "Alpha [graph] beta" (emacs-tui-current-item session)))))

(ert-deftest emacs-tui-independent-selection-and-view-focus ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a1" "a2"))
                    (emacs-tui-view :id 'b :items '("b1" "b2"))))
    (let ((query-window (selected-window)))
      (emacs-tui-next-item session)
      (emacs-tui-next-view session)
      (should (equal "b1" (emacs-tui-current-item session)))
      (emacs-tui-previous-view session)
      (should (equal "a2" (emacs-tui-current-item session)))
      (should (eq query-window (selected-window))))))

(ert-deftest emacs-tui-select-is-not-commit ()
  (let (selected committed)
    (emacs-tui-test--workspace
        (:views (list (emacs-tui-view
                       :id 'a :items '("a")
                       :on-select (lambda (_ item) (setq selected item))))
         :on-commit (lambda (&rest _) (setq committed t)))
      (emacs-tui-select session)
      (should (equal selected "a"))
      (should-not committed)
      (should (emacs-tui--workspace-active session)))))

(ert-deftest emacs-tui-explicit-commit-at-marker ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("INSERT")))
       :on-commit (lambda (_ item marker)
                    (goto-char marker) (insert item)))
    (with-current-buffer source (goto-char (point-min)) (insert "x"))
    (emacs-tui-commit session)
    (should-not (emacs-tui--workspace-active session))
    (with-current-buffer source
      (should (equal "xunchaINSERTnged source" (buffer-string))))))

(ert-deftest emacs-tui-failed-commit-rolls-back-and-keeps-session ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a")))
       :on-commit (lambda (&rest _) (insert "bad") (error "Failure")))
    (should-error (emacs-tui-commit session))
    (should (emacs-tui--workspace-active session))
    (with-current-buffer source
      (should (equal "unchanged source" (buffer-string))))))

(ert-deftest emacs-tui-update-retains-selection-by-id ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view
                     :id 'a :items '((:id 1 :label "one") (:id 2 :label "two")))))
    (emacs-tui-next-item session)
    (emacs-tui-update session 'a
                      :items '((:id 2 :label "changed") (:id 1 :label "one")))
    (should (= 2 (plist-get (emacs-tui-current-item session) :id)))
    (emacs-tui-update session 'a :items nil)
    (should-not (emacs-tui-current-item session))))

(ert-deftest emacs-tui-custom-query-results-are-not-filtered-again ()
  (let (queries)
    (emacs-tui-test--workspace
        (:views (list (emacs-tui-view :id 'a))
         :on-query (lambda (workspace query)
                     (push query queries)
                     (emacs-tui-update workspace 'a :items '("semantic match"))))
      (insert "different words")
      (should (equal queries '("different words" "")))
      (should (equal "semantic match" (emacs-tui-current-item session))))))

(ert-deftest emacs-tui-preview-text-is-read-only-and-clearable ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :text "preview" :items '("item"))))
    (let ((buffer (emacs-tui--view-buffer (car (emacs-tui--workspace-views session)))))
      (with-current-buffer buffer
        (should buffer-read-only)
        (should (equal "preview" (buffer-string))))
      (should-not (emacs-tui-current-item session))
      (emacs-tui-update session 'a :text nil)
      (should (equal "item" (emacs-tui-current-item session))))))

(ert-deftest emacs-tui-close-is-idempotent-and-releases-buffers ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a"))))
    (let ((buffers (cons (emacs-tui--workspace-query-buffer session)
                         (mapcar #'emacs-tui--view-buffer
                                 (emacs-tui--workspace-views session)))))
      (emacs-tui-close session)
      (emacs-tui-close session)
      (should-not (cl-some #'buffer-live-p buffers))
      (should-not (memq session emacs-tui--sessions))
      (should-not (marker-buffer (emacs-tui--workspace-origin session))))))

(ert-deftest emacs-tui-query-buffer-kill-closes-workspace ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a"))))
    (kill-buffer (emacs-tui--workspace-query-buffer session))
    (should-not (emacs-tui--workspace-active session))
    (should (= 1 (length (window-list))))))

(ert-deftest emacs-tui-origin-buffer-kill-closes-workspace ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a"))))
    (kill-buffer source)
    (should-not (emacs-tui--workspace-active session))))

(ert-deftest emacs-tui-layout-switch-reuses-buffers ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a"))
                    (emacs-tui-view :id 'b :text "b")))
    (let ((buffers (mapcar #'emacs-tui--view-buffer
                           (emacs-tui--workspace-views session))))
      (dotimes (_ 3) (emacs-tui-cycle-layout session))
      (should (equal buffers (mapcar #'emacs-tui--view-buffer
                                     (emacs-tui--workspace-views session))))
      (should (eq 'columns (emacs-tui--workspace-layout session))))))

(ert-deftest emacs-tui-invalid-open-does-not-allocate ()
  (let ((buffers (buffer-list)))
    (should-error (emacs-tui-open :views nil))
    (let ((view (emacs-tui-view :id 'same)))
      (should-error (emacs-tui-open :views (list view view))))
    (should (equal buffers (buffer-list)))))

(ert-deftest emacs-tui-no-child-frame-support-is-explicit ()
  (cl-letf (((symbol-function 'emacs-tui--child-frames-supported-p) (lambda () nil)))
    (let ((buffers (buffer-list)) (windows (window-list)))
      (should-error
       (emacs-tui-open :views (list (emacs-tui-view :id 'a))
                       :backend 'child-frame)
       :type 'user-error)
      (should (equal buffers (buffer-list)))
      (should (equal windows (window-list))))))

(ert-deftest emacs-tui-failed-initial-query-cleans-up ()
  (save-window-excursion
    (delete-other-windows)
    (let ((buffers (buffer-list)) (windows (window-list)))
      (should-error
       (emacs-tui-open :backend 'windows
                       :views (list (emacs-tui-view :id 'a))
                       :on-query (lambda (&rest _) (error "Provider failed"))))
      (should (equal buffers (buffer-list)))
      (should (equal windows (window-list)))
      (should-not emacs-tui--sessions))))

(ert-deftest emacs-tui-auto-falls-back-when-child-creation-fails ()
  (save-window-excursion
    (delete-other-windows)
    (let (session)
      (unwind-protect
          (cl-letf (((symbol-function 'emacs-tui--child-frames-supported-p)
                     (lambda () t))
                    ((symbol-function 'make-frame)
                     (lambda (&rest _) (error "Unsupported display"))))
            (setq session (emacs-tui-open
                           :views (list (emacs-tui-view :id 'a))))
            (should (eq 'windows (emacs-tui--workspace-backend session))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-close-preserves-new-unrelated-window ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a"))))
    (let* ((origin (emacs-tui--workspace-origin-window session))
           (other (split-window origin nil 'right)))
      (emacs-tui-close session)
      (should (window-live-p other))
      (should (window-live-p origin))
      (should (= 2 (length (window-list)))))))

(ert-deftest emacs-tui-partial-layout-failure-does-not-leak-windows ()
  (save-window-excursion
    (delete-other-windows)
    (let ((split (symbol-function 'split-window)) (calls 0) session)
      (unwind-protect
          (cl-letf (((symbol-function 'split-window)
                     (lambda (&rest args)
                       (cl-incf calls)
                       (if (= calls 4) (error "Injected split failure")
                         (apply split args)))))
            (setq session
                  (emacs-tui-open
                   :backend 'windows
                   :views (list (emacs-tui-view :id 'a)
                                (emacs-tui-view :id 'b)
                                (emacs-tui-view :id 'c)))))
        (when session (emacs-tui-close session)))
      (should (= 1 (length (window-list)))))))

(ert-deftest emacs-tui-initial-provider-quit-cleans-up ()
  (save-window-excursion
    (delete-other-windows)
    (let ((buffers (buffer-list)) (windows (window-list)) cancelled)
      (condition-case nil
          (emacs-tui-open :backend 'windows
                          :views (list (emacs-tui-view :id 'a))
                          :on-query (lambda (&rest _) (keyboard-quit)))
        (quit (setq cancelled t)))
      (should cancelled)
      (should (equal buffers (buffer-list)))
      (should (equal windows (window-list)))
      (should-not emacs-tui--sessions))))

(ert-deftest emacs-tui-provider-error-does-not-disable-query-refresh ()
  (let ((calls 0))
    (emacs-tui-test--workspace
        (:views (list (emacs-tui-view :id 'a))
         :on-query (lambda (workspace query)
                     (cl-incf calls)
                     (when (equal query "a") (error "Temporary provider failure"))
                     (emacs-tui-update workspace 'a :items (list query))))
      (insert "a")
      (should (memq #'emacs-tui--query-changed after-change-functions))
      (insert "b")
      (should (= calls 3))
      (should (equal "ab" (emacs-tui-current-item session))))))

(ert-deftest emacs-tui-hidden-view-is-shown-before-selection ()
  (emacs-tui-test--workspace
      (:layout 'rows
       :views (cl-loop for index below 30
                       collect (emacs-tui-view
                                :id (format "view-%s" index)
                                :items (list (format "item-%s" index)))))
    (emacs-tui-next-view session 29)
    (let* ((view (emacs-tui--focused-view session))
           (window (emacs-tui--view-window view)))
      (should (window-live-p window))
      (should (eq (window-buffer window) (emacs-tui--view-buffer view)))
      (should (equal "item-29" (emacs-tui-current-item session))))))

(ert-deftest emacs-tui-view-buffer-kill-closes-workspace ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a"))))
    (kill-buffer (emacs-tui--view-buffer (emacs-tui--focused-view session)))
    (should-not (emacs-tui--workspace-active session))
    (should (= 1 (length (window-list))))))

(ert-deftest emacs-tui-close-after-delete-other-windows-restores-source ()
  (emacs-tui-test--workspace
      (:views (list (emacs-tui-view :id 'a :items '("a"))))
    (delete-other-windows)
    (emacs-tui-close session)
    (should (eq source (window-buffer)))
    (should (= 6 (window-point)))
    (should-not (window-parameter nil 'emacs-tui-session))))

(ert-deftest emacs-tui-partial-child-frame-is-disposed-before-fallback ()
  (save-window-excursion
    (delete-other-windows)
    (let ((live (symbol-function 'frame-live-p))
          (root (symbol-function 'frame-root-window))
          (delete (symbol-function 'delete-frame))
          deleted session)
      (unwind-protect
          (cl-letf (((symbol-function 'emacs-tui--child-frames-supported-p)
                     (lambda () t))
                    ((symbol-function 'make-frame) (lambda (&rest _) 'fake-frame))
                    ((symbol-function 'frame-root-window)
                     (lambda (frame)
                       (if (eq frame 'fake-frame) (selected-window)
                         (funcall root frame))))
                    ((symbol-function 'make-frame-visible)
                     (lambda (&rest _) (error "Cannot show frame")))
                    ((symbol-function 'frame-live-p)
                     (lambda (frame)
                       (if (eq frame 'fake-frame) t (funcall live frame))))
                    ((symbol-function 'delete-frame)
                     (lambda (frame &optional force)
                       (if (eq frame 'fake-frame) (setq deleted t)
                         (funcall delete frame force)))))
            (setq session (emacs-tui-open :views (list (emacs-tui-view :id 'a))))
            (should deleted)
            (should (eq 'windows (emacs-tui--workspace-backend session)))
            (should-not (emacs-tui--workspace-frame session)))
        (when session (emacs-tui-close session))))))

(provide 'emacs-tui-test)
;;; emacs-tui-test.el ends here
