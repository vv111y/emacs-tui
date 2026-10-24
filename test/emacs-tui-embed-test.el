;;; emacs-tui-embed-test.el --- Borrowed window regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Embedded panels own their view buffer, never their application's window.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-embed-test--host (&rest body)
  "Evaluate BODY with an application buffer and window, then clean up."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let ((host (generate-new-buffer " *embed-host*"))
           (window (selected-window)) session)
       (unwind-protect
           (progn
             (switch-to-buffer host)
             (insert (make-string 200 ?x))
             (goto-char 80)
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p host) (kill-buffer host))))))

(ert-deftest emacs-tui-embed-restores-host-window-and-buffer ()
  (emacs-tui-embed-test--host
    (set-window-hscroll window 4)
    (set-window-parameter window 'application-data 'retained)
    (let ((windows (window-list)) (point (point)) (text (buffer-string)))
      (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a :items '("A"))))
      (should (equal windows (window-list)))
      (should (equal "A" (emacs-tui-current-item session)))
      (let ((view-buffer (window-buffer window)))
        (emacs-tui-close session)
        (should-not (buffer-live-p view-buffer)))
      (should (window-live-p window))
      (should (eq host (window-buffer window)))
      (should (= point (window-point window)))
      (should (= 4 (window-hscroll window)))
      (should (eq 'retained (window-parameter window 'application-data)))
      (should (equal text (with-current-buffer host (buffer-string))))
      (should-not (window-parameter window 'emacs-tui-session)))))

(ert-deftest emacs-tui-embed-tracks-edits-to-hidden-host ()
  (emacs-tui-embed-test--host
    (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a)))
    (with-current-buffer host (goto-char 1) (insert "new"))
    (emacs-tui-close session)
    (should (= 83 (window-point window)))
    (should (with-current-buffer host (buffer-modified-p)))))

(ert-deftest emacs-tui-embed-preserves-repurposed-window ()
  (emacs-tui-embed-test--host
    (let ((foreign (generate-new-buffer " *embed-foreign*")))
      (unwind-protect
          (progn
            (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a)))
            (set-window-buffer window foreign)
            (should-not (emacs-tui-refresh session))
            (should (eq foreign (window-buffer window)))
            (should (window-live-p window)))
        (kill-buffer foreign)))))

(ert-deftest emacs-tui-embed-survives-host-buffer-death ()
  (emacs-tui-embed-test--host
    (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a)))
    (kill-buffer host)
    (should (emacs-tui-refresh session))
    (emacs-tui-close session)
    (should (window-live-p window))
    (should (buffer-live-p (window-buffer window)))
    (should-not (buffer-local-value 'emacs-tui--session (window-buffer window)))))

(ert-deftest emacs-tui-embed-closes-on-host-window-death ()
  (emacs-tui-embed-test--host
    (let ((closed 0))
      (split-window-right)
      (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a)
                                   :on-close (lambda (_) (cl-incf closed))))
      (delete-window window)
      (emacs-tui--window-state-changed)
      (should-not (emacs-tui-live-p session))
      (should (= 1 closed))
      (should (buffer-live-p host)))))

(ert-deftest emacs-tui-embed-rejects-dedicated-and-claimed-windows ()
  (emacs-tui-embed-test--host
    (set-window-dedicated-p window t)
    (unwind-protect
        (should-error (emacs-tui-embed :view (emacs-tui-view :id 'a)))
      (set-window-dedicated-p window nil))
    (should (eq host (window-buffer window)))
    (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a)))
    (should-error (emacs-tui-embed :window window :view (emacs-tui-view :id 'b)))
    (should (emacs-tui-live-p session))))

(ert-deftest emacs-tui-embed-reflow-and-actions-retain-host ()
  (emacs-tui-embed-test--host
    (let ((count 0))
      (setq session (emacs-tui-embed
                     :view (emacs-tui-view :id 'a :items '("A" "B")
                                           :multi-select t
                                           :on-select (lambda (_ _item) (cl-incf count)))))
      (execute-kbd-macro (kbd "n C-c C-m RET"))
      (split-window-right)
      (should (emacs-tui-refresh session))
      (should (equal '("B") (emacs-tui-marked-items session)))
      (should (= 1 count))
      (emacs-tui-close session)
      (should (window-live-p window))
      (should (= 2 (length (window-list)))))))

(ert-deftest emacs-tui-embed-startup-failure-restores-host ()
  (emacs-tui-embed-test--host
    (let ((before (buffer-list)) (closed 0))
      (cl-letf (((symbol-function 'emacs-tui--render-view)
                 (lambda (&rest _) (error "Render failure"))))
        (should-error (emacs-tui-embed :view (emacs-tui-view :id 'a)
                                       :on-close (lambda (_) (cl-incf closed)))))
      (should (= 1 closed))
      (should (eq host (window-buffer window)))
      (should (= 80 (window-point window)))
      (should (equal before (buffer-list))))))

(ert-deftest emacs-tui-embed-killed-view-restores-host ()
  (emacs-tui-embed-test--host
    (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a)))
    (kill-buffer (window-buffer window))
    (should-not (emacs-tui-live-p session))
    (should (eq host (window-buffer window)))))

(ert-deftest emacs-tui-embed-explicit-window-leaves-other-window-intact ()
  (emacs-tui-embed-test--host
    (let ((other (split-window-right)) (other-buffer (get-buffer-create " *embed-other*")))
      (unwind-protect
          (progn
            (set-window-buffer other other-buffer)
            (setq session (emacs-tui-embed :window other :view (emacs-tui-view :id 'a)))
            (should (eq (selected-window) other))
            (should (eq (window-buffer window) host))
            (emacs-tui-close session)
            (should (eq (window-buffer other) other-buffer))
            (should (eq (window-buffer window) host)))
        (kill-buffer other-buffer)))))

(ert-deftest emacs-tui-embed-async-disposal-preserves-host ()
  (emacs-tui-embed-test--host
    (let ((stopped 0) publish)
      (setq session (emacs-tui-embed
                     :view (emacs-tui-view :id 'a) :debounce 60
                     :provider (lambda (_app query emit _fail)
                                 (should (equal query ""))
                                 (setq publish emit)
                                 (funcall emit 'a :items '("Async"))
                                 (lambda () (cl-incf stopped)))))
      (let ((request (emacs-tui--workspace-request session)))
        (cancel-timer (emacs-tui--request-timer request))
        (emacs-tui--start-provider request))
      (should (equal "Async" (emacs-tui-current-item session)))
      (emacs-tui-close session)
      (should (= 1 stopped))
      (should-not (funcall publish 'a :items '("Late")))
      (should (eq host (window-buffer window))))))

(ert-deftest emacs-tui-embed-close-handles-new-window-dedication ()
  (emacs-tui-embed-test--host
    (setq session (emacs-tui-embed :view (emacs-tui-view :id 'a)))
    (let ((view-buffer (window-buffer window)))
      (set-window-dedicated-p window t)
      (unwind-protect
          (progn
            (emacs-tui-close session)
            (should (eq host (window-buffer window)))
            (should (window-dedicated-p window))
            (should-not (buffer-live-p view-buffer)))
        (set-window-dedicated-p window nil)))))

(defun emacs-tui-embed-test--foreign-state (window)
  "Capture the unrelated display state in WINDOW."
  (list (window-buffer window) (window-point window) (window-start window)
        (window-hscroll window) (window-vscroll window t)
        (with-current-buffer (window-buffer window)
          (list (point) (buffer-string) (buffer-modified-p)))))

(ert-deftest emacs-tui-embed-late-list-renders-preserve-repurposed-window ()
  (emacs-tui-embed-test--host
    (let ((foreign (generate-new-buffer " *embed-foreign-update*")))
      (unwind-protect
          (progn
            (setq session (emacs-tui-embed
                           :view (emacs-tui-view :id 'a :multi-select t
                                                 :items '("alpha" "beta"))))
            (with-current-buffer foreign
              (insert (make-string 200 ?x))
              (set-buffer-modified-p nil))
            (set-window-buffer window foreign)
            (set-window-point window 60)
            (set-window-hscroll window 4)
            (let ((before (emacs-tui-embed-test--foreign-state window)))
              ;; These can run synchronously before the window-state hook
              ;; notices that the user has repurposed the borrowed window.
              (emacs-tui-update session 'a :items '("gamma" "delta"))
              (should (equal "gamma" (emacs-tui-current-item session 'a)))
              (should (equal before (emacs-tui-embed-test--foreign-state window)))
              (should (emacs-tui-toggle-mark session))
              (should (equal before (emacs-tui-embed-test--foreign-state window)))
              (emacs-tui-clear-marks session)
              (should (equal before (emacs-tui-embed-test--foreign-state window)))
              (emacs-tui-next-item session)
              (should (equal before (emacs-tui-embed-test--foreign-state window)))
              (emacs-tui-close session)
              (should (equal before (emacs-tui-embed-test--foreign-state window)))))
        (kill-buffer foreign)))))

(ert-deftest emacs-tui-embed-late-provider-preview-preserves-repurposed-window ()
  (let (publish (cancelled 0))
    (emacs-tui-embed-test--host
      (let ((foreign (generate-new-buffer " *embed-foreign-preview*")))
        (unwind-protect
            (progn
              (setq session
                    (emacs-tui-embed
                     :view (emacs-tui-view :id 'a :text "Original preview")
                     :debounce 60
                     :provider (lambda (_ _query emit _fail)
                                 (setq publish emit)
                                 (lambda () (cl-incf cancelled)))))
              (let ((request (emacs-tui--workspace-request session)))
                (cancel-timer (emacs-tui--request-timer request))
                (emacs-tui--start-provider request))
              (with-current-buffer foreign
                (insert (make-string 200 ?x))
                (set-buffer-modified-p nil))
              (set-window-buffer window foreign)
              (set-window-point window 80)
              (let ((before (emacs-tui-embed-test--foreign-state window)))
                (should (funcall publish 'a :text "New provider preview"))
                (should (equal "New provider preview"
                               (with-current-buffer
                                   (emacs-tui--view-buffer (emacs-tui--focused-view session))
                                 (buffer-string))))
                (should (equal before (emacs-tui-embed-test--foreign-state window)))
                ;; Normal ownership invalidation still closes/cancels once.
                (should-not (emacs-tui-refresh session))
                (should (= cancelled 1))
                (should-not (funcall publish 'a :text "Obsolete preview"))
                (should (equal before (emacs-tui-embed-test--foreign-state window)))))
          (kill-buffer foreign))))))

(provide 'emacs-tui-embed-test)
;;; emacs-tui-embed-test.el ends here
