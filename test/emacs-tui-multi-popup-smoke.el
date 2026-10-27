;;; emacs-tui-multi-popup-smoke.el --- Native sibling popup journey -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Shared by real interactive TTY and graphical fixtures.  Never models frames.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui-multi-popup-demo
         (expand-file-name "../examples/emacs-tui-multi-popup-demo.el"
                           (file-name-directory (or load-file-name
                                                    (bound-and-true-p byte-compile-current-file)
                                                    buffer-file-name))))

(defun emacs-tui-multi-popup-smoke--frames (parent)
  "Assert all three native panels belong to PARENT and return their frames."
  (let (frames)
    (dolist (spec emacs-tui-multi-popup-demo--panels)
      (let* ((app (emacs-tui-multi-popup-demo--session (car spec)))
             (child (and app (emacs-tui--workspace-frame app))))
        (cl-assert (frame-live-p child))
        (cl-assert (frame-visible-p child))
        (cl-assert (eq parent (frame-parent child)))
        (push child frames)))
    (cl-assert (= 3 (length (delete-dups frames))))
    frames))

(defun emacs-tui-multi-popup-smoke ()
  "Toggle and compose three real child frames without replacing their source."
  (cl-assert (not noninteractive))
  (save-window-excursion
    (let ((before (frame-list)) (parent (selected-frame)) source)
      (unwind-protect
          (progn
            (emacs-tui-multi-popup-demo)
            (setq source (current-buffer))
            (let ((host (selected-window)) (text (buffer-string)) (position (point))
                  (windows (window-state-get (frame-root-window parent))))
              (redisplay t)
              ;; Let real focus events arrive; never repair focus in this test.
              (sit-for 0.05)
              (cl-assert (eq parent (selected-frame)))
              (cl-assert (eq host (selected-window)))
              (emacs-tui-multi-popup-smoke--frames parent)
              (dolist (step '((objects . "C-c 1") (details . "C-c 2") (keys . "C-c 3")))
                (let* ((id (car step))
                       (old (emacs-tui-multi-popup-demo--session id))
                       (siblings (cl-remove-if
                                  (lambda (entry) (eq id (car entry)))
                                  (copy-sequence emacs-tui-multi-popup-demo--sessions))))
                  (execute-kbd-macro (kbd (cdr step)))
                  (cl-assert (not (emacs-tui-live-p old)))
                  (dolist (entry siblings)
                    (cl-assert (eq (cdr entry) (emacs-tui-multi-popup-demo--session (car entry)))))
                  (execute-kbd-macro (kbd (cdr step)))
                  (cl-assert (not (eq old (emacs-tui-multi-popup-demo--session id))))
                  (emacs-tui-multi-popup-smoke--frames parent)))
              (let* ((details (emacs-tui-multi-popup-demo--session 'details))
                     (child (emacs-tui--workspace-frame details))
                     (place (frame-position child)))
                (execute-kbd-macro (kbd "C-c C-p M-n"))
                (cl-assert (equal place (frame-position child)))
                (cl-assert (eq 'valve (plist-get (emacs-tui-current-item
                                                (emacs-tui-multi-popup-demo--session 'objects)) :id)))
                (cl-assert (string-match-p "Return valve"
                                          (emacs-tui--view-text
                                           (emacs-tui--resolve-view details 'details)))))
              ;; Partial visibility -> none -> all, retaining application state.
              (execute-kbd-macro (kbd "C-c 2 C-c 0"))
              (cl-assert (not emacs-tui-multi-popup-demo--sessions))
              (cl-assert emacs-tui-multi-popup-demo-mode)
              (execute-kbd-macro (kbd "M-n C-c 0"))
              (emacs-tui-multi-popup-smoke--frames parent)
              (cl-assert (eq 'sensor (plist-get (emacs-tui-current-item
                                               (emacs-tui-multi-popup-demo--session 'objects)) :id)))
              ;; Native deletion of one child must leave its siblings usable.
              (delete-frame (emacs-tui--workspace-frame
                             (emacs-tui-multi-popup-demo--session 'keys)) t)
              (cl-assert (not (emacs-tui-multi-popup-demo--session 'keys)))
              (cl-assert (emacs-tui-multi-popup-demo--session 'objects))
              (execute-kbd-macro (kbd "C-c 3"))
              (cl-assert (equal windows (window-state-get (frame-root-window parent))))
              (cl-assert (equal text (buffer-string)))
              (cl-assert (= position (point)))
              (cl-assert (null buffer-undo-list))
              (execute-kbd-macro "x")
              (undo-boundary)
              (undo-only 1)
              (cl-assert (equal text (buffer-string)))
              (cl-assert (= position (point)))
              (cl-assert (eq host (selected-window)))
              (execute-kbd-macro (kbd "C-g C-c 0 C-c C-q"))
              (cl-assert (not emacs-tui-multi-popup-demo-mode))
              (cl-assert (not emacs-tui-multi-popup-demo--sessions))
              (cl-assert (null (cl-set-difference (frame-list) before)))
              ;; Major-mode replacement closes every owned frame and binding.
              (emacs-tui-multi-popup-demo-mode 1)
              (text-mode)
              (cl-assert (not emacs-tui-multi-popup-demo-mode))
              (cl-assert (null (cl-set-difference (frame-list) before)))
              (emacs-tui-multi-popup-demo-mode 1)
              (kill-buffer source)
              (cl-assert (null (cl-set-difference (frame-list) before)))))
        (when (buffer-live-p source) (kill-buffer source))))))

(provide 'emacs-tui-multi-popup-smoke)
;;; emacs-tui-multi-popup-smoke.el ends here
