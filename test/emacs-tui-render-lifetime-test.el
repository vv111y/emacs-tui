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

(defun emacs-tui-render-test--modification-buffer-switch (stage outcome &optional before global)
  "Switch buffers at render STAGE, then perform OUTCOME.
STAGE is zero for deletion and one for insertion.  OUTCOME is nil, error,
or close.  BEFORE selects before-change hooks; GLOBAL installs it globally.
Check foreign-buffer isolation and successful rendering or rollback."
  (save-window-excursion
    (delete-other-windows)
    (let ((foreign (generate-new-buffer " *render-hook-foreign*"))
          session buffer armed hook (calls 0)
          (hook-variable (if before 'before-change-functions 'after-change-functions)))
      (unwind-protect
          (progn
            (switch-to-buffer foreign)
            (insert "unrelated text")
            (goto-char 4)
            (setq-local header-line-format "foreign header")
            (set-buffer-modified-p nil)
            (setq session (emacs-tui-mount
                           :backend 'windows
                           :views (list (emacs-tui-view :id 'rows :items '("old")))))
            (setq buffer (emacs-tui--view-buffer
                          (car (emacs-tui--workspace-views session))))
            (setq hook (lambda (&rest _)
                         (when armed
                           (when (= calls stage)
                             (setq armed nil)
                             (when (eq outcome 'close) (emacs-tui-close session))
                             (set-buffer foreign)
                             (when (eq outcome 'error) (error "Hook failed")))
                           (cl-incf calls))))
            (with-current-buffer buffer
              (add-hook hook-variable hook nil (not global)))
            (setq armed t)
            (pcase outcome
              ('error
               (should (equal (should-error
                               (emacs-tui-update session 'rows :items '("new")))
                              '(error "Hook failed"))))
              ('close
               ;; Native change-group cleanup may report a deleted buffer.
               (should-error (emacs-tui-update session 'rows :items '("new"))))
              (_ (emacs-tui-update session 'rows :items '("new"))))
            (should-not armed)
            (if (eq outcome 'close)
                (should-not (emacs-tui-live-p session))
              (should (emacs-tui-live-p session))
              (should (equal (emacs-tui-current-item session)
                             (if outcome "old" "new")))
              (with-current-buffer buffer
                (should (equal (buffer-string) (if outcome "old\n" "new\n")))
                (should (equal header-line-format "* rows"))
                (should (eq (overlay-buffer emacs-tui--selection-overlay) buffer))
                (should (= (overlay-start emacs-tui--selection-overlay) 1))
                (should (= (overlay-end emacs-tui--selection-overlay) 4))))
            (with-current-buffer foreign
              (should (equal (buffer-string) "unrelated text"))
              (should (= (point) 4))
              (should (equal header-line-format "foreign header"))
              (should-not (buffer-modified-p))
              (should-not emacs-tui--row-ranges)
              (should-not (overlays-in (point-min) (point-max)))))
        (when global (remove-hook hook-variable hook))
        (when session (emacs-tui-close session))
        (when (buffer-live-p foreign) (kill-buffer foreign))))))

(ert-deftest emacs-tui-render-isolates-modification-buffer-switch ()
  (dolist (stage '(0 1))
    (emacs-tui-render-test--modification-buffer-switch stage nil)))

(ert-deftest emacs-tui-render-rolls-back-switching-modification-error ()
  (dolist (stage '(0 1))
    (emacs-tui-render-test--modification-buffer-switch stage 'error)))

(ert-deftest emacs-tui-render-rejects-modification-closing-session ()
  (dolist (stage '(0 1))
    (emacs-tui-render-test--modification-buffer-switch stage 'close)))

(ert-deftest emacs-tui-render-isolates-before-change-buffer-switch ()
  (dolist (stage '(0 1))
    (dolist (outcome '(nil error close))
      (emacs-tui-render-test--modification-buffer-switch stage outcome t))))

(ert-deftest emacs-tui-render-isolates-global-before-change-buffer-switch ()
  (dolist (stage '(0 1))
    (emacs-tui-render-test--modification-buffer-switch stage nil t t)))

(ert-deftest emacs-tui-render-restores-native-hook-lists ()
  (save-window-excursion
    (let ((session (emacs-tui-mount
                    :backend 'windows
                    :views (list (emacs-tui-view :id 'rows :items '("old")))))
          (calls 0))
      (unwind-protect
          (with-current-buffer
              (emacs-tui--view-buffer (car (emacs-tui--workspace-views session)))
            (let ((before-local (local-variable-p 'before-change-functions))
                  (before before-change-functions)
                  (after after-change-functions))
              (emacs-tui-update session 'rows :items '("new"))
              (should (eq before-local (local-variable-p 'before-change-functions)))
              (should (equal before before-change-functions))
              (should (equal after after-change-functions)))
            (let ((self-removing
                   (lambda (&rest _)
                     (cl-incf calls)
                     (setq before-change-functions nil))))
              (add-hook 'before-change-functions self-removing nil t)
              (emacs-tui-update session 'rows :items '("again"))
              (should (= calls 1))
              (should-not before-change-functions))
            (add-hook 'before-change-functions (lambda (&rest _) (error "Stop")) nil t)
            (should-error (emacs-tui-update session 'rows :items '("rejected")))
            (should-not before-change-functions))
        (emacs-tui-close session)))))

(ert-deftest emacs-tui-render-guards-replaced-before-change-hooks ()
  (save-window-excursion
    (let ((foreign (generate-new-buffer " *render-replacement-hook*")) session)
      (unwind-protect
          (progn
            (switch-to-buffer foreign)
            (insert "unrelated text")
            (setq session (emacs-tui-mount
                           :backend 'windows
                           :views (list (emacs-tui-view :id 'rows :items '("old")))))
            (with-current-buffer
                (emacs-tui--view-buffer (car (emacs-tui--workspace-views session)))
              (let ((replacement (lambda (&rest _) (set-buffer foreign))))
                (add-hook 'before-change-functions
                          (lambda (&rest _)
                            (setq before-change-functions (list replacement))) nil t)
                (emacs-tui-update session 'rows :items '("new"))
                (should (equal (buffer-string) "new\n"))
                (should (equal before-change-functions (list replacement)))))
            (with-current-buffer foreign
              (should (equal (buffer-string) "unrelated text"))))
        (when session (emacs-tui-close session))
        (kill-buffer foreign)))))

(provide 'emacs-tui-render-lifetime-test)
;;; emacs-tui-render-lifetime-test.el ends here
