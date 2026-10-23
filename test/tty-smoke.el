;;; tty-smoke.el --- Exercise a real terminal session -*- lexical-binding: t; -*-
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defun emacs-tui-test--terminal-smoke ()
  (condition-case err
      (let* ((source (get-buffer-create "*terminal smoke source*"))
             (backend (if (featurep 'tty-child-frames) 'child-frame 'windows))
             session)
        (switch-to-buffer source)
        (erase-buffer)
        (insert "origin:")
        (setq session
              (emacs-tui-open
               :backend backend
               :views (list (emacs-tui-view :id 'items :items '("alpha" "beta")
                                           :on-select
                                           (lambda (workspace item)
                                             (emacs-tui-update workspace 'preview
                                                               :text item)))
                            (emacs-tui-view :id 'preview :text "pending"))
               :on-commit (lambda (_ item marker) (goto-char marker) (insert item))))
        (cl-assert (eq (emacs-tui--workspace-backend session) backend))
        (cl-assert (eq (current-buffer) (emacs-tui--workspace-query-buffer session)))
        (execute-kbd-macro "alp")
        (cl-assert (equal (emacs-tui-query session) "alp"))
        (cl-assert (equal (emacs-tui-current-item session) "alpha"))
        (execute-kbd-macro (kbd "RET"))
        (cl-assert (equal (emacs-tui--view-text
                           (cadr (emacs-tui--workspace-views session))) "alpha"))
        (redisplay t)
        (cl-assert (equal (with-current-buffer source (buffer-string)) "origin:"))
        (execute-kbd-macro (kbd "C-c C-c"))
        (cl-assert (equal (with-current-buffer source (buffer-string)) "origin:alpha"))
        (cl-assert (null emacs-tui--sessions))
        (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
          (insert (format "PASS Emacs %s; real TTY; backend=%s\n" emacs-version backend)))
        (kill-emacs 0))
    ((error quit)
     (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
       (insert (format "FAIL: %S\n" err)))
     (kill-emacs 1))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-test--terminal-smoke)))
