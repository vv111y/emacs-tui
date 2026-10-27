;;; emacs-tui-popup-lifecycle-smoke.el --- Shared native lifetime checks -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Called by graphical and terminal integration fixtures after their interactive
;; scenarios.  Drive disposal through the command loop, not private hook calls.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)

(defun emacs-tui-popup-lifecycle-smoke ()
  "Exercise twenty native popup lifetimes and explicit source departures.
Require a supported display.  Verify exact-once callbacks, detached markers,
dead view buffers/frames and removal of popup routing hooks after every cycle.
Ordinary commands must retain their chosen window and buffer after disposal."
  (cl-assert (emacs-tui-popup-supported-p))
  (cl-assert (null emacs-tui--sessions))
  (let ((frames (frame-list)))
    (save-window-excursion
      (dotimes (cycle 20)
        (let ((source (generate-new-buffer " *popup lifetime source*"))
              (other (generate-new-buffer " *popup lifetime destination*"))
              (kind (mod cycle 4)) app child view-buffer begin end calls
              origin destination)
          (unwind-protect
              (progn
                (switch-to-buffer source)
                (insert "source anchor\n")
                (goto-char 8)
                (setq buffer-undo-list nil
                      origin (selected-window))
                (with-current-buffer other (insert "destination stays editable\n"))
                (when (= kind 1)
                  (setq destination (split-window-below))
                  (set-window-buffer destination other))
                (redisplay t)
                (setq app
                      (emacs-tui-popup
                       :begin 8 :end 14 :width 28 :height 5
                       :view (emacs-tui-view :id 'preview :text "Temporary preview")
                       :on-close (lambda (closed)
                                   (push (list (eq closed app)
                                               (emacs-tui-live-p closed)
                                               (selected-window)) calls))))
                (setq child (emacs-tui--workspace-frame app)
                      view-buffer (emacs-tui--view-buffer
                                   (emacs-tui--resolve-view app 'preview))
                      begin (emacs-tui--popup-begin (emacs-tui--workspace-popup app))
                      end (emacs-tui--popup-end (emacs-tui--workspace-popup app)))
                (cl-assert (frame-live-p child))
                (cl-assert (eq (selected-window) origin))
                ;; A temporary command map supplies application actions without
                ;; altering source bindings or manually invoking post-command.
                (let ((overriding-terminal-local-map (make-sparse-keymap)))
                  (define-key overriding-terminal-local-map (kbd "C-c t")
                              (lambda ()
                                (interactive)
                                (pcase kind
                                  (0 (emacs-tui-close app))
                                  (1 (other-window 1))
                                  (2 (switch-to-buffer other))
                                  (3 (kill-buffer source)))))
                  (execute-kbd-macro (kbd "C-c t")))
                (cl-assert (not (emacs-tui-live-p app)))
                (cl-assert (not (frame-live-p child)))
                (cl-assert (not (buffer-live-p view-buffer)))
                (cl-assert (not (marker-buffer begin)))
                (cl-assert (not (marker-buffer end)))
                (emacs-tui-close app)
                (cl-assert (= 1 (length calls)))
                (cl-assert (equal (cl-subseq (car calls) 0 2) '(t nil)))
                (cl-assert (eq (selected-window) (if (= kind 1) destination origin)))
                (cl-assert (eq (nth 2 (car calls)) (selected-window)))
                (when (= kind 3) (cl-assert (not (buffer-live-p source))))
                (when (= kind 0)
                  (cl-assert (eq (window-buffer origin) source)))
                (when (memq kind '(1 2))
                  (cl-assert (eq (window-buffer (selected-window)) other)))
                (when (buffer-live-p source)
                  (with-current-buffer source
                    (cl-assert (equal (buffer-string) "source anchor\n"))
                    (cl-assert (= (point) 8))
                    (cl-assert (null (cl-remove nil buffer-undo-list)))))
                (with-current-buffer other
                  (cl-assert (equal (buffer-string) "destination stays editable\n")))
                (cl-assert (null emacs-tui--sessions))
                (cl-assert (null (cl-set-exclusive-or frames (frame-list))))
                (cl-assert (not (memq #'emacs-tui--popup-post-command post-command-hook)))
                (cl-assert (not (memq #'emacs-tui--popup-terminal-deleted delete-terminal-functions)))
                (cl-assert (not (advice-member-p #'emacs-tui--popup-switch-frame #'handle-switch-frame)))
                (cl-assert (not (advice-member-p #'emacs-tui--tty-switch-frame #'handle-switch-frame))))
            (when app (emacs-tui-close app))
            (when (window-live-p origin) (select-window origin))
            (when (window-live-p destination) (delete-window destination))
            (when (buffer-live-p source) (kill-buffer source))
            (when (buffer-live-p other) (kill-buffer other))))))))

(provide 'emacs-tui-popup-lifecycle-smoke)
;;; emacs-tui-popup-lifecycle-smoke.el ends here
