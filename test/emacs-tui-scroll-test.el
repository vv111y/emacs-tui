;;; emacs-tui-scroll-test.el --- Focus-preserving preview scrolling -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Exercise owned ordinary windows; native anchored previews have a TTY probe.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-scroll-test--app (&rest body)
  "Run BODY in a disposable list, preview and editable input application."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     (let ((text (mapconcat (lambda (n) (format "Line %03d" n))
                            (number-sequence 1 200) "\n")) app)
       (unwind-protect
           (progn
             (setq app (emacs-tui-mount
                        :views (list (emacs-tui-view :id 'items :items '("A" "B")
                                                    :multi-select t)
                                     (emacs-tui-view :id 'preview :text text)
                                     (emacs-tui-input :id 'input :value "Scratch"))))
             ,@body)
         (when app (emacs-tui-close app))))))

(ert-deftest emacs-tui-scroll-preserves-focus-data-and-selection ()
  (emacs-tui-scroll-test--app
    (emacs-tui-toggle-mark app)
    (let* ((source (current-buffer)) (window (selected-window))
           (point (point)) (source-text (buffer-string))
           (view (emacs-tui--resolve-view app 'preview))
           (preview (emacs-tui--view-window view))
           (start (window-start preview))
           (tick (with-current-buffer (emacs-tui--view-buffer view)
                   (buffer-chars-modified-tick))))
      (should (eq app (emacs-tui-scroll-view app 'preview 5)))
      (should (> (window-start preview) start))
      (should (eq source (current-buffer)))
      (should (eq window (selected-window)))
      (should (= point (point)))
      (should (equal source-text (buffer-string)))
      (should (eq 'items (emacs-tui-current-view app)))
      (should (equal "A" (emacs-tui-current-item app)))
      (should (equal '("A") (emacs-tui-marked-items app)))
      (should (= tick (with-current-buffer (emacs-tui--view-buffer view)
                        (buffer-chars-modified-tick))))
      ;; Batch windows do not redisplay. Establish a middle reading position
      ;; before checking backward movement; native popup reversal has a PTY test.
      (with-current-buffer (emacs-tui--view-buffer view)
        (goto-char (point-min)) (forward-line 40)
        (set-window-start preview (point) t)
        (set-window-point preview (point)))
      (let ((middle (window-start preview)))
        (emacs-tui-scroll-view app 'preview -2)
        (should (< (window-start preview) middle))))))

(ert-deftest emacs-tui-scroll-retains-reading-position-through-layout ()
  (emacs-tui-scroll-test--app
    (emacs-tui-scroll-view app 'preview 8)
    (let* ((view (emacs-tui--resolve-view app 'preview))
           (start (window-start (emacs-tui--view-window view)))
           (point (window-point (emacs-tui--view-window view))))
      (emacs-tui-update app 'preview :text (copy-sequence text))
      (emacs-tui-cycle-layout app)
      (should (= start (window-start (emacs-tui--view-window view))))
      (should (= point (window-point (emacs-tui--view-window view)))))))

(ert-deftest emacs-tui-scroll-rejects-hidden-editable-and-list-targets ()
  (emacs-tui-scroll-test--app
    (should-error (emacs-tui-scroll-view app 'items 1) :type 'user-error)
    (should-error (emacs-tui-scroll-view app 'input 1) :type 'user-error)
    (should-error (emacs-tui-scroll-view app 'absent 1))
    (should-error (emacs-tui-scroll-view app 'preview 1.5))
    (emacs-tui-toggle-maximize app)
    (let ((windows (window-state-get)))
      (should-error (emacs-tui-scroll-view app 'preview 1) :type 'user-error)
      (should (equal windows (window-state-get)))
      (should (eq 'items (emacs-tui-current-view app))))))

(ert-deftest emacs-tui-scroll-rejects-repurposed-window-without-touching-it ()
  (emacs-tui-scroll-test--app
    (let ((foreign (generate-new-buffer " *scroll foreign*"))
          (window (emacs-tui--view-window (emacs-tui--resolve-view app 'preview))))
      (unwind-protect
          (progn
            (with-current-buffer foreign (insert text))
            (set-window-buffer window foreign)
            (set-window-point window 30)
            (let ((state (window-state-get)))
              (should-error (emacs-tui-scroll-view app 'preview 5) :type 'user-error)
              (should (equal state (window-state-get)))
              (should (eq 'items (emacs-tui-current-view app)))))
        (kill-buffer foreign)))))

(ert-deftest emacs-tui-scroll-native-errors-restore-selected-source ()
  (emacs-tui-scroll-test--app
    (let ((source (current-buffer)) (window (selected-window)))
      (should-error (emacs-tui-scroll-view app 'preview -1) :type 'beginning-of-buffer)
      (should (eq source (current-buffer)))
      (should (eq window (selected-window)))
      (should (eq 'items (emacs-tui-current-view app)))
      (emacs-tui-close app)
      (should-error (emacs-tui-scroll-view app 'preview 1) :type 'user-error))))

(provide 'emacs-tui-scroll-test)
;;; emacs-tui-scroll-test.el ends here
