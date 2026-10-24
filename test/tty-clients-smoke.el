;;; tty-clients-smoke.el --- Two terminal clients in one Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; A real terminal Emacs starts a private server.  A second PTY attaches through
;; emacsclient.  The Python driver sends actual keys and resizes each terminal
;; separately; no keyboard macros or synthetic frames substitute for clients.

;;; Code:
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'server)
(require 'emacs-tui)

(defvar emacs-tui-test--clients nil)
(defvar emacs-tui-test--clients-phase 'starting)
(defvar emacs-tui-test--clients-timer nil)
(defvar emacs-tui-test--clients-commands nil)

(defun emacs-tui-test--clients-record (kind details)
  "Record bounded diagnostic event KIND with DETAILS and native focus."
  (push (list kind details (selected-frame)
              (mapcar (lambda (entry)
                        (let ((app (plist-get (cdr entry) :session)))
                          (list (car entry)
                                (and app (emacs-tui--workspace-tty-focus app)))))
                      emacs-tui-test--clients)
              (copy-tree emacs-tui--tty-deleting-frames))
        emacs-tui-test--clients-commands)
  (setq emacs-tui-test--clients-commands
        (seq-take emacs-tui-test--clients-commands 80))
  (emacs-tui-test--clients-write
   "commands" (pp-to-string (reverse emacs-tui-test--clients-commands))))

(defun emacs-tui-test--clients-command ()
  "Retain a bounded native input trace for failure diagnostics."
  (push (list emacs-tui-test--clients-phase
              (terminal-name (frame-terminal)) (frame-parameter nil 'name)
              (buffer-name) last-command-event this-command)
        emacs-tui-test--clients-commands)
  (setq emacs-tui-test--clients-commands
        (seq-take emacs-tui-test--clients-commands 80))
  (emacs-tui-test--clients-write
   "commands" (pp-to-string (reverse emacs-tui-test--clients-commands))))

(defun emacs-tui-test--clients-write (name text)
  "Write TEXT to coordination file NAME in the private test directory."
  (let* ((path (expand-file-name name (getenv "EMACS_TUI_CLIENT_DIR")))
         (temporary (concat path ".tmp")))
    (with-temp-file temporary (insert text))
    (rename-file temporary path t)))

(defun emacs-tui-test--clients-fail (err)
  "Report ERR and stop the dedicated test process."
  (emacs-tui-test--clients-write "result" (format "FAIL clients phase=%s: %S\n"
                                               emacs-tui-test--clients-phase err))
  (kill-emacs 1))

(defun emacs-tui-test--clients-state (id)
  "Return the recorded client state for ID."
  (cdr (assq id emacs-tui-test--clients)))

(defun emacs-tui-test--clients-ready (phase)
  "Record completed PHASE for the external PTY driver."
  (setq emacs-tui-test--clients-phase phase)
  (emacs-tui-test--clients-write "ready" (symbol-name phase)))

(defun emacs-tui-test--clients-create (id)
  "Create an independent interface for terminal client ID."
  (let* ((parent (selected-frame))
         (host (generate-new-buffer (format " *client-%s-host*" id)))
         (state (list :parent parent :terminal (frame-terminal parent)
                      :host host :closed 0 :cancelled 0 :changes 0
                      :session nil :buffers nil :timer nil :publish nil
                      :edited-changes nil))
         (map (make-sparse-keymap)))
    (switch-to-buffer host)
    (insert (format "host-%s edited" id))
    (define-key map (kbd "C-c C-e") #'emacs-tui-test--clients-ack)
    (define-key map (kbd "C-c C-d") #'emacs-tui-test--clients-delete)
    (push (cons id state) emacs-tui-test--clients)
    (let ((session
           (emacs-tui-mount
            :backend (if (featurep 'tty-child-frames) 'child-frame 'windows)
            :keymap map
            :views (list (emacs-tui-input
                          :id 'body :title (symbol-name id)
                          :on-change (lambda (_session _view _value)
                                       (cl-incf (plist-get state :changes))))
                         (emacs-tui-view :id 'items :multi-select t))
            :debounce 0
            :provider (lambda (_session _query publish _fail)
                        (let ((timer (run-at-time 60 60 #'ignore)))
                          (setf (plist-get state :timer) timer
                                (plist-get state :publish) publish)
                          (funcall publish 'items :items '("one" "two"))
                          (lambda ()
                            (cl-incf (plist-get state :cancelled))
                            (cancel-timer timer))))
            :on-close (lambda (_session)
                        (cl-incf (plist-get state :closed))
                        (emacs-tui-test--clients-record 'close-callback id)))))
      (setf (plist-get state :session) session
            (plist-get state :buffers)
            (mapcar #'emacs-tui--view-buffer (emacs-tui--workspace-views session)))
      (cl-assert (eq parent (emacs-tui--workspace-origin-frame session)))
      (when-let* ((child (emacs-tui--workspace-frame session)))
        (cl-assert (eq parent (frame-parent child)))
        (cl-assert (eq (frame-terminal parent) (frame-terminal child))))
      state)))

(defun emacs-tui-test--clients-isolated ()
  "Check both live surfaces and native resources belong to distinct terminals."
  (let* ((a (emacs-tui-test--clients-state 'A))
         (b (emacs-tui-test--clients-state 'B)))
    (cl-assert (not (eq (plist-get a :terminal) (plist-get b :terminal))))
    (dolist (state (list a b))
      (let ((session (plist-get state :session)))
        (cl-assert (emacs-tui-live-p session))
        (cl-assert (= 0 (plist-get state :closed)))
        (cl-assert (= 0 (plist-get state :cancelled)))
        (cl-assert (memq (plist-get state :timer) timer-list))
        (dolist (view (emacs-tui--workspace-views session))
          (let ((window (emacs-tui--view-window view)))
            (cl-assert (window-live-p window))
            (cl-assert (eq (plist-get state :terminal)
                           (frame-terminal (window-frame window))))
            (cl-assert (eq (window-buffer window) (emacs-tui--view-buffer view)))))))
    (cl-assert (not (cl-intersection (plist-get a :buffers) (plist-get b :buffers))))))

(defun emacs-tui-test--clients-join ()
  "Attach the second real terminal and create its interface."
  (condition-case err
      (progn
        (cl-assert (eq emacs-tui-test--clients-phase 'first-ready))
        (emacs-tui-test--clients-create 'B)
        (setq emacs-tui-test--clients-phase 'joining))
    ((error quit) (emacs-tui-test--clients-fail err)))
  nil)

(defun emacs-tui-test--clients-ack ()
  "Acknowledge native keys from the current client and check isolation."
  (interactive)
  (condition-case err
      (let* ((a (emacs-tui-test--clients-state 'A))
             (b (emacs-tui-test--clients-state 'B))
             (sa (plist-get a :session)) (sb (plist-get b :session)))
        (pcase emacs-tui-test--clients-phase
          ('both-ready
           (cl-assert (eq sa (emacs-tui-current-session)))
           (cl-assert (equal "alpha" (emacs-tui-input-value sa 'body)))
           (cl-assert (equal "" (emacs-tui-input-value sb 'body)))
           (emacs-tui-test--clients-isolated)
           (emacs-tui-test--clients-ready 'first-edited))
          ('first-edited
           (cl-assert (eq sb (emacs-tui-current-session)))
           (cl-assert (equal "bravo" (emacs-tui-input-value sb 'body)))
           (let* ((window (selected-window))
                  (frame (selected-frame))
                  (buffer (window-buffer window))
                  (point (window-point window))
                  (tick (buffer-chars-modified-tick)))
             ;; These are background operations on A while B owns native focus.
             (emacs-tui-update sa 'items :items '("one" "two" "three"))
             (emacs-tui-set-query sa 'items "two")
             (emacs-tui-mark-all sa 'items)
             (emacs-tui-set-query sa 'items "")
             (emacs-tui-set-selection sa 'items "three")
             (emacs-tui-update sa 'body :title "A background 50%busy")
             (emacs-tui-refresh sa)
             (cl-assert (eq window (selected-window)))
             (cl-assert (eq frame (selected-frame)))
             (cl-assert (eq buffer (current-buffer)))
             (cl-assert (= point (window-point window)))
             (cl-assert (= tick (buffer-chars-modified-tick))))
           (setf (plist-get a :edited-changes) (plist-get a :changes)
                 (plist-get b :edited-changes) (plist-get b :changes))
           (cl-assert (> (plist-get a :changes) 0))
           (cl-assert (> (plist-get b :changes) 0))
           (emacs-tui-test--clients-isolated)
           (emacs-tui-test--clients-ready 'second-edited))
          ('second-resized
           (cl-assert (eq sa (emacs-tui-current-session)))
           (cl-assert (equal "alpha" (emacs-tui-input-value sa 'body)))
           (cl-assert (= 2 (point)))
           (emacs-tui-test--clients-ready 'first-prefix))
          ('second-deleted
           (cl-assert (eq sa (emacs-tui-current-session)))
           (cl-assert (equal "alpha!" (emacs-tui-input-value sa 'body)))
           (cl-assert (equal '("two") (emacs-tui-marked-items sa 'items)))
           (cl-assert (equal "three" (emacs-tui-current-item sa 'items)))
           (cl-assert (> (plist-get a :changes) (plist-get a :edited-changes)))
           (cl-assert (= (plist-get b :changes) (plist-get b :edited-changes)))
           (emacs-tui-close sa)
           (emacs-tui-close sb)
           (dolist (state (list a b))
             (cl-assert (= 1 (plist-get state :closed)))
             (cl-assert (= 1 (plist-get state :cancelled)))
             (cl-assert (not (memq (plist-get state :timer) timer-list)))
             (dolist (buffer (plist-get state :buffers))
               (cl-assert (not (buffer-live-p buffer))))
             (cl-assert (equal (format "host-%s edited" (car (rassq state emacs-tui-test--clients)))
                               (with-current-buffer (plist-get state :host) (buffer-string)))))
           (cl-assert (null emacs-tui--sessions))
           (cl-assert (not (memq #'emacs-tui--frame-deleted delete-frame-functions)))
           (cl-assert (not (memq #'emacs-tui--window-state-changed window-state-change-hook)))
           (cl-assert (not (memq #'emacs-tui--remember-tty-focus post-command-hook)))
           (cl-assert (not (advice-member-p #'emacs-tui--tty-switch-frame #'handle-switch-frame)))
           (cl-assert (not (memq #'emacs-tui--tty-frame-deleting delete-frame-functions)))
           (cl-assert (not (memq #'emacs-tui--tty-frame-deleted after-delete-frame-functions)))
           (cl-assert (null emacs-tui--tty-deleting-frames))
           (cl-assert (= 1 (length (frame-list))))
           (emacs-tui-test--clients-write
            "result" (format "PASS Emacs %s; two real terminals; backend=%s; native input, background updates, independent resize, frame deletion, stale publication and cleanup\n"
                             emacs-version (emacs-tui--workspace-backend sa)))
           (kill-emacs 0))
          (_ (error "Unexpected native acknowledgement"))))
    ((error quit) (emacs-tui-test--clients-fail err))))

(defun emacs-tui-test--clients-delete ()
  "Delete B's parent frame as an explicit native client command."
  (interactive)
  (condition-case err
      (let* ((b (emacs-tui-test--clients-state 'B))
             (session (plist-get b :session)))
        (cl-assert (eq emacs-tui-test--clients-phase 'first-prefix))
        (cl-assert (eq session (emacs-tui-current-session)))
        (delete-frame (plist-get b :parent) t))
    ((error quit) (emacs-tui-test--clients-fail err))))

(defun emacs-tui-test--clients-poll ()
  "Observe actual client geometry and disposal without forcing reflow."
  (condition-case err
      (let* ((a (emacs-tui-test--clients-state 'A))
             (b (emacs-tui-test--clients-state 'B))
             (sa (plist-get a :session)) (sb (plist-get b :session))
             (phase emacs-tui-test--clients-phase))
        (when (and (eq phase 'joining)
                   (plist-get a :publish) (plist-get b :publish)
                   (memq (plist-get a :timer) timer-list)
                   (memq (plist-get b :timer) timer-list))
          (emacs-tui-test--clients-isolated)
          (emacs-tui-test--clients-ready 'both-ready))
        (when (memq phase '(second-edited first-resized))
          (redisplay t)
          (when (and (= 90 (frame-width (plist-get a :parent)))
                     (<= 28 (frame-height (plist-get a :parent)) 30)
                     (= (if (eq phase 'second-edited) 100 140)
                        (frame-width (plist-get b :parent)))
                     (let ((height (if (eq phase 'second-edited) 35 45)))
                       (<= (- height 2) (frame-height (plist-get b :parent)) height))
                     (equal (emacs-tui--workspace-geometry sa) (emacs-tui--geometry sa))
                     (equal (emacs-tui--workspace-geometry sb) (emacs-tui--geometry sb)))
            (emacs-tui-test--clients-isolated)
            (cl-assert (equal "alpha" (emacs-tui-input-value sa 'body)))
            (cl-assert (equal "bravo" (emacs-tui-input-value sb 'body)))
            (emacs-tui-test--clients-ready
             (if (eq phase 'second-edited) 'first-resized 'second-resized))))
        (when (and (eq phase 'first-prefix) (not (frame-live-p (plist-get b :parent))))
          (cl-assert (not (emacs-tui-live-p sb)))
          (cl-assert (emacs-tui-live-p sa))
          (cl-assert (= 1 (plist-get b :closed)))
          (cl-assert (= 1 (plist-get b :cancelled)))
          (cl-assert (= 0 (plist-get a :closed)))
          (cl-assert (memq (plist-get a :timer) timer-list))
          (cl-assert (not (funcall (plist-get b :publish) 'items :items '("stale"))))
          (cl-assert (equal "three" (emacs-tui-current-item sa 'items)))
          (emacs-tui-test--clients-ready 'second-deleted)))
    ((error quit) (emacs-tui-test--clients-fail err))))

(defun emacs-tui-test--clients-start ()
  "Start the private server and first terminal's interface."
  (condition-case err
      (progn
        (setq server-socket-dir (expand-file-name "socket" (getenv "EMACS_TUI_CLIENT_DIR"))
              server-name "tui")
        (make-directory server-socket-dir t)
        (set-file-modes server-socket-dir #o700)
        (server-start)
        (add-hook 'pre-command-hook #'emacs-tui-test--clients-command)
        (advice-add #'emacs-tui--remember-tty-focus :before
                    (lambda (&rest _) (emacs-tui-test--clients-record 'remember-before nil)))
        (advice-add #'emacs-tui--remember-tty-focus :after
                    (lambda (&rest _) (emacs-tui-test--clients-record 'remember-after nil)))
        (advice-add #'emacs-tui--tty-frame-deleting :before
                    (lambda (frame) (emacs-tui-test--clients-record 'deleting-before frame)))
        (advice-add #'emacs-tui--tty-frame-deleting :after
                    (lambda (frame) (emacs-tui-test--clients-record 'deleting-after frame)))
        (advice-add #'emacs-tui--tty-frame-deleted :before
                    (lambda (frame) (emacs-tui-test--clients-record 'deleted-before frame)))
        (advice-add #'emacs-tui--tty-frame-deleted :after
                    (lambda (frame) (emacs-tui-test--clients-record 'deleted-after frame)))
        (emacs-tui-test--clients-create 'A)
        (setq emacs-tui-test--clients-timer
              (run-at-time 0.05 0.05 #'emacs-tui-test--clients-poll))
        (emacs-tui-test--clients-ready 'first-ready))
    ((error quit) (emacs-tui-test--clients-fail err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-test--clients-start)))

;;; tty-clients-smoke.el ends here
