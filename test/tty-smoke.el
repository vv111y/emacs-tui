;;; tty-smoke.el --- Exercise typing and resizing in a real TTY -*- lexical-binding: t; -*-
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defvar emacs-tui-test--smoke-session nil)
(defvar emacs-tui-test--smoke-phase 0)
(defvar emacs-tui-test--smoke-attempts 0)
(defvar emacs-tui-test--smoke-small-width nil)
(defvar emacs-tui-test--smoke-result-timer nil)
(defvar emacs-tui-test--smoke-cancellations 0)

(defun emacs-tui-test--smoke-failure (err)
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
    (insert (format "FAIL: %S\n" err)))
  (kill-emacs 1))

(defun emacs-tui-test--smoke-check-resize ()
  (condition-case err
      (let* ((session emacs-tui-test--smoke-session)
             (parent (emacs-tui--workspace-origin-frame session))
             (child (emacs-tui--workspace-frame session))
             (backend (emacs-tui--workspace-backend session))
             (phase emacs-tui-test--smoke-phase)
             (width (if (= phase 1) 90 140))
             (height (if (= phase 1) 30 45)))
        (cl-incf emacs-tui-test--smoke-attempts)
        (when (> emacs-tui-test--smoke-attempts 100)
          (error "Resize phase %s did not settle: parent=%sx%s child=%S"
                 phase (frame-width parent) (frame-height parent)
                 (when (frame-live-p child) (cons (frame-width child) (frame-height child)))))
        (redisplay t)
        (when (and (= (frame-width parent) width)
                   (<= (- height 2) (frame-height parent) height)
                   (or (not child)
                       (and (< (frame-width child) width) (< (frame-height child) height)
                            (or (= phase 1) (> (frame-width child) emacs-tui-test--smoke-small-width)))))
          (cl-assert (emacs-tui--workspace-active session))
          (cl-assert (equal (emacs-tui--workspace-geometry session)
                            (emacs-tui--geometry session)))
          (cl-assert (= 2 (window-total-height (emacs-tui--workspace-root session))))
          (cl-assert (equal (emacs-tui-query session) "a"))
          (cl-assert (equal (emacs-tui-current-item session) "beta"))
          (cl-assert (equal (emacs-tui-marked-items session) '("alpha" "beta")))
          (cl-assert (= (with-current-buffer (emacs-tui--workspace-query-buffer session) (point)) 1))
          (cl-assert (equal (with-current-buffer "*terminal smoke source*" (buffer-string)) "origin:"))
          (cl-assert (= (with-current-buffer "*terminal smoke source*" (point)) 8))
          (when child
            (let ((position (frame-position child)))
              (cl-assert (>= (car position) 0))
              (cl-assert (>= (cdr position) 0))
              (cl-assert (<= (+ (car position) (frame-width child)) (frame-width parent)))
              (cl-assert (<= (+ (cdr position) (frame-height child)) (frame-height parent)))))
          (if (= phase 1)
              (progn
                (setq emacs-tui-test--smoke-small-width (when child (frame-width child))
                      emacs-tui-test--smoke-phase 2
                      emacs-tui-test--smoke-attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
            (execute-kbd-macro (kbd "C-c C-c"))
            (cl-assert (equal (with-current-buffer "*terminal smoke source*" (buffer-string)) "origin:alpha|beta"))
            (cl-assert (null emacs-tui--sessions))
            (cl-assert (> emacs-tui-test--smoke-cancellations 0))
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; real TTY; backend=%s; async=passed; marks=passed; resize=120x40->90x30->140x45\n"
                              emacs-version backend)))
            (kill-emacs 0))))
    ((error quit) (emacs-tui-test--smoke-failure err))))

(defun emacs-tui-test--smoke-check-results ()
  (condition-case err
      (let ((session emacs-tui-test--smoke-session))
        (cl-incf emacs-tui-test--smoke-attempts)
        (when (> emacs-tui-test--smoke-attempts 100)
          (error "Asynchronous results did not arrive"))
        (when (emacs-tui-current-item session)
          (cancel-timer emacs-tui-test--smoke-result-timer)
          (cl-assert (equal (emacs-tui-query session) "a"))
          (cl-assert (equal (emacs-tui-current-item session) "alpha"))
          (execute-kbd-macro (kbd "C-c C-m M-n C-c C-m RET C-a"))
          (cl-assert (equal (emacs-tui-current-item session) "beta"))
          (cl-assert (equal (emacs-tui--view-text (cadr (emacs-tui--workspace-views session))) "beta"))
          (setq emacs-tui-test--smoke-phase 1
                emacs-tui-test--smoke-attempts 0)
          (redisplay t)
          (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))
          (run-at-time 0.05 0.05 #'emacs-tui-test--smoke-check-resize)))
    ((error quit) (emacs-tui-test--smoke-failure err))))

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
               :views (list (emacs-tui-view :id 'items :multi-select t
                                           :on-select
                                           (lambda (workspace item)
                                             (emacs-tui-update workspace 'preview :text item)))
                            (emacs-tui-view :id 'preview :text "pending"))
               :provider
               (lambda (_ query publish fail)
                 (let ((timer
                        (run-at-time
                         0.01 nil
                         (lambda ()
                           (condition-case provider-error
                               (progn
                                 (cl-assert (equal query "a"))
                                 (funcall publish 'items :items '("alpha" "beta")))
                             (error (funcall fail provider-error)))))))
                   (lambda ()
                     (cl-incf emacs-tui-test--smoke-cancellations)
                     (cancel-timer timer))))
               :on-commit
               (lambda (workspace item marker)
                 (goto-char marker)
                 (insert (mapconcat #'identity
                                    (or (emacs-tui-marked-items workspace) (list item))
                                    "|")))))
        (cl-assert (eq (emacs-tui--workspace-backend session) backend))
        (cl-assert (eq (current-buffer) (emacs-tui--workspace-query-buffer session)))
        (execute-kbd-macro "a")
        (setq emacs-tui-test--smoke-session session
              emacs-tui-test--smoke-result-timer
              (run-at-time 0.05 0.05 #'emacs-tui-test--smoke-check-results)))
    ((error quit) (emacs-tui-test--smoke-failure err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-test--terminal-smoke)))
