;;; emacs-tui-multi-popup-test.el --- Multi-popup demo policies -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Model presentation for application policy/failure tests.  Real sibling frames,
;; native keys and source preservation run in the shared GUI/TTY smoke fixture.

;;; Code:
(require 'ert)
(require 'emacs-tui-multi-popup-demo
         (expand-file-name "../examples/emacs-tui-multi-popup-demo.el"
                           (file-name-directory (or load-file-name buffer-file-name))))

(defmacro emacs-tui-multi-test--source (&rest body)
  "Run BODY with real source editing and modeled popup resources."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (let ((source (generate-new-buffer " *multi source*"))
           callbacks created create-hook fail-on (calls 0))
       (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) t))
                 ((symbol-function 'emacs-tui-popup)
                  (lambda (&rest args)
                    (cl-incf calls)
                    (when (equal calls fail-on) (error "Injected creation failure"))
                    (let ((app (emacs-tui--make-workspace
                                :active t :views (list (plist-get args :view)))))
                      (push app created)
                      (push (cons app (plist-get args :on-close)) callbacks)
                      (when create-hook (funcall create-hook))
                      app)))
                 ((symbol-function 'emacs-tui-set-selection)
                  (lambda (app _id id)
                    (setf (emacs-tui--view-selected (car (emacs-tui--workspace-views app))) id)))
                 ((symbol-function 'emacs-tui-update)
                  (lambda (app _id &rest args)
                    (setf (emacs-tui--view-text (car (emacs-tui--workspace-views app)))
                          (plist-get args :text))))
                 ((symbol-function 'emacs-tui-close)
                  (lambda (app)
                    (when (emacs-tui-live-p app)
                      (setf (emacs-tui--workspace-active app) nil)
                      (funcall (cdr (assq app callbacks)) app)))))
         (unwind-protect
             (progn (switch-to-buffer source) (text-mode) (insert "Native 日本語") ,@body)
           (dolist (app created) (emacs-tui-close app))
           (when (buffer-live-p source) (kill-buffer source)))))))

(ert-deftest emacs-tui-multi-individual-and-all-toggles-preserve-siblings-and-source ()
  (emacs-tui-multi-test--source
    (let ((text (buffer-string)) (point (point)) (undo (copy-tree buffer-undo-list)))
      (emacs-tui-multi-popup-demo-mode 1)
      (let ((objects (emacs-tui-multi-popup-demo--session 'objects))
            (keys (emacs-tui-multi-popup-demo--session 'keys))
            (details (emacs-tui-multi-popup-demo--session 'details)))
        (execute-kbd-macro (kbd "C-c 2"))
        (should-not (emacs-tui-live-p details))
        (should (eq objects (emacs-tui-multi-popup-demo--session 'objects)))
        (should (eq keys (emacs-tui-multi-popup-demo--session 'keys)))
        ;; A partial set toggles off completely, then the next toggle shows all.
        (execute-kbd-macro (kbd "C-c 0"))
        (should-not (cl-some #'emacs-tui-live-p created))
        (should emacs-tui-multi-popup-demo-mode)
        (execute-kbd-macro (kbd "C-c 0"))
        (should (= 3 (cl-count-if #'emacs-tui-live-p created))))
      (should (equal text (buffer-string))) (should (= point (point)))
      (should (equal undo buffer-undo-list))
      (execute-kbd-macro (kbd "C-c C-q"))
      (should-not emacs-tui-multi-popup-demo-mode)
      (should-not (cl-some #'emacs-tui-live-p created)))))

(ert-deftest emacs-tui-multi-hidden-panels-retain-application-selection ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (execute-kbd-macro (kbd "C-c 0 M-n C-c 0"))
    (should (= 1 emacs-tui-multi-popup-demo--index))
    (should (eq 'valve (emacs-tui--view-selected
                       (car (emacs-tui--workspace-views
                             (emacs-tui-multi-popup-demo--session 'objects))))))
    (should (string-match-p "Return valve"
                           (emacs-tui--view-text
                            (car (emacs-tui--workspace-views
                                  (emacs-tui-multi-popup-demo--session 'details))))))))

(ert-deftest emacs-tui-multi-all-start-failure-rolls-back-and-restores-bindings ()
  (emacs-tui-multi-test--source
    (setq fail-on 3)
    (should-error (emacs-tui-multi-popup-demo-mode 1))
    (should-not emacs-tui-multi-popup-demo-mode)
    (should-not (cl-some #'emacs-tui-live-p created))
    (should-not (memq #'emacs-tui-multi-popup-demo--stop change-major-mode-hook))
    (should-not (eq (key-binding (kbd "C-c 1"))
                    #'emacs-tui-multi-popup-demo-toggle-objects))))

(ert-deftest emacs-tui-multi-individual-start-failure-preserves-existing-siblings ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (emacs-tui-multi-popup-demo-toggle-details)
    (setq fail-on (1+ calls))
    (should-error (emacs-tui-multi-popup-demo-toggle-details))
    (should (= 2 (cl-count-if #'emacs-tui-live-p created)))
    (should (emacs-tui-multi-popup-demo--session 'objects))
    (should (emacs-tui-multi-popup-demo--session 'keys))))

(ert-deftest emacs-tui-multi-source-repurposing-closes-all-panels ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (text-mode)
    (should-not emacs-tui-multi-popup-demo-mode)
    (should-not (cl-some #'emacs-tui-live-p created))))

(ert-deftest emacs-tui-multi-enable-switch-preserves-foreign-demo ()
  (emacs-tui-multi-test--source
    (let ((foreign (generate-new-buffer " *foreign multi*")) foreign-apps)
      (unwind-protect
          (progn
            (switch-to-buffer foreign)
            (emacs-tui-multi-popup-demo-mode 1)
            (setq foreign-apps (mapcar #'cdr emacs-tui-multi-popup-demo--sessions))
            (switch-to-buffer source)
            (setq create-hook (lambda () (when (= calls 5) (switch-to-buffer foreign))))
            (should-error (emacs-tui-multi-popup-demo-mode 1) :type 'user-error)
            (should (eq foreign (current-buffer)))
            (should emacs-tui-multi-popup-demo-mode)
            (should (cl-every #'emacs-tui-live-p foreign-apps))
            (should (= 3 (cl-count-if #'emacs-tui-live-p created))))
        (kill-buffer foreign)))))

(ert-deftest emacs-tui-multi-unsupported-mode-leaves-no-binding-or-source-change ()
  (with-temp-buffer
    (let ((text (buffer-string)))
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) nil)))
        (should-error (emacs-tui-multi-popup-demo-mode 1) :type 'user-error))
      (should-not emacs-tui-multi-popup-demo-mode)
      (should (equal text (buffer-string)))
      (should-not emacs-tui-multi-popup-demo--sessions))))

(ert-deftest emacs-tui-multi-dismiss-during-creation-cancels-without-losing-bindings ()
  (emacs-tui-multi-test--source
    (setq create-hook #'emacs-tui-multi-popup-demo-dismiss)
    (should-error (emacs-tui-multi-popup-demo-mode 1) :type 'user-error)
    (should emacs-tui-multi-popup-demo-mode)
    (should-not (cl-some #'emacs-tui-live-p created))
    (setq create-hook nil)
    (execute-kbd-macro (kbd "C-c 0"))
    (should (= 3 (cl-count-if #'emacs-tui-live-p created)))))

(ert-deftest emacs-tui-multi-stop-attempts-every-sibling-after-close-error ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (let ((close (symbol-function 'emacs-tui-close)) first)
      (cl-letf (((symbol-function 'emacs-tui-close)
                 (lambda (app)
                   (funcall close app)
                   (unless first (setq first t) (error "Native deletion hook failed")))))
        (should-error (emacs-tui-multi-popup-demo-mode -1))))
    (should-not (cl-some #'emacs-tui-live-p created))
    (should-not emacs-tui-multi-popup-demo-mode)
    (should-not (memq #'emacs-tui-multi-popup-demo--stop kill-buffer-hook))
    (should-not (memq #'emacs-tui-multi-popup-demo--stop change-major-mode-hook))))

(ert-deftest emacs-tui-multi-failed-browse-reopens-coherent-data-panels ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (cl-letf (((symbol-function 'emacs-tui-set-selection)
               (lambda (&rest _) (error "Selection publication failed"))))
      (should-error (emacs-tui-multi-popup-demo-next)))
    (should (= 1 emacs-tui-multi-popup-demo--index))
    (should-not (emacs-tui-multi-popup-demo--session 'objects))
    (should-not (emacs-tui-multi-popup-demo--session 'details))
    (should (emacs-tui-multi-popup-demo--session 'keys))
    (execute-kbd-macro (kbd "C-c 1 C-c 2"))
    (should (eq 'valve (emacs-tui--view-selected
                       (car (emacs-tui--workspace-views
                             (emacs-tui-multi-popup-demo--session 'objects))))))))

(ert-deftest emacs-tui-multi-gallery-failed-tour-releases-real-chooser ()
  (require 'emacs-tui-multi-popup-smoke)
  (save-window-excursion
    (let ((before (copy-sequence emacs-tui--sessions)) (noninteractive nil))
      (cl-letf (((symbol-function 'execute-kbd-macro)
                 (lambda (&rest _) (error "Injected tour command failure"))))
        (should-error (emacs-tui-multi-popup-smoke)))
      (should-not (cl-set-difference emacs-tui--sessions before)))))

(provide 'emacs-tui-multi-popup-test)
;;; emacs-tui-multi-popup-test.el ends here
