;;; tty-hangup-smoke.el --- Abrupt terminal client cleanup -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; A real terminal Emacs starts a private server and an emacsclient attaches on
;; another PTY.  The driver kills the client process group without asking Emacs
;; to delete its frame, then verifies disposal and survivor input on the server
;; terminal.  Synthetic frames do not substitute for this native boundary.

;;; Code:
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'server)
(require 'emacs-tui)

(defvar emacs-tui-test--hangup nil)
(defvar emacs-tui-test--hangup-phase 'starting)
(defvar emacs-tui-test--hangup-timer nil)
(defvar emacs-tui-test--hangup-events nil)

(defun emacs-tui-test--hangup-write (name text)
  "Write TEXT to coordination file NAME atomically."
  (let* ((path (expand-file-name name (getenv "EMACS_TUI_HANGUP_DIR")))
         (temporary (concat path ".tmp")))
    (with-temp-file temporary (insert text))
    (rename-file temporary path t)))

(defun emacs-tui-test--hangup-record (kind details)
  "Record bounded diagnostic event KIND with DETAILS."
  (push (list kind details emacs-tui-test--hangup-phase
              (selected-frame) (buffer-name)
              (copy-tree emacs-tui--tty-deleting-frames))
        emacs-tui-test--hangup-events)
  (setq emacs-tui-test--hangup-events
        (seq-take emacs-tui-test--hangup-events 80))
  (emacs-tui-test--hangup-write
   "events" (pp-to-string (reverse emacs-tui-test--hangup-events))))

(defun emacs-tui-test--hangup-command ()
  "Retain a bounded trace of native commands."
  (emacs-tui-test--hangup-record
   'command
   (list (terminal-name (frame-terminal)) (frame-parameter nil 'name)
         last-command-event this-command)))

(defun emacs-tui-test--hangup-fail (err)
  "Report ERR and stop the dedicated test process."
  (emacs-tui-test--hangup-write
   "result" (format "FAIL hangup phase=%s: %S\n" emacs-tui-test--hangup-phase err))
  (kill-emacs 1))

(defun emacs-tui-test--hangup-state (id)
  "Return state for terminal ID."
  (cdr (assq id emacs-tui-test--hangup)))

(defun emacs-tui-test--hangup-ready (phase)
  "Publish completed PHASE to the external PTY driver."
  (setq emacs-tui-test--hangup-phase phase)
  (emacs-tui-test--hangup-write "ready" (symbol-name phase)))

(defun emacs-tui-test--hangup-create (id)
  "Mount an independent persistent interface for terminal ID."
  (let* ((parent (selected-frame))
         (host (generate-new-buffer (format " *hangup-%s-host*" id)))
         (state (list :parent parent :terminal (frame-terminal parent)
                      :host host :session nil :buffers nil :timer nil
                      :publish nil :closed 0 :cancelled 0 :changes 0
                      :edited-changes nil))
         (map (make-sparse-keymap)))
    (switch-to-buffer host)
    (insert (format "host-%s preserved" id))
    (define-key map (kbd "C-c C-e") #'emacs-tui-test--hangup-ack)
    (push (cons id state) emacs-tui-test--hangup)
    (let ((session
           (emacs-tui-mount
            :backend (if (featurep 'tty-child-frames) 'child-frame 'windows)
            :keymap map
            :views (list
                    (emacs-tui-input
                     :id 'body :title (symbol-name id)
                     :on-change (lambda (_session _view _value)
                                  (cl-incf (plist-get state :changes))))
                    (emacs-tui-view :id 'items :multi-select t))
            :debounce 0
            :provider
            (lambda (_session _query publish _fail)
              (let ((timer (run-at-time 60 60 #'ignore)))
                (setf (plist-get state :timer) timer
                      (plist-get state :publish) publish)
                (funcall publish 'items :items '("one" "two"))
                (lambda ()
                  (cl-incf (plist-get state :cancelled))
                  (cancel-timer timer))))
            :on-close (lambda (_session)
                        (cl-incf (plist-get state :closed))
                        (emacs-tui-test--hangup-record 'close id)))))
      (setf (plist-get state :session) session
            (plist-get state :buffers)
            (mapcar #'emacs-tui--view-buffer
                    (emacs-tui--workspace-views session)))
      (cl-assert (eq parent (emacs-tui--workspace-origin-frame session)))
      (when-let* ((child (emacs-tui--workspace-frame session)))
        (cl-assert (eq parent (frame-parent child)))
        (cl-assert (eq (frame-terminal parent) (frame-terminal child))))
      state)))

(defun emacs-tui-test--hangup-join ()
  "Attach B on a second real terminal."
  (condition-case err
      (progn
        (cl-assert (eq emacs-tui-test--hangup-phase 'first-ready))
        (emacs-tui-test--hangup-create 'B)
        (setq emacs-tui-test--hangup-phase 'joining))
    ((error quit) (emacs-tui-test--hangup-fail err)))
  nil)

(defun emacs-tui-test--hangup-b-disposed-p ()
  "Whether abrupt client B has been completely disposed."
  (let* ((state (emacs-tui-test--hangup-state 'B))
         (session (plist-get state :session)))
    (and (not (frame-live-p (plist-get state :parent)))
         (not (emacs-tui-live-p session))
         (= 1 (plist-get state :closed))
         (= 1 (plist-get state :cancelled))
         (not (memq (plist-get state :timer) timer-list))
         (cl-every (lambda (buffer) (not (buffer-live-p buffer)))
                   (plist-get state :buffers)))))

(defun emacs-tui-test--hangup-ack ()
  "Acknowledge native input before or after abrupt client loss."
  (interactive)
  (condition-case err
      (let* ((a (emacs-tui-test--hangup-state 'A))
             (b (emacs-tui-test--hangup-state 'B))
             (sa (plist-get a :session)) (sb (plist-get b :session)))
        (pcase emacs-tui-test--hangup-phase
          ('both-ready
           (cl-assert (eq sb (emacs-tui-current-session)))
           (cl-assert (equal "bravo" (emacs-tui-input-value sb 'body)))
           (cl-assert (equal "" (emacs-tui-input-value sa 'body)))
           (setf (plist-get b :edited-changes) (plist-get b :changes))
           (cl-assert (> (plist-get b :changes) 0))
           (emacs-tui-test--hangup-ready 'hangup-ready))
          ('client-hung-up
           (cl-assert (eq sa (emacs-tui-current-session)))
           (cl-assert (equal "alpha!" (emacs-tui-input-value sa 'body)))
           (cl-assert (> (plist-get a :changes) 0))
           (cl-assert (= (plist-get b :edited-changes)
                         (plist-get b :changes)))
           (cl-assert (emacs-tui-test--hangup-b-disposed-p))
           (cl-assert (not (funcall (plist-get b :publish)
                                    'items :items '("stale"))))
           (cl-assert (equal "host-B preserved"
                             (with-current-buffer (plist-get b :host)
                               (buffer-string))))
           (emacs-tui-close sa)
           (cl-assert (= 1 (plist-get a :closed)))
           (cl-assert (= 1 (plist-get a :cancelled)))
           (dolist (buffer (plist-get a :buffers))
             (cl-assert (not (buffer-live-p buffer))))
           (cl-assert (equal "host-A preserved"
                             (with-current-buffer (plist-get a :host)
                               (buffer-string))))
           (cl-assert (null emacs-tui--sessions))
           (cl-assert (not (memq #'emacs-tui--track-tty-focus
                                 (default-value 'post-command-hook))))
           (cl-assert (not (advice-member-p
                            #'emacs-tui--tty-switch-frame #'handle-switch-frame)))
           (cl-assert (not (memq #'emacs-tui--tty-frame-deleting
                                 delete-frame-functions)))
           (cl-assert (not (memq #'emacs-tui--tty-frame-deleted
                                 after-delete-frame-functions)))
           (cl-assert (not (memq #'emacs-tui--tty-terminal-deleting
                                 delete-terminal-functions)))
           (cl-assert (null emacs-tui--tty-deleting-frames))
           (cl-assert (= 1 (length (frame-list))))
           (emacs-tui-test--hangup-write
            "result"
            (format "PASS Emacs %s; abrupt real-client hangup; backend=%s; disposal, stale rejection, survivor input and cleanup\n"
                    emacs-version (emacs-tui--workspace-backend sa)))
           (kill-emacs 0))
          (_ (error "Unexpected native acknowledgement"))))
    ((error quit) (emacs-tui-test--hangup-fail err))))

(defun emacs-tui-test--hangup-poll ()
  "Observe provider readiness and asynchronous abrupt-client disposal."
  (condition-case err
      (let* ((a (emacs-tui-test--hangup-state 'A))
             (b (emacs-tui-test--hangup-state 'B)))
        (when (and (eq emacs-tui-test--hangup-phase 'joining)
                   (plist-get a :publish) (plist-get b :publish)
                   (memq (plist-get a :timer) timer-list)
                   (memq (plist-get b :timer) timer-list))
          (cl-assert (not (eq (plist-get a :terminal)
                              (plist-get b :terminal))))
          (emacs-tui-test--hangup-ready 'both-ready))
        (when (and (eq emacs-tui-test--hangup-phase 'hangup-ready)
                   (file-exists-p
                    (expand-file-name "client-killed"
                                      (getenv "EMACS_TUI_HANGUP_DIR")))
                   (emacs-tui-test--hangup-b-disposed-p))
          (cl-assert (emacs-tui-live-p (plist-get a :session)))
          (cl-assert (= 0 (plist-get a :closed)))
          (cl-assert (= 0 (plist-get a :cancelled)))
          (cl-assert (memq (plist-get a :timer) timer-list))
          (if (eq (emacs-tui--workspace-backend (plist-get a :session))
                  'child-frame)
              (progn
                (cl-assert (memq #'emacs-tui--track-tty-focus
                                 (default-value 'post-command-hook)))
                (cl-assert (advice-member-p
                            #'emacs-tui--tty-switch-frame
                            #'handle-switch-frame)))
            (cl-assert (not (memq #'emacs-tui--track-tty-focus
                                  (default-value 'post-command-hook))))
            (cl-assert (not (advice-member-p
                             #'emacs-tui--tty-switch-frame
                             #'handle-switch-frame))))
          (emacs-tui-test--hangup-ready 'client-hung-up)))
    ((error quit) (emacs-tui-test--hangup-fail err))))

(defun emacs-tui-test--hangup-start ()
  "Start the private server and mount A on the server terminal."
  (condition-case err
      (progn
        (setq server-socket-dir
              (expand-file-name "socket" (getenv "EMACS_TUI_HANGUP_DIR"))
              server-name "tui")
        (make-directory server-socket-dir t)
        (set-file-modes server-socket-dir #o700)
        (server-start)
        (add-hook 'pre-command-hook #'emacs-tui-test--hangup-command)
        (advice-add #'emacs-tui--tty-terminal-deleting :before
                    (lambda (terminal)
                      (emacs-tui-test--hangup-record 'terminal-before terminal)))
        (advice-add #'emacs-tui--tty-terminal-deleting :after
                    (lambda (terminal)
                      (emacs-tui-test--hangup-record 'terminal-after terminal)))
        (advice-add #'emacs-tui--tty-frame-deleting :before
                    (lambda (frame)
                      (emacs-tui-test--hangup-record 'frame-before frame)))
        (advice-add #'emacs-tui--tty-frame-deleted :after
                    (lambda (frame)
                      (emacs-tui-test--hangup-record 'frame-after frame)))
        (emacs-tui-test--hangup-create 'A)
        (setq emacs-tui-test--hangup-timer
              (run-at-time 0.05 0.05 #'emacs-tui-test--hangup-poll))
        (emacs-tui-test--hangup-ready 'first-ready))
    ((error quit) (emacs-tui-test--hangup-fail err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-test--hangup-start)))

;;; tty-hangup-smoke.el ends here
