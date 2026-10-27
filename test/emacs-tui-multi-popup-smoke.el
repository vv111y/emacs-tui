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

(require 'emacs-tui-gallery
         (expand-file-name "../examples/emacs-tui-gallery.el"
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

(defun emacs-tui-multi-popup-smoke--departures (source parent)
  "Leave SOURCE through native commands and recreate its panels on PARENT.
Verify both another buffer in the same window and another selected window.
No explicit close is used before checking the old resources."
  (save-window-excursion
    (let ((destination (generate-new-buffer " *multi destination*")))
      (unwind-protect
          (dolist (kind '(buffer window))
            (let* ((host (selected-window))
                   (other (when (eq kind 'window) (split-window-right)))
                   (index emacs-tui-multi-popup-demo--index)
                   (text (buffer-string)) (position (point))
                   (undo (copy-tree buffer-undo-list))
                   (apps (mapcar #'cdr emacs-tui-multi-popup-demo--sessions))
                   (resources
                    (mapcar
                     (lambda (app)
                       (let ((popup (emacs-tui--workspace-popup app)))
                         (list (emacs-tui--workspace-frame app)
                               (emacs-tui--view-buffer (car (emacs-tui--workspace-views app)))
                               (emacs-tui--popup-begin popup) (emacs-tui--popup-end popup))))
                     apps)))
              (cl-assert (= 3 (length apps)))
              (emacs-tui-multi-popup-smoke--frames parent)
              (dolist (resource resources)
                (cl-assert (buffer-live-p (nth 1 resource)))
                (cl-assert (eq source (marker-buffer (nth 2 resource))))
                (cl-assert (eq source (marker-buffer (nth 3 resource)))))
              (when other (set-window-buffer other destination))
              (with-current-buffer destination (erase-buffer) (insert "Destination"))
              (let ((overriding-terminal-local-map (make-sparse-keymap)))
                (define-key overriding-terminal-local-map (kbd "C-c t")
                            (lambda () (interactive)
                              (if other (other-window 1) (switch-to-buffer destination))))
                (define-key overriding-terminal-local-map (kbd "C-c b")
                            (lambda () (interactive)
                              (if other (other-window -1) (switch-to-buffer source))))
                (execute-kbd-macro (kbd "C-c t"))
                (cl-assert (eq destination (current-buffer)))
                (cl-assert (eq (selected-window) (or other host)))
                (dolist (app apps) (cl-assert (not (emacs-tui-live-p app))))
                (dolist (resource resources)
                  (cl-assert (not (frame-live-p (nth 0 resource))))
                  (cl-assert (not (buffer-live-p (nth 1 resource))))
                  (cl-assert (not (marker-buffer (nth 2 resource))))
                  (cl-assert (not (marker-buffer (nth 3 resource)))))
                (cl-assert (not (memq #'emacs-tui--popup-post-command post-command-hook)))
                (execute-kbd-macro (kbd "M-> x"))
                (cl-assert (equal (buffer-string) "Destinationx"))
                (execute-kbd-macro (kbd "C-c b")))
              (cl-assert (eq host (selected-window)))
              (cl-assert (eq source (current-buffer)))
              (cl-assert emacs-tui-multi-popup-demo-mode)
              (cl-assert (null emacs-tui-multi-popup-demo--sessions))
              (cl-assert (= index emacs-tui-multi-popup-demo--index))
              (cl-assert (equal text (buffer-string)))
              (cl-assert (= position (point)))
              (cl-assert (equal undo buffer-undo-list))
              (when other (delete-window other))
              (redisplay t)
              (let ((windows (window-state-get (frame-root-window parent))))
                (execute-kbd-macro (kbd "C-c 0"))
                (emacs-tui-multi-popup-smoke--frames parent)
                (cl-assert (equal windows (window-state-get (frame-root-window parent)))))
              (cl-assert (eq (plist-get (nth index emacs-tui-multi-popup-demo--objects) :id)
                             (plist-get (emacs-tui-current-item
                                         (emacs-tui-multi-popup-demo--session 'objects)) :id)))))
        (when (buffer-live-p destination) (kill-buffer destination))))))

(defun emacs-tui-multi-popup-smoke ()
  "Toggle and compose three real child frames without replacing their source."
  (cl-assert (not noninteractive))
  (save-window-excursion
    (let ((before (frame-list)) (parent (selected-frame)) source gallery)
      (unwind-protect
          (progn
            (setq gallery (emacs-tui-gallery))
              (emacs-tui-set-selection gallery 'demos 'multi-popup)
              (execute-kbd-macro (kbd "RET"))
              (cl-assert (string-match-p
                          "C-c 0"
                          (emacs-tui--view-text (emacs-tui--resolve-view gallery 'tour))))
              (execute-kbd-macro (kbd "C-c C-o"))
              (cl-assert (not (emacs-tui-live-p gallery)))
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
              (cl-assert (equal windows (window-state-get (frame-root-window parent))) nil
                         "Source window state changed: before=%S after=%S"
                         windows (window-state-get (frame-root-window parent)))
              (cl-assert (equal text (buffer-string)))
              (cl-assert (= position (point)))
              (cl-assert (null buffer-undo-list))
              ;; Navigation intentionally updates native window buffer history.
              ;; Keep the original exact-state check above around popup actions;
              ;; the departure helper checks reopening against its new baseline.
              (emacs-tui-multi-popup-smoke--departures source parent)
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
        (when gallery (emacs-tui-close gallery))
        (when (buffer-live-p source) (kill-buffer source))))))

(provide 'emacs-tui-multi-popup-smoke)
;;; emacs-tui-multi-popup-smoke.el ends here
