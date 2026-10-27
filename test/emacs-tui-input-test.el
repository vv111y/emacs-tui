;;; emacs-tui-input-test.el --- Editable view behavior -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise native editing, callbacks, undo, focus and resource ownership.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(ert-deftest emacs-tui-input-suppressed-edit-survives-focus-navigation ()
  (save-window-excursion
    (let* ((app (emacs-tui-mount
                 :views (list (emacs-tui-input :id 'input :value "A")
                              (emacs-tui-view :id 'other :items '("Other")))))
           (input (current-buffer)))
      (unwind-protect
          (progn
            (let ((inhibit-modification-hooks t)) (goto-char (point-max)) (insert "B"))
            (let ((undo (copy-tree buffer-undo-list)) (position (point)))
              (emacs-tui-focus-view app 'other)
              (emacs-tui-previous-view app)
              (should (eq input (current-buffer)))
              (should (equal "AB" (emacs-tui-input-value app 'input)))
              (should (equal undo buffer-undo-list))
              (should (= position (point)))))
        (emacs-tui-close app)))))

(ert-deftest emacs-tui-input-render-hook-edit-survives-same-reflow ()
  (save-window-excursion
    (let* ((app (emacs-tui-mount
                 :views (list (emacs-tui-view :id 'items :items '("Item"))
                              (emacs-tui-input :id 'input :value "A"))))
           input entered)
      (unwind-protect
          (progn
            (emacs-tui-focus-view app 'input)
            (setq input (current-buffer))
            (emacs-tui-focus-view app 'items)
            (let ((hook (lambda (&rest _)
                          (unless entered
                            (setq entered t)
                            (with-current-buffer input
                              (goto-char (point-max)) (insert "B"))))))
              (add-hook 'before-change-functions hook nil t)
              (unwind-protect (emacs-tui-refresh app)
                (remove-hook 'before-change-functions hook t)))
            (should entered)
            ;; The earlier pane's hook edits the input after reflow begins.
            (should (equal "AB" (emacs-tui-input-value app 'input))))
        (emacs-tui-close app)))))

(ert-deftest emacs-tui-input-cross-buffer-hook-edit-survives-reflow ()
  (let ((calls 0) entered input)
    (save-window-excursion
      (let ((app (emacs-tui-mount
                  :views (list (emacs-tui-input :id 'input :value "A"
                                               :on-change (lambda (&rest _) (cl-incf calls)))
                               (emacs-tui-view :id 'preview :text "Old")))))
        (unwind-protect
            (progn
              (setq input (current-buffer))
              (emacs-tui-focus-view app 'preview)
              (let ((hook (lambda (&rest _)
                            (unless entered
                              (setq entered t)
                              (with-current-buffer input
                                (goto-char (point-max))
                                (insert (propertize "日本語" 'face 'bold)))))))
                (add-hook 'before-change-functions hook nil t)
                (unwind-protect (emacs-tui-update app 'preview :text "New")
                  (remove-hook 'before-change-functions hook t)))
              (should (equal "A日本語" (emacs-tui-input-value app 'input)))
              (let ((undo (with-current-buffer input (copy-tree buffer-undo-list))))
                (emacs-tui-set-layout app 'rows)
                (should (equal "A日本語" (emacs-tui-input-value app 'input)))
                (with-current-buffer input
                  (should (equal undo buffer-undo-list))
                  (should (eq 'bold (get-text-property 2 'face)))))
              ;; The originating native hook inhibited nested change hooks.
              ;; Reflow must preserve its edit without inventing a callback.
              (should (= 0 calls)))
          (emacs-tui-close app))))))

(ert-deftest emacs-tui-input-suppressed-edit-survives-quiet-update ()
  (save-window-excursion
    (let ((app (emacs-tui-mount :views (list (emacs-tui-input :id 'input :value "A")))))
      (unwind-protect
          (progn
            (let ((inhibit-modification-hooks t)) (goto-char (point-max)) (insert "B"))
            (narrow-to-region 2 3)
            (let ((undo (copy-tree buffer-undo-list)))
              (emacs-tui-update app 'input :title "Updated title")
              (emacs-tui-update app 'input)
              (should (equal "AB" (emacs-tui-input-value app 'input)))
              (should (equal undo buffer-undo-list))
              (should (= 2 (point-min))))
            ;; An explicit replacement still wins and resets undo normally.
            (emacs-tui-update app 'input :text "Replacement")
            (should (equal "Replacement" (emacs-tui-input-value app 'input)))
            (should-not buffer-undo-list))
        (emacs-tui-close app)))))

(ert-deftest emacs-tui-input-hidden-suppressed-edit-survives-layout ()
  (save-window-excursion
    (let* ((app (emacs-tui-mount
                 :views (list (emacs-tui-input :id 'input :value "A")
                              (emacs-tui-view :id 'other :items '("Other")))))
           (input (current-buffer)))
      (unwind-protect
          (progn
            (emacs-tui-focus-view app 'other)
            (emacs-tui-toggle-maximize app)
            (with-current-buffer input
              (let ((inhibit-modification-hooks t)) (goto-char (point-max)) (insert "B")))
            (emacs-tui-refresh app)
            (emacs-tui-toggle-maximize app)
            (emacs-tui-focus-view app 'input)
            (should (equal "AB" (emacs-tui-input-value app 'input))))
        (emacs-tui-close app)))))

(defmacro emacs-tui-input-test--with (views &rest body)
  "Mount VIEWS as session, run BODY and release owned resources."
  (declare (indent 1) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let (session)
       (unwind-protect
           (progn (setq session (emacs-tui-mount :views ,views)) ,@body)
         (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-input-native-editing-and-unicode ()
  (emacs-tui-input-test--with (list (emacs-tui-input :id 'body))
    (should-not buffer-read-only)
    (should (derived-mode-p 'text-mode))
    (execute-kbd-macro (kbd "n p q s RET"))
    (insert "日本語 é")
    (should (equal "npqs\n日本語 é" (emacs-tui-input-value session 'body)))
    (should (emacs-tui-live-p session))
    (should-not (emacs-tui-current-item session))))

(ert-deftest emacs-tui-input-edit-callback-receives-current-full-value ()
  (let (calls)
    (emacs-tui-input-test--with
        (list (emacs-tui-input :id 'body :value "abcd"
                              :on-change (lambda (app id value)
                                           (push (list app id value) calls))))
      (should-not calls)
      (narrow-to-region 2 4)
      (goto-char 3)
      (insert "X")
      (should (equal (car calls) (list session 'body "abXcd")))
      (should (equal "abXcd" (emacs-tui-input-value session 'body)))
      (should (= 2 (point-min))))))

(ert-deftest emacs-tui-input-native-undo-updates-application ()
  (let (values)
    (emacs-tui-input-test--with
        (list (emacs-tui-input :id 'body :value "A"
                              :on-change (lambda (_app _id value) (push value values))))
      (goto-char (point-max))
      (insert "B")
      (undo-boundary)
      (undo-only 1)
      (should (equal "A" (emacs-tui-input-value session 'body)))
      (should (equal "A" (car values))))))

(ert-deftest emacs-tui-input-focus-and-reflow-preserve-edit-state ()
  (let ((calls 0))
    (emacs-tui-input-test--with
        (list (emacs-tui-input :id 'body :value "initial"
                              :on-change (lambda (&rest _) (cl-incf calls)))
              (emacs-tui-view :id 'other :items '("a")))
      (goto-char 3)
      (insert "x")
      (let ((position (point)) (undo (copy-tree buffer-undo-list))
            (tick (buffer-chars-modified-tick)))
        (emacs-tui-next-view session)
        (emacs-tui-previous-view session)
        (emacs-tui-cycle-layout session)
        (should (= position (point)))
        (should (= tick (buffer-chars-modified-tick)))
        (should (equal undo buffer-undo-list))
        (should (= calls 1))))))

(ert-deftest emacs-tui-input-programmatic-updates-are-quiet-and-reset-undo ()
  (let ((calls 0))
    (emacs-tui-input-test--with
        (list (emacs-tui-input :id 'body :on-change (lambda (&rest _) (cl-incf calls))))
      (insert "edited")
      (should buffer-undo-list)
      (emacs-tui-update session 'body :text "replacement")
      (should (equal "replacement" (emacs-tui-input-value session 'body)))
      (should (= 1 calls))
      (should-not buffer-undo-list)
      (should (= 1 (point)))
      (insert "x")
      (let ((undo (copy-tree buffer-undo-list)) (position (point)))
        (emacs-tui-update session 'body :text "xreplacement")
        (should (equal undo buffer-undo-list))
        (should (= position (point)))))))

(ert-deftest emacs-tui-input-callback-may-update-preview ()
  (emacs-tui-input-test--with
      (list (emacs-tui-input :id 'body
                            :on-change (lambda (app _id value)
                                         (emacs-tui-update app 'preview :text (upcase value))))
            (emacs-tui-view :id 'preview :text ""))
    (insert "hello")
    (emacs-tui-next-view session)
    (should (equal "HELLO" (buffer-string)))
    (emacs-tui-previous-view session)
    (should (equal "hello" (emacs-tui-input-value session)))))

(ert-deftest emacs-tui-input-callback-errors-preserve-edit-and-recover ()
  (let ((calls 0))
    (emacs-tui-input-test--with
        (list (emacs-tui-input :id 'body :on-change
                              (lambda (&rest _) (cl-incf calls) (error "Application failed"))))
      (insert "a")
      (insert "b")
      (should (= calls 2))
      (should (equal "ab" (emacs-tui-input-value session)))
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-input-callback-can-close ()
  (emacs-tui-input-test--with
      (list (emacs-tui-input :id 'body :on-change
                            (lambda (app &rest _) (emacs-tui-close app))))
    (insert "done")
    (should-not (emacs-tui-live-p session))))

(ert-deftest emacs-tui-input-callback-can-normalize-without-recursion ()
  (let ((calls 0))
    (emacs-tui-input-test--with
        (list (emacs-tui-input :id 'body :on-change
                              (lambda (app id value)
                                (cl-incf calls)
                                (emacs-tui-update app id :text (upcase value)))))
      (insert "hello")
      (should (= 1 calls))
      (should (equal "HELLO" (emacs-tui-input-value session)))
      (should-not buffer-undo-list))))

(ert-deftest emacs-tui-input-narrowed-field-survives-focus-and-refresh ()
  (emacs-tui-input-test--with
      (list (emacs-tui-input :id 'body :value "abcdef")
            (emacs-tui-view :id 'preview :text "other"))
    (narrow-to-region 2 5)
    (goto-char 3)
    (insert "x")
    (emacs-tui-next-view session)
    (emacs-tui-previous-view session)
    (emacs-tui-refresh session)
    (should (= 2 (point-min)))
    (should (= 6 (point-max)))
    (should (= 4 (point)))
    (should (equal "abxcdef" (emacs-tui-input-value session)))))

(ert-deftest emacs-tui-input-invalid-updates-preserve-edit ()
  (emacs-tui-input-test--with (list (emacs-tui-input :id 'body :value "kept"))
    (should-error (emacs-tui-update session 'body :text nil))
    (should-error (emacs-tui-update session 'body :items nil))
    (should (equal "kept" (emacs-tui-input-value session)))))

(ert-deftest emacs-tui-input-descriptor-and-lifecycle-validation ()
  (should-error (emacs-tui-input :id 'body :value nil))
  (should-error (emacs-tui-input :id 'body :on-change 'not-a-function))
  (should-error (emacs-tui-open :views (list (emacs-tui-input :id 'body))))
  (emacs-tui-input-test--with (list (emacs-tui-view :id 'list :items '("x")))
    (should-error (emacs-tui-input-value session))))

(ert-deftest emacs-tui-input-description-can-be-reused ()
  (let ((description (emacs-tui-input :id 'body :value "original")) other)
    (emacs-tui-input-test--with (list description)
      (unwind-protect
          (progn
            (insert "one")
            (setq other (emacs-tui-mount :views (list description)))
            (should (equal "original" (emacs-tui-input-value other)))
            (should (equal "oneoriginal" (emacs-tui-input-value session)))
            (should (equal "original" (emacs-tui--view-text description))))
        (when other (emacs-tui-close other))))))

(ert-deftest emacs-tui-input-embedding-restores-unmodified-host ()
  (save-window-excursion
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert "host")
      (goto-char 2)
      (let ((host (current-buffer)) session input)
        (unwind-protect
            (progn
              (setq session (emacs-tui-embed :view (emacs-tui-input :id 'body))
                    input (current-buffer))
              (insert "scratch edits")
              (emacs-tui-close session)
              (should (eq host (window-buffer)))
              (should (equal "host" (with-current-buffer host (buffer-string))))
              (should (= 2 (window-point)))
              (should-not (buffer-live-p input)))
          (when session (emacs-tui-close session)))))))

(ert-deftest emacs-tui-input-application-keymap-preserves-native-keys ()
  (let ((map (make-sparse-keymap)) (count 0))
    (define-key map (kbd "C-c C-c") (lambda () (interactive) (cl-incf count)))
    (emacs-tui-input-test--with (list (emacs-tui-input :id 'body :keymap map))
      (execute-kbd-macro (kbd "a RET b C-c C-c"))
      (should (= 1 count))
      (should (equal "a\nb" (emacs-tui-input-value session))))))

(ert-deftest emacs-tui-input-composer-keeps-copy-explicit ()
  (load (expand-file-name "../examples/emacs-tui-composer.el"
                          (file-name-directory (or load-file-name
                                                   (locate-library "emacs-tui-input-test")))))
  (save-window-excursion
    (delete-other-windows)
    (let ((kill-ring nil) session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-composer))
            (should-not kill-ring)
            (emacs-tui-next-view session)
            (emacs-tui-update session 'body :text "a\nb")
            (emacs-tui-composer-copy)
            (should (equal "* a\n* b" (car kill-ring)))
            (should (emacs-tui-live-p session)))
        (when session (emacs-tui-close session))))))

(provide 'emacs-tui-input-test)
;;; emacs-tui-input-test.el ends here
