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
                                :active t :views (list (plist-get args :view))
                                :popup (emacs-tui--make-popup :position (plist-get args :position)
                                                             :width (plist-get args :width)
                                                             :height (plist-get args :height)))))
                      (push app created)
                      (push (cons app (plist-get args :on-close)) callbacks)
                      (when create-hook (funcall create-hook))
                      app)))
                 ((symbol-function 'emacs-tui-reposition-popup)
                  (lambda (app &optional position)
                    (let* ((popup (emacs-tui--workspace-popup app))
                           (current (emacs-tui--popup-position popup))
                           (next (or position
                                     (nth (mod (1+ (cl-position current emacs-tui-layout-popup-positions)) 8)
                                          emacs-tui-layout-popup-positions))))
                      (setf (emacs-tui--popup-position popup) next))))
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

(ert-deftest emacs-tui-multi-size-toggle-retains-choice-and-siblings ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (let ((apps (copy-sequence emacs-tui-multi-popup-demo--sessions)) sizes)
      (cl-letf (((symbol-function 'emacs-tui-resize-popup)
                 (lambda (app width height)
                   (should (eq app (emacs-tui-multi-popup-demo--session 'details)))
                   (push (list width height) sizes))))
        (execute-kbd-macro (kbd "C-c C-e"))
        (should emacs-tui-multi-popup-demo--expanded)
        (should (equal apps emacs-tui-multi-popup-demo--sessions))
        (execute-kbd-macro (kbd "C-c 2 C-c 2"))
        (let ((popup (emacs-tui--workspace-popup (emacs-tui-multi-popup-demo--session 'details))))
          (should (= 50 (emacs-tui--popup-width popup)))
          (should (= 12 (emacs-tui--popup-height popup))))
        (dolist (id '(objects keys))
          (should (eq (alist-get id apps) (emacs-tui-multi-popup-demo--session id))))
        (execute-kbd-macro (kbd "C-c C-e"))
        (should-not emacs-tui-multi-popup-demo--expanded)
        (should (equal sizes '((34 7) (50 12))))
        (emacs-tui-multi-popup-demo-mode -1)
        (should-error (emacs-tui-multi-popup-demo-toggle-size) :type 'user-error)))))

(ert-deftest emacs-tui-multi-size-rejects-hidden-busy-failed-and-stale-publication ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (let ((resizes 0))
      (cl-letf (((symbol-function 'emacs-tui-resize-popup)
                 (lambda (&rest _) (cl-incf resizes) (error "Injected resize failure"))))
        (let ((emacs-tui-multi-popup-demo--busy t))
          (should-error (emacs-tui-multi-popup-demo-toggle-size) :type 'user-error))
        (should (= 0 resizes))
        (should-error (emacs-tui-multi-popup-demo-toggle-size))
        (should (= 1 resizes))
        (should-not emacs-tui-multi-popup-demo--expanded)
        (emacs-tui-multi-popup-demo-toggle-details)
        (should-error (emacs-tui-multi-popup-demo-toggle-size) :type 'user-error)
        (should (= 1 resizes)))
      (emacs-tui-multi-popup-demo-toggle-details)
      (cl-letf (((symbol-function 'emacs-tui-resize-popup)
                 (lambda (&rest _) (emacs-tui-multi-popup-demo-dismiss))))
        (should-error (emacs-tui-multi-popup-demo-toggle-size) :type 'user-error)
        (should-not emacs-tui-multi-popup-demo--expanded)))))

(ert-deftest emacs-tui-multi-scroll-targets-only-visible-details ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (let ((apps (copy-sequence emacs-tui-multi-popup-demo--sessions)) calls)
      (cl-letf (((symbol-function 'emacs-tui-scroll-view)
                 (lambda (app id lines) (push (list app id lines) calls))))
        (execute-kbd-macro (kbd "C-c ] C-c ["))
        (should (equal calls
                       (list (list (alist-get 'details apps) 'details -3)
                             (list (alist-get 'details apps) 'details 3))))
        (should (equal apps emacs-tui-multi-popup-demo--sessions))
        (should (= 0 emacs-tui-multi-popup-demo--index))
        (let ((emacs-tui-multi-popup-demo--busy t))
          (should-error (emacs-tui-multi-popup-demo-scroll-backward) :type 'user-error))
        (should (= 2 (length calls)))
        (emacs-tui-multi-popup-demo-toggle-details)
        (should-error (emacs-tui-multi-popup-demo-scroll-forward) :type 'user-error)
        (should-not (emacs-tui-multi-popup-demo--session 'details))
        (should (= 2 (length calls)))
        (emacs-tui-multi-popup-demo-mode -1)
        (should-error (emacs-tui-multi-popup-demo-scroll-forward) :type 'user-error)))))

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

(ert-deftest emacs-tui-multi-placement-is-independent-and-survives-hidden-panels ()
  (emacs-tui-multi-test--source
    (let ((text (buffer-string)) (position (point)))
      (emacs-tui-multi-popup-demo-mode 1)
      (emacs-tui-multi-popup-demo-next)
      (dolist (step '((objects "C-c p 1" west)
                      (details "C-c p 2" south-east)
                      (keys "C-c p 3" north)))
        (let* ((id (car step))
               (siblings (cl-remove-if (lambda (entry) (eq id (car entry)))
                                       (copy-tree emacs-tui-multi-popup-demo--positions))))
          (execute-kbd-macro (kbd (nth 1 step)))
          (should (eq (nth 2 step) (alist-get id emacs-tui-multi-popup-demo--positions)))
          (dolist (entry siblings)
            (should (eq (cdr entry) (alist-get (car entry) emacs-tui-multi-popup-demo--positions))))))
      (execute-kbd-macro (kbd "C-c 2 C-c 2 C-c 0 C-c 0"))
      (dolist (entry '((objects . west) (details . south-east) (keys . north)))
        (should (eq (cdr entry)
                    (emacs-tui--popup-position
                     (emacs-tui--workspace-popup (emacs-tui-multi-popup-demo--session (car entry)))))))
      (should (= 1 emacs-tui-multi-popup-demo--index))
      (should (equal text (buffer-string))) (should (= position (point)))
      (emacs-tui-multi-popup-demo-mode -1)
      (emacs-tui-multi-popup-demo-mode 1)
      (should-not emacs-tui-multi-popup-demo--positions))))

(ert-deftest emacs-tui-multi-hidden-panel-movement-does-not-open-it ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (emacs-tui-multi-popup-demo-toggle-details)
    (should-error (emacs-tui-multi-popup-demo-move-details) :type 'user-error)
    (should-not (emacs-tui-multi-popup-demo--session 'details))
    (should (= 2 (cl-count-if #'emacs-tui-live-p created)))
    (should-not emacs-tui-multi-popup-demo--positions)))

(ert-deftest emacs-tui-multi-movement-does-not-save-after-dismissal ()
  (emacs-tui-multi-test--source
    (emacs-tui-multi-popup-demo-mode 1)
    (cl-letf (((symbol-function 'emacs-tui-reposition-popup)
               (lambda (&rest _) (emacs-tui-multi-popup-demo-dismiss) 'north)))
      (should-error (emacs-tui-multi-popup-demo-move-details) :type 'user-error))
    (should-not emacs-tui-multi-popup-demo--positions)
    (should-not (cl-some #'emacs-tui-live-p created))))

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
