;;; emacs-tui-action-test.el --- Explicit context action behavior -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Actions target current source objects, remain explicit and recheck menu state.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-action-test--with (views &rest body)
  "Mount VIEWS as session, run BODY and release owned resources."
  (declare (indent 1) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let (session)
       (unwind-protect
           (progn (setq session (emacs-tui-mount :views ,views)) ,@body)
         (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-action-construction-rejects-invalid-descriptions ()
  (should-error (emacs-tui-action :run #'ignore))
  (should-error (emacs-tui-action :id 'a :run nil))
  (should-error (emacs-tui-action :id 'a :title 42 :run #'ignore))
  (should-error (emacs-tui-action :id 'a :run #'ignore :enabled 'undefined-callback))
  (should-error (emacs-tui-view :id 'a :actions '(not-an-action)))
  (let ((action (emacs-tui-action :id 'a :run #'ignore)))
    (should-error (emacs-tui-tree :id 'a :actions (list action action)))))

(ert-deftest emacs-tui-action-runs-only-explicitly-and-keeps-interface-open ()
  (let ((runs 0) (predicates 0) selected)
    (emacs-tui-action-test--with
        (list (emacs-tui-view
               :id 'a :items '("alpha" "beta")
               :on-select (lambda (&rest _) (setq selected t))
               :actions (list (emacs-tui-action
                               :id 'copy :run (lambda (_app items) (cl-incf runs) items)
                               :enabled (lambda (&rest _) (cl-incf predicates) t)))))
      (emacs-tui-next-item session)
      (emacs-tui-refresh session)
      (emacs-tui-set-query session 'a "beta")
      (should (= 0 predicates))
      (should (= 0 runs))
      (should (equal '("beta") (emacs-tui-act session 'copy)))
      (should (= 1 runs))
      (should (= 1 predicates))
      (should-not selected)
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-action-uses-hidden-marks-in-source-order ()
  (let* ((a (list :id 'a :label "alpha")) (b (list :id 'b :label "beta")) received)
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items (list a b) :multi-select t
                              :actions (list (emacs-tui-action
                                              :id 'batch :run (lambda (_app items) (setq received items))))))
      (emacs-tui-next-item session)
      (emacs-tui-toggle-mark session)
      (emacs-tui-next-item session)
      (emacs-tui-toggle-mark session)
      (emacs-tui-set-query session 'a "nothing")
      (emacs-tui-act session 'batch)
      (should (equal (list a b) received))
      (should (eq a (car received)))
      (should (eq b (cadr received))))))

(ert-deftest emacs-tui-action-marked-update-uses-new-source-objects ()
  (let (received)
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items '((:id x :label "old")) :multi-select t
                              :actions (list (emacs-tui-action :id 'run
                                                               :run (lambda (_app items) (setq received items))))))
      (emacs-tui-toggle-mark session)
      (let ((new (list :id 'x :label "new")))
        (emacs-tui-update session 'a :items (list new))
        (emacs-tui-act session 'run)
        (should (eq new (car received)))))))

(ert-deftest emacs-tui-action-target-free-input-action-keeps-editing-native ()
  (let (received)
    (emacs-tui-action-test--with
        (list (emacs-tui-input :id 'input
                               :actions (list (emacs-tui-action :id 'apply
                                                                :run (lambda (app items)
                                                                       (setq received (list items (emacs-tui-input-value app))))))))
      (execute-kbd-macro (kbd "a b c"))
      (emacs-tui-act session 'apply)
      (should (equal '(nil "abc") received))
      (should (equal "abc" (emacs-tui-input-value session))))))

(ert-deftest emacs-tui-action-disabled-unknown-and-missing-actions-do-not-run ()
  (let ((runs 0))
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items '("x")
                              :actions (list (emacs-tui-action :id 'disabled
                                                               :enabled nil
                                                               :run (lambda (&rest _) (cl-incf runs))))))
      (should-error (emacs-tui-act session 'disabled) :type 'user-error)
      (should-error (emacs-tui-act session 'missing) :type 'user-error)
      (should-error (emacs-tui-act session) :type 'user-error)
      (should (= 0 runs)))
    (emacs-tui-action-test--with (list (emacs-tui-view :id 'a))
      (should-error (emacs-tui-act session) :type 'user-error))))

(ert-deftest emacs-tui-action-menu-dispatches-current-object-after-source-update ()
  (let (received)
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items '((:id x :label "old"))
                              :actions (list (emacs-tui-action :id 'run :title "Run"
                                                               :run (lambda (_app items) (setq received items))))))
      (let ((new (list :id 'x :label "new")))
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (&rest _)
                     (emacs-tui-update session 'a :items (list new)) "Run (run)")))
          (emacs-tui-act session))
        (should (eq new (car received)))))))

(ert-deftest emacs-tui-action-menu-rechecks-availability-after-source-change ()
  (let ((runs 0))
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items '("x")
                              :actions (list (emacs-tui-action :id 'run :title "Run"
                                                               :enabled (lambda (_app items) (consp items))
                                                               :run (lambda (&rest _) (cl-incf runs))))))
      (cl-letf (((symbol-function 'completing-read)
                 (lambda (&rest _) (emacs-tui-update session 'a :items nil) "Run (run)")))
        (should-error (emacs-tui-act session) :type 'user-error))
      (should (= 0 runs)))))

(ert-deftest emacs-tui-action-menu-aborts-after-close-or-focus-change ()
  (let ((runs 0))
    (dolist (operation '(focus close))
      (emacs-tui-action-test--with
          (list (emacs-tui-view :id 'a :items '("x")
                                :actions (list (emacs-tui-action :id 'run :title "Run"
                                                                 :run (lambda (&rest _) (cl-incf runs)))))
                (emacs-tui-view :id 'b :items '("y")))
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (&rest _)
                     (if (eq operation 'focus) (emacs-tui-next-view session) (emacs-tui-close session))
                     "Run (run)")))
          (should-error (emacs-tui-act session) :type 'user-error))))
    (should (= 0 runs))))

(ert-deftest emacs-tui-action-errors-keep-interface-and-original-selection ()
  (emacs-tui-action-test--with
      (list (emacs-tui-view :id 'a :items '("x")
                            :actions (list (emacs-tui-action :id 'fail :run (lambda (&rest _) (error "Application failed"))))))
    (should-error (emacs-tui-act session 'fail))
    (should (equal "x" (emacs-tui-current-item session)))
    (should (emacs-tui-live-p session))))

(ert-deftest emacs-tui-action-may-close-explicitly ()
  (emacs-tui-action-test--with
      (list (emacs-tui-view :id 'a :actions
                            (list (emacs-tui-action :id 'close :run (lambda (app _items) (emacs-tui-close app) 'done)))))
    (should (eq 'done (emacs-tui-act session 'close)))
    (should-not (emacs-tui-live-p session))))

(ert-deftest emacs-tui-action-tree-demo-copies-marked-names-explicitly ()
  (load (expand-file-name "../examples/emacs-tui-buffer-tree.el"
                          (file-name-directory (or load-file-name
                                                   (locate-library "emacs-tui-action-test")))))
  (let ((kill-ring nil))
    (emacs-tui-action-test--with
        (list (emacs-tui-tree :id 'a :multi-select t
                              :items '((:id root :label "Root" :children ((:id leaf :label "Leaf"))))
                              :actions (emacs-tui-buffer-tree--actions)))
      (should-not kill-ring)
      (execute-kbd-macro (kbd "<right> <right> C-c C-m <left> <left>"))
      (emacs-tui-act session 'copy)
      (should (equal "Leaf" (car kill-ring)))
      (should-error (emacs-tui-act session 'display) :type 'user-error)
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-action-menu-cancel-keeps-interface-open ()
  (let ((runs 0))
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items '("x")
                              :actions (list (emacs-tui-action :id 'run :run (lambda (&rest _) (cl-incf runs))))))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) (signal 'quit nil))))
        (condition-case nil (emacs-tui-act session) (quit nil)))
      (should (= 0 runs))
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-action-same-title-distinct-ids-remain-selectable ()
  (dolist (ids (list (list 'run "run") (list (make-symbol "run") (make-symbol "run"))))
    (let (result)
      (emacs-tui-action-test--with
          (list (emacs-tui-view
                 :id 'a :items '("x")
                 :actions (list (emacs-tui-action :id (car ids) :title "Same"
                                                  :run (lambda (&rest _) (setq result 'first)))
                                (emacs-tui-action :id (cadr ids) :title "Same"
                                                  :run (lambda (&rest _) (setq result 'second))))))
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (_prompt choices &rest _)
                     (should (= 2 (length choices)))
                     (should-not (equal (caar choices) (caadr choices)))
                     (caadr choices))))
          (emacs-tui-act session))
        (should (eq 'second result))))))

(ert-deftest emacs-tui-action-accepted-case-insensitive-menu-answer-resolves ()
  (let ((completion-ignore-case t) result)
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items '("x")
                              :actions (list (emacs-tui-action :id 'run :title "Run"
                                                               :run (lambda (&rest _) (setq result 'ran))))))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "run (run)")))
        (emacs-tui-act session))
      (should (eq 'ran result)))))

(ert-deftest emacs-tui-action-case-folded-menu-prefers-exact-candidate ()
  (let ((completion-ignore-case t) result)
    (emacs-tui-action-test--with
        (list (emacs-tui-view
               :id 'a :items '("x")
               :actions (list (emacs-tui-action :id 'run :title "Run" :run (lambda (&rest _) (setq result 'first)))
                              (emacs-tui-action :id 'RUN :title "RUN" :run (lambda (&rest _) (setq result 'second))))))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "RUN (RUN)")))
        (emacs-tui-act session))
      (should (eq 'second result)))))

(ert-deftest emacs-tui-action-ambiguous-folded-answer-does-not-dispatch ()
  (let ((completion-ignore-case t) (runs 0))
    (emacs-tui-action-test--with
        (list (emacs-tui-view
               :id 'a :items '("x")
               :actions (list (emacs-tui-action :id 'run :title "Run" :run (lambda (&rest _) (cl-incf runs)))
                              (emacs-tui-action :id 'RUN :title "RUN" :run (lambda (&rest _) (cl-incf runs))))))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "rUn (rUn)")))
        (should-error (emacs-tui-act session) :type 'user-error))
      (should (= 0 runs)))))

(ert-deftest emacs-tui-action-availability-cannot-dispatch-after-invalidation ()
  ;; A predicate can yield to a timer/process callback even when it is pure.
  ;; Exercise the resulting invalidation synchronously at the same boundary.
  (dolist (operation '(close focus replace select mark))
    (dolist (prompt '(nil t))
      (let ((runs 0) (prompts 0))
        (emacs-tui-action-test--with
            (list (emacs-tui-view
                   :id 'a :items (list (list :id 'x :label "same")
                                      (list :id 'y :label "other"))
                   :multi-select t
                   :actions
                   (list (emacs-tui-action
                          :id 'run :title "Run"
                          :enabled
                          (lambda (app _items)
                            (pcase operation
                              ('close (emacs-tui-close app))
                              ('focus (emacs-tui-next-view app))
                              ('replace (emacs-tui-update
                                         app 'a :items (list (list :id 'x :label "same")
                                                            (list :id 'y :label "other"))))
                              ('select (emacs-tui-next-item app))
                              ('mark (emacs-tui-next-item app)
                                     (emacs-tui-toggle-mark app)))
                            t)
                          :run (lambda (&rest _) (cl-incf runs)))))
                  (emacs-tui-view :id 'b :items '("b")))
          (cl-letf (((symbol-function 'completing-read)
                     (lambda (&rest _) (cl-incf prompts) "Run (run)")))
            (should-error (emacs-tui-act session (unless prompt 'run))
                          :type 'user-error))
          (should (= 0 runs))
          (should (= 0 prompts)))))))

(ert-deftest emacs-tui-action-final-availability-cannot-use-replaced-targets ()
  (let ((runs 0) (checks 0) (prompts 0))
    (emacs-tui-action-test--with
        (list (emacs-tui-view
               :id 'a :items (list (list :id 'x :label "same"))
               :actions
               (list (emacs-tui-action
                      :id 'run :title "Run"
                      :enabled (lambda (app _items)
                                 (when (= 2 (cl-incf checks))
                                   (emacs-tui-update app 'a :items
                                                     (list (list :id 'x :label "same"))))
                                 t)
                      :run (lambda (&rest _) (cl-incf runs))))))
      (cl-letf (((symbol-function 'completing-read)
                 (lambda (&rest _) (cl-incf prompts) "Run (run)")))
        (should-error (emacs-tui-act session) :type 'user-error))
      (should (= 1 prompts))
      (should (= 2 checks))
      (should (= 0 runs)))))

(ert-deftest emacs-tui-action-repurposed-surface-never-dispatches ()
  (dolist (prompt '(nil t))
    (let ((foreign (generate-new-buffer " *action-foreign*"))
          (runs 0) (checks 0))
      (unwind-protect
          (emacs-tui-action-test--with
              (list (emacs-tui-view
                     :id 'a :items '("x")
                     :actions (list (emacs-tui-action
                                     :id 'run :title "Run"
                                     :enabled (lambda (&rest _) (cl-incf checks) t)
                                     :run (lambda (&rest _) (cl-incf runs))))))
            (let ((window (selected-window)))
              (cl-letf (((symbol-function 'completing-read)
                         (lambda (&rest _)
                           (set-window-buffer window foreign)
                           "Run (run)")))
                (unless prompt (set-window-buffer window foreign))
                (should-error (emacs-tui-act session (unless prompt 'run))
                              :type 'user-error))
              (should (= (if prompt 1 0) checks))
              (should (= 0 runs))
              (should (eq foreign (window-buffer window)))))
        (kill-buffer foreign)))))

(ert-deftest emacs-tui-select-rejects-repurposed-surface ()
  (let ((foreign (generate-new-buffer " *select-foreign*")) (runs 0))
    (unwind-protect
        (emacs-tui-action-test--with
            (list (emacs-tui-view :id 'a :items '("x")
                                  :on-select (lambda (&rest _) (cl-incf runs))))
          (let ((window (selected-window)))
            (with-current-buffer foreign (insert "keep"))
            (set-window-buffer window foreign)
            (should-error (emacs-tui-select session) :type 'user-error)
            (should (= 0 runs))
            (should (eq foreign (window-buffer window)))
            (should (equal "keep" (with-current-buffer foreign (buffer-string))))))
      (kill-buffer foreign))))

(ert-deftest emacs-tui-select-preserves-single-selection-with-hidden-marks ()
  (let ((first (list :id 'a :label "alpha"))
        (second (list :id 'b :label "beta")) received)
    (emacs-tui-action-test--with
        (list (emacs-tui-view :id 'a :items (list first second) :multi-select t
                              :on-select (lambda (_app item) (setq received item))))
      (emacs-tui-toggle-mark session)
      (emacs-tui-set-query session 'a "beta")
      (should (eq second (emacs-tui-select session)))
      (should (eq second received))
      (should (equal (list first) (emacs-tui-marked-items session)))
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-action-pure-availability-yields-to-close-timer ()
  (let (timer fired ran)
    (unwind-protect
        (emacs-tui-action-test--with
            (list (emacs-tui-view
                   :id 'a :items '("a")
                   :actions (list (emacs-tui-action
                                   :id 'run
                                   :enabled (lambda (&rest _)
                                              (let ((deadline (+ (float-time) 2)))
                                                (while (and (not fired)
                                                            (< (float-time) deadline))
                                                  (accept-process-output nil 0.001)))
                                              t)
                                   :run (lambda (&rest _) (setq ran t))))))
          (setq timer (run-at-time 0 nil (lambda ()
                                          (setq fired t)
                                          (emacs-tui-close session))))
          (should-error (emacs-tui-act session 'run) :type 'user-error)
          (should fired)
          (should-not ran))
      (when timer (cancel-timer timer)))))

(ert-deftest emacs-tui-action-availability-refresh-retains-original-targets ()
  (let* ((objects (list (list :id 'a :label "a"))) received)
    (emacs-tui-action-test--with
        (list (emacs-tui-view
               :id 'a :items objects :multi-select t
               :actions (list (emacs-tui-action
                               :id 'run
                               :enabled (lambda (app _items)
                                          (emacs-tui-update app 'a :items
                                                            (copy-sequence objects))
                                          t)
                               :run (lambda (_app items) (setq received items))))))
      (emacs-tui-toggle-mark session)
      (emacs-tui-act session 'run)
      (should (eq (car objects) (car received))))))

(provide 'emacs-tui-action-test)
;;; emacs-tui-action-test.el ends here
