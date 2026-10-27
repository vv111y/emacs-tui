;;; gui-smoke.el --- Graphical child-frame integration smoke -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Run interactively under Xvfb, never in batch or a TTY.  This verifies native
;; graphical frame state and input, not physical display/font appearance.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)
(require 'emacs-tui-inspector-demo)
(require 'emacs-tui-form-demo)
(require 'emacs-tui-popup-lifecycle-smoke)
(require 'emacs-tui-multi-popup-smoke)

(defvar emacs-tui-gui--parent nil)
(defvar emacs-tui-gui--source nil)
(defvar emacs-tui-gui--app nil)
(defvar emacs-tui-gui--text nil)
(defvar emacs-tui-gui--point nil)
(defvar emacs-tui-gui--phase 0)
(defvar emacs-tui-gui--frames nil)
(defvar emacs-tui-gui--close-trace nil)

(defun emacs-tui-gui--trace-close (&optional session)
  "Record unexpected disposal of SESSION before its resources disappear."
  (when (and (eq session emacs-tui-gui--app)
             (memq emacs-tui-gui--phase '(1 2))
             (emacs-tui--workspace-active session)
             (not emacs-tui-gui--close-trace))
    (setq emacs-tui-gui--close-trace
          (concat (format "Close context: selected=%S origin=%S command=%S\n"
                          (selected-window) (emacs-tui--workspace-origin-window session)
                          this-command)
                  (with-temp-buffer
                    (let ((standard-output (current-buffer))) (backtrace))
                    (buffer-string))))))

(defun emacs-tui-gui--finish (error)
  "Report ERROR or success, disposing test-owned resources."
  (advice-remove 'emacs-tui-close #'emacs-tui-gui--trace-close)
  (when error
    (setq error (list :error error :phase emacs-tui-gui--phase
                      :current-buffer (buffer-name)
                      :selected-buffer (buffer-name (window-buffer (selected-window)))
                      :parent-selected (eq (selected-frame) emacs-tui-gui--parent))))
  (when emacs-tui-gui--app (emacs-tui-close emacs-tui-gui--app))
  (when (buffer-live-p emacs-tui-gui--source)
    (kill-buffer emacs-tui-gui--source))
  (let ((coding-system-for-write 'utf-8-unix))
    (with-temp-file (or (getenv "EMACS_TUI_GUI_REPORT") "gui-result.txt")
      (insert (if error (format "FAIL %S\n" error)
                (format "PASS Emacs %s; graphical %S; three sibling popups/gallery launch/source departures/independent placement/individual and collective toggles; child input; form validation/options/apply/revert; inspector scroll/action/related/history; eight moves; resize; source preservation; twenty command-loop lifetimes; cleanup\n"
                        emacs-version window-system)))
      (when (and error (get-buffer "*Messages*"))
        (insert (with-current-buffer "*Messages*" (buffer-string))))
      (when (and error emacs-tui-gui--close-trace)
        (insert emacs-tui-gui--close-trace))))
  (kill-emacs (if error 1 0)))

(defun emacs-tui-gui--form ()
  "Exercise native form editing, validation and explicit saved state."
  (let ((frames (frame-list)) (source (current-buffer))
        (text (buffer-string)) (position (point)) app child buffers)
    (unwind-protect
        (progn
          (setq app (emacs-tui-form-demo)
                child (emacs-tui--workspace-frame app)
                buffers (mapcar #'emacs-tui--view-buffer
                                (emacs-tui--workspace-views app)))
          (redisplay t)
          (cl-assert (= 4 (length buffers)))
          (cl-assert (cl-every #'buffer-live-p buffers))
          (cl-assert (frame-live-p child))
          (cl-assert (frame-visible-p child))
          (cl-assert (eq (frame-parent child) emacs-tui-gui--parent))
          (execute-kbd-macro (kbd "C-a C-k O p s"))
          (emacs-tui-focus-view app 'retries)
          (execute-kbd-macro (kbd "C-a C-k 1 1"))
          (cl-assert (string-match-p
                      "Draft invalid"
                      (emacs-tui--view-text (emacs-tui--resolve-view app 'status))))
          (cl-assert (eq 'rejected
                         (condition-case nil
                             (progn (emacs-tui-act app 'apply) 'accepted)
                           (user-error 'rejected))))
          (cl-assert (string-match-p
                      "Name: Local demo"
                      (emacs-tui--view-text (emacs-tui--resolve-view app 'status))))
          (execute-kbd-macro (kbd "C-a C-k 1 0"))
          (emacs-tui-focus-view app 'options)
          (cl-assert (eq 'wrap (plist-get (emacs-tui-current-item app) :id)))
          (execute-kbd-macro (kbd "SPC C-c C-c"))
          (cl-assert (not (plist-get (emacs-tui-current-item app) :checked)))
          (execute-kbd-macro (kbd "SPC"))
          (cl-assert (plist-get (emacs-tui-current-item app) :checked))
          (cl-assert (string-match-p
                      "Wrap text=off"
                      (emacs-tui--view-text (emacs-tui--resolve-view app 'status))))
          (emacs-tui-focus-view app 'name)
          (execute-kbd-macro (kbd "C-a C-k d r a f t C-c C-r"))
          (cl-assert (equal "Ops" (emacs-tui-input-value app 'name)))
          (cl-assert (equal "10" (emacs-tui-input-value app 'retries)))
          (cl-assert (eq 'wrap (plist-get (emacs-tui-current-item app 'options) :id)))
          (cl-assert (not (plist-get (emacs-tui-current-item app 'options) :checked)))
          (execute-kbd-macro (kbd "C-c C-q"))
          (cl-assert (not (emacs-tui-live-p app)))
          (cl-assert (not (frame-live-p child)))
          (cl-assert (not (cl-some #'buffer-live-p buffers)))
          (cl-assert (equal frames (frame-list)))
          (cl-assert (eq source (window-buffer (selected-window))))
          (with-current-buffer source
            (cl-assert (equal text (buffer-string)))
            (cl-assert (= position (point)))))
      (when app (emacs-tui-close app)))))

(defun emacs-tui-gui--step ()
  "Run the next integration phase after native display events settle."
  (condition-case err
      ;; Timers inherit an arbitrary current buffer.  Observe the actual typing
      ;; target without selecting a window/frame or hiding native focus changes.
      (with-current-buffer (window-buffer (selected-window))
        (when (> emacs-tui-gui--phase 0)
          (cl-assert (eq (window-buffer (selected-window)) emacs-tui-gui--source)))
        (pcase emacs-tui-gui--phase
          (0
           (cl-assert (display-graphic-p))
           (setq emacs-tui-gui--frames (frame-list))
           (setq emacs-tui-gui--parent (selected-frame)
                 emacs-tui-gui--source (generate-new-buffer " *TUI GUI source*"))
           (set-frame-size emacs-tui-gui--parent 120 40)
           (switch-to-buffer emacs-tui-gui--source)
           (insert (make-string 18 ?\n) (make-string 55 ?\s) "pump"
                   (make-string 25 ?\n))
           (goto-char (point-min)) (forward-line 18) (end-of-line)
           (setq buffer-undo-list nil)
           (setq emacs-tui-gui--text (buffer-string)
                 emacs-tui-gui--point (point))
           (setq emacs-tui-gui--app
                 (emacs-tui-mount :backend 'child-frame
                                  :views (list (emacs-tui-input :id 'draft :value ""))))
           (cl-assert (display-graphic-p (emacs-tui--workspace-frame emacs-tui-gui--app)))
           (execute-kbd-macro "hello")
           (cl-assert (equal "hello" (emacs-tui-input-value emacs-tui-gui--app 'draft)))
           (emacs-tui-close emacs-tui-gui--app)
           (switch-to-buffer emacs-tui-gui--source)
           (goto-char emacs-tui-gui--point)
           (setq emacs-tui-gui--app (emacs-tui-inspector-demo-at-point))
           (advice-add 'emacs-tui-close :before #'emacs-tui-gui--trace-close)
           (setq emacs-tui-gui--phase 1)
           (run-at-time .3 nil #'emacs-tui-gui--step))
          ((or 1 2 3)
           (redisplay t)
           (let ((size (nth (1- emacs-tui-gui--phase) '((120 40) (90 30) (140 45)))))
             (cl-assert (= (frame-width emacs-tui-gui--parent) (car size)))
             (cl-assert (= (frame-height emacs-tui-gui--parent) (cadr size))))
           (cl-assert (eq (selected-frame) emacs-tui-gui--parent))
           (cl-assert (eq (current-buffer) emacs-tui-gui--source))
           (cl-assert (equal emacs-tui-gui--text (buffer-string)))
           (cl-assert (= emacs-tui-gui--point (point)))
           (cl-assert (null (cl-remove nil buffer-undo-list)))
           (let ((child (emacs-tui--workspace-frame emacs-tui-gui--app))
                 symbols positions)
             (cl-assert (frame-live-p child))
             (cl-assert (frame-visible-p child))
             (cl-assert (eq (frame-parent child) emacs-tui-gui--parent))
             (dotimes (_ 8)
               (push (emacs-tui-reposition-popup emacs-tui-gui--app) symbols)
               (redisplay t)
               (let ((position (frame-position child)))
                 (push position positions)
                 (cl-assert (>= (car position) 0))
                 (cl-assert (>= (cdr position) 0))
                 (cl-assert (<= (+ (car position) (frame-pixel-width child))
                                (frame-inner-width emacs-tui-gui--parent)))
                 (cl-assert (<= (+ (cdr position) (frame-pixel-height child))
                                (frame-inner-height emacs-tui-gui--parent)))))
             (cl-assert (= 8 (length (delete-dups symbols))))
             (cl-assert (> (length (delete-dups positions)) 1)))
           (pcase emacs-tui-gui--phase
             (1 (let* ((view (emacs-tui--resolve-view emacs-tui-gui--app 'details))
                       (window (emacs-tui--view-window view))
                       (start (window-start window)))
                  (execute-kbd-macro (kbd "M-n"))
                  (cl-assert (> (window-start window) start)))
                (emacs-tui-inspector-demo-acknowledge)
                (cl-assert (gethash "pump" emacs-tui-inspector-demo--acknowledged))
                (dolist (step '(("C-c C-l" . "valve") ("C-c C-l" . "sensor")
                                ("C-c C-b" . "valve") ("C-c C-b" . "pump")
                                ("C-c C-f" . "valve") ("C-c C-b" . "pump")))
                  (execute-kbd-macro (kbd (car step)))
                  (cl-assert (equal (cdr step) (car emacs-tui-inspector-demo--object))))
                (set-frame-size emacs-tui-gui--parent 90 30))
             (2 (set-frame-size emacs-tui-gui--parent 140 45))
             (3 (let ((child (emacs-tui--workspace-frame emacs-tui-gui--app)))
                  (execute-kbd-macro (kbd "C-g"))
                  (cl-assert (not (frame-live-p child)))
                  (cl-assert (not emacs-tui-inspector-demo--active))
                  (cl-assert (not emacs-tui--sessions))
                  (cl-assert (not (advice-member-p #'emacs-tui--popup-switch-frame
                                                  #'handle-switch-frame)))
                  (cl-assert (null (cl-set-difference (frame-list) emacs-tui-gui--frames))))
                (emacs-tui-gui--form)
                (emacs-tui-multi-popup-smoke)
                (emacs-tui-popup-lifecycle-smoke)
                (emacs-tui-gui--finish nil)))
           (cl-incf emacs-tui-gui--phase)
           (run-at-time .3 nil #'emacs-tui-gui--step))))
    ((error quit) (emacs-tui-gui--finish err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time .3 nil #'emacs-tui-gui--step)))
;;; gui-smoke.el ends here
