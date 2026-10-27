;;; emacs-tui-inspector-test.el --- Object inspector application policies -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Model popup presentation only; real source editing and application actions
;; run here. Native scrolling and anchored display have a separate PTY fixture.

;;; Code:
(require 'ert)
(require 'cl-lib)
(require 'emacs-tui-inspector-demo
         (expand-file-name "../examples/emacs-tui-inspector-demo.el"
                           (file-name-directory (or load-file-name buffer-file-name))))

(defmacro emacs-tui-inspector-test--source (&rest body)
  "Run BODY in a disposable source with modeled popup creation and closure."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (let ((source (generate-new-buffer " *inspector source*")) callbacks)
       (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) t))
                 ((symbol-function 'emacs-tui-popup)
                  (lambda (&rest options)
                    (let ((app (emacs-tui--make-workspace
                                :active t :views (list (plist-get options :view)))))
                      (push (cons app (plist-get options :on-close)) callbacks)
                      app)))
                 ((symbol-function 'emacs-tui-update)
                  (lambda (app _id &rest options)
                    (setf (emacs-tui--view-text (car (emacs-tui--workspace-views app)))
                          (plist-get options :text))))
                 ((symbol-function 'emacs-tui-close)
                  (lambda (app)
                    (when (emacs-tui-live-p app)
                      (setf (emacs-tui--workspace-active app) nil)
                      (funcall (cdr (assq app callbacks)) app)))))
         (unwind-protect
             (progn (switch-to-buffer source) (insert "pump valve") (goto-char 3) ,@body)
           (when (buffer-live-p source)
             (with-current-buffer source (emacs-tui-inspector-demo-dismiss))
             (kill-buffer source)))))))

(ert-deftest emacs-tui-inspector-actions-are-explicit-and-source-preserving ()
  (emacs-tui-inspector-test--source
    (let ((text (buffer-string)) (point (point)) (undo buffer-undo-list))
      (emacs-tui-inspector-demo-at-point)
      (let ((app emacs-tui-inspector-demo--session))
        (should-not (gethash "pump" emacs-tui-inspector-demo--acknowledged))
        (should (eq (key-binding (kbd "C-c C-a")) #'emacs-tui-inspector-demo-acknowledge))
        (emacs-tui-inspector-demo-acknowledge)
        (should (gethash "pump" emacs-tui-inspector-demo--acknowledged))
        (should (emacs-tui-live-p app))
        (should (string-match-p "Acknowledged: yes"
                                (emacs-tui--view-text (car (emacs-tui--workspace-views app)))))
        (emacs-tui-inspector-demo-dismiss)
        (should-not emacs-tui-inspector-demo--active)
        (should-not (eq (key-binding (kbd "C-c C-a")) #'emacs-tui-inspector-demo-acknowledge))
        (emacs-tui-inspector-demo-at-point)
        (should (gethash "pump" emacs-tui-inspector-demo--acknowledged))
        (emacs-tui-inspector-demo-acknowledge)
        (should-not (gethash "pump" emacs-tui-inspector-demo--acknowledged)))
      (should (equal text (buffer-string))) (should (= point (point)))
      (should (equal undo buffer-undo-list)))))

(ert-deftest emacs-tui-inspector-objects-and-source-buffers-have-independent-state ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (emacs-tui-inspector-demo-acknowledge)
    (goto-char (point-max))
    (emacs-tui-inspector-demo-at-point)
    (should (equal "valve" (car emacs-tui-inspector-demo--object)))
    (should-not (gethash "valve" emacs-tui-inspector-demo--acknowledged))
    (let ((first emacs-tui-inspector-demo--acknowledged))
      (emacs-tui-inspector-test--source
        (emacs-tui-inspector-demo-at-point)
        (should-not (eq first emacs-tui-inspector-demo--acknowledged))
        (should-not (gethash "pump" emacs-tui-inspector-demo--acknowledged))))))

(ert-deftest emacs-tui-inspector-render-failure-does-not-acknowledge ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (cl-letf (((symbol-function 'emacs-tui-update) (lambda (&rest _) (error "Render failed"))))
      (should-error (emacs-tui-inspector-demo-acknowledge)))
    (should-not (gethash "pump" emacs-tui-inspector-demo--acknowledged))
    (emacs-tui-inspector-demo-acknowledge)
    (should (gethash "pump" emacs-tui-inspector-demo--acknowledged))))

(ert-deftest emacs-tui-inspector-close-during-render-does-not-acknowledge ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (let ((table emacs-tui-inspector-demo--acknowledged))
      (cl-letf (((symbol-function 'emacs-tui-update)
                 (lambda (app &rest _) (emacs-tui-close app))))
        (should-error (emacs-tui-inspector-demo-acknowledge) :type 'user-error))
      (should-not (gethash "pump" table))
      (should-not emacs-tui-inspector-demo--active))))

(ert-deftest emacs-tui-inspector-major-mode-and-early-close-release-bindings ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (let ((app emacs-tui-inspector-demo--session))
      (text-mode)
      (should-not (emacs-tui-live-p app))
      (should-not emacs-tui-inspector-demo--active))
    (let ((create (symbol-function 'emacs-tui-popup)))
      (cl-letf (((symbol-function 'emacs-tui-popup)
                 (lambda (&rest args)
                   (let ((app (apply create args))) (emacs-tui-close app) app))))
        (should-error (emacs-tui-inspector-demo-at-point) :type 'user-error))
      (should-not emacs-tui-inspector-demo--active)
      (should-not emacs-tui-inspector-demo--session))))

(ert-deftest emacs-tui-inspector-reentrant-creation-preserves-new-owner ()
  (dolist (reset-mode '(nil t))
   (emacs-tui-inspector-test--source
    (let ((create (symbol-function 'emacs-tui-popup)) old inner entering)
      (cl-letf (((symbol-function 'emacs-tui-popup)
                 (lambda (&rest args)
                   (let ((app (apply create args)))
                     (unless entering
                       (setq old app entering t)
                       (when reset-mode (text-mode))
                       (setq inner (emacs-tui-inspector-demo-at-point)))
                     app))))
        (should-error (emacs-tui-inspector-demo-at-point) :type 'user-error))
      (should-not (emacs-tui-live-p old))
      (should (emacs-tui-live-p inner))
      (should (eq inner emacs-tui-inspector-demo--session))
      (should emacs-tui-inspector-demo--active)))))

(ert-deftest emacs-tui-inspector-close-reentry-preserves-new-owner ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (let ((close (symbol-function 'emacs-tui-close))
          (old emacs-tui-inspector-demo--session) inner entering)
      (cl-letf (((symbol-function 'emacs-tui-close)
                 (lambda (app)
                   (funcall close app)
                   (unless entering
                     (setq entering t)
                     (setq inner (emacs-tui-inspector-demo-at-point))))))
        (should-error (emacs-tui-inspector-demo-at-point) :type 'user-error))
      (should-not (emacs-tui-live-p old))
      (should (emacs-tui-live-p inner))
      (should (eq inner emacs-tui-inspector-demo--session))
      (should (= 1 (cl-count-if (lambda (entry) (emacs-tui-live-p (car entry))) callbacks))))))

(ert-deftest emacs-tui-inspector-source-edit-during-creation-is-preserved ()
  (emacs-tui-inspector-test--source
    (let ((create (symbol-function 'emacs-tui-popup)))
      (cl-letf (((symbol-function 'emacs-tui-popup)
                 (lambda (&rest args) (prog1 (apply create args) (insert "x")))))
        (should-error (emacs-tui-inspector-demo-at-point) :type 'user-error))
      (should (equal "puxmp valve" (buffer-string)))
      (should-not emacs-tui-inspector-demo--active)
      (should (cl-every (lambda (entry) (not (emacs-tui-live-p (car entry)))) callbacks)))))

(ert-deftest emacs-tui-inspector-unsupported-launch-preserves-host ()
  (save-window-excursion
    (let ((buffer (current-buffer)) (buffers (buffer-list)) (state (window-state-get)))
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) nil)))
        (should-error (emacs-tui-inspector-demo) :type 'user-error))
      (should (eq buffer (current-buffer)))
      (should (equal buffers (buffer-list)))
      (should (equal state (window-state-get))))))

(ert-deftest emacs-tui-inspector-follows-links-with-independent-object-actions ()
  (emacs-tui-inspector-test--source
    (let ((text (buffer-string)) (point (point)) (undo buffer-undo-list))
      (emacs-tui-inspector-demo-at-point)
      (let ((app emacs-tui-inspector-demo--session))
        (emacs-tui-inspector-demo-acknowledge)
        (emacs-tui-inspector-demo-follow)
        (should (equal "valve" (car emacs-tui-inspector-demo--object)))
        (should-not (gethash "valve" emacs-tui-inspector-demo--acknowledged))
        (emacs-tui-inspector-demo-follow)
        (should (equal "sensor" (car emacs-tui-inspector-demo--object)))
        (emacs-tui-inspector-demo-acknowledge)
        (emacs-tui-inspector-demo-back)
        (emacs-tui-inspector-demo-back)
        (should (equal "pump" (car emacs-tui-inspector-demo--object)))
        (should (string-match-p "Acknowledged: yes"
                                (emacs-tui--view-text (car (emacs-tui--workspace-views app)))))
        (emacs-tui-inspector-demo-forward)
        (should (equal "valve" (car emacs-tui-inspector-demo--object)))
        (should (eq app emacs-tui-inspector-demo--session))
        (should (equal text (buffer-string)))
        (should (= point (point)))
        (should (equal undo buffer-undo-list))
        (emacs-tui-inspector-demo-dismiss)
        (should-not emacs-tui-inspector-demo--back)
        (should-not emacs-tui-inspector-demo--forward)
        (emacs-tui-inspector-demo-at-point)
        (should-error (emacs-tui-inspector-demo-back) :type 'user-error)
        (should (gethash "sensor" emacs-tui-inspector-demo--acknowledged))))))

(ert-deftest emacs-tui-inspector-history-is-bounded-and-new-visits-discard-forward ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (dotimes (_ 40) (emacs-tui-inspector-demo-follow))
    (should (= 32 (length emacs-tui-inspector-demo--back)))
    (dotimes (_ 32) (emacs-tui-inspector-demo-back))
    (should-error (emacs-tui-inspector-demo-back) :type 'user-error)
    (should (= 32 (length emacs-tui-inspector-demo--forward)))
    (emacs-tui-inspector-demo-forward)
    (emacs-tui-inspector-demo-follow)
    (should-not emacs-tui-inspector-demo--forward)
    (should-error (emacs-tui-inspector-demo-forward) :type 'user-error)))

(ert-deftest emacs-tui-inspector-failed-navigation-preserves-history ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (emacs-tui-inspector-demo-follow)
    (emacs-tui-inspector-demo-follow)
    (emacs-tui-inspector-demo-back)
    (let ((object emacs-tui-inspector-demo--object)
          (back emacs-tui-inspector-demo--back)
          (forward emacs-tui-inspector-demo--forward))
      (cl-letf (((symbol-function 'emacs-tui-update) (lambda (&rest _) (error "Render failed"))))
        (dolist (command '(emacs-tui-inspector-demo-follow emacs-tui-inspector-demo-back
                          emacs-tui-inspector-demo-forward))
          (should-error (funcall command))
          (should (eq object emacs-tui-inspector-demo--object))
          (should (eq back emacs-tui-inspector-demo--back))
          (should (eq forward emacs-tui-inspector-demo--forward)))))))

(ert-deftest emacs-tui-inspector-reentrant-actions-cannot-diverge-display-and-state ()
  (dolist (before '(nil t))
    (dolist (command '(emacs-tui-inspector-demo-follow emacs-tui-inspector-demo-acknowledge))
      (emacs-tui-inspector-test--source
        (emacs-tui-inspector-demo-at-point)
        (let ((update (symbol-function 'emacs-tui-update)) attempted)
          (cl-letf (((symbol-function 'emacs-tui-update)
                     (lambda (&rest args)
                       (unless before (apply update args))
                       (setq attempted t)
                       (should-error (emacs-tui-inspector-demo-follow) :type 'user-error)
                       (should-error (emacs-tui-inspector-demo-acknowledge) :type 'user-error)
                       (when before (apply update args)))))
            (funcall command))
          (should attempted)
          (let* ((following (eq command 'emacs-tui-inspector-demo-follow))
                 (object emacs-tui-inspector-demo--object)
                 (acknowledged (gethash (car object) emacs-tui-inspector-demo--acknowledged)))
            (should (equal (if following "valve" "pump") (car object)))
            (should (eq (not following) acknowledged))
            (should (= (if following 1 0) (length emacs-tui-inspector-demo--back)))
            (should (equal-including-properties
                     (emacs-tui-inspector-demo--text object acknowledged)
                     (emacs-tui--view-text
                      (car (emacs-tui--workspace-views emacs-tui-inspector-demo--session))))))
          (should-not emacs-tui-inspector-demo--publishing))))))

(ert-deftest emacs-tui-inspector-close-during-navigation-clears-history ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (emacs-tui-inspector-demo-follow)
    (cl-letf (((symbol-function 'emacs-tui-update)
               (lambda (app &rest _) (emacs-tui-close app))))
      (should-error (emacs-tui-inspector-demo-back) :type 'user-error))
    (should-not emacs-tui-inspector-demo--back)
    (should-not emacs-tui-inspector-demo--forward)
    (should-not emacs-tui-inspector-demo--object)))

(ert-deftest emacs-tui-inspector-navigation-does-not-overwrite-replacement-session ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (let ((old emacs-tui-inspector-demo--session) replacement)
      (cl-letf (((symbol-function 'emacs-tui-update)
                 (lambda (app &rest _)
                   (emacs-tui-close app)
                   (setq replacement (emacs-tui-inspector-demo-at-point)))))
        (should-error (emacs-tui-inspector-demo-follow) :type 'user-error))
      (should-not (emacs-tui-live-p old))
      (should (emacs-tui-live-p replacement))
      (should (eq replacement emacs-tui-inspector-demo--session))
      (should (equal "pump" (car emacs-tui-inspector-demo--object)))
      (should-not emacs-tui-inspector-demo--back)
      (should-not emacs-tui-inspector-demo--publishing))))

(ert-deftest emacs-tui-inspector-failed-publication-releases-reentrancy-guard ()
  (emacs-tui-inspector-test--source
    (emacs-tui-inspector-demo-at-point)
    (cl-letf (((symbol-function 'emacs-tui-update)
               (lambda (&rest _) (emacs-tui-inspector-demo-follow))))
      (should-error (emacs-tui-inspector-demo-follow) :type 'user-error))
    (should-not emacs-tui-inspector-demo--publishing)
    (should-not emacs-tui-inspector-demo--back)
    (emacs-tui-inspector-demo-follow)
    (should (equal "valve" (car emacs-tui-inspector-demo--object)))))

(ert-deftest emacs-tui-inspector-native-render-hook-reentry-rolls-back ()
  (save-window-excursion
    (let ((source (generate-new-buffer " *inspector hook source*")) app)
      (unwind-protect
          (progn
            (switch-to-buffer source)
            (insert "pump")
            (let ((original (selected-window)))
              (setq app (emacs-tui-mount
                         :views (list (emacs-tui-view :id 'details :text "initial"))))
              (select-window original)
              (switch-to-buffer source))
            (setq emacs-tui-inspector-demo--session app
                  emacs-tui-inspector-demo--object (assoc "pump" emacs-tui-inspector-demo--objects)
                  emacs-tui-inspector-demo--acknowledged (make-hash-table :test #'equal))
            (let ((view (emacs-tui--resolve-view app 'details))
                  (hook (lambda (&rest _)
                          (with-current-buffer source (emacs-tui-inspector-demo-follow)))))
              (emacs-tui-update app 'details
                                :text (emacs-tui-inspector-demo--text emacs-tui-inspector-demo--object nil))
              (with-current-buffer (emacs-tui--view-buffer view)
                (add-hook 'before-change-functions hook nil t))
              (should-error (emacs-tui-inspector-demo-acknowledge) :type 'user-error)
              (with-current-buffer (emacs-tui--view-buffer view)
                (remove-hook 'before-change-functions hook t))
              (should (equal "pump" (car emacs-tui-inspector-demo--object)))
              (should-not (gethash "pump" emacs-tui-inspector-demo--acknowledged))
              (should (equal-including-properties
                       (emacs-tui-inspector-demo--text emacs-tui-inspector-demo--object nil)
                       (with-current-buffer (emacs-tui--view-buffer view) (buffer-string))))
              (should-not emacs-tui-inspector-demo--publishing)))
        (when app (emacs-tui-close app))
        (kill-buffer source)))))

(provide 'emacs-tui-inspector-test)
;;; emacs-tui-inspector-test.el ends here
