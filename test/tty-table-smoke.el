;;; tty-table-smoke.el --- Exercise embedded native TTY views -*- lexical-binding: t; -*-
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defvar emacs-tui-test--table-session nil)
(defvar emacs-tui-test--table-phase 1)
(defvar emacs-tui-test--table-attempts 0)
(defvar emacs-tui-test--table-small-width nil)
(defvar emacs-tui-test--table-small-line-width nil)
(defvar emacs-tui-test--table-actions 0)
(defvar emacs-tui-test--table-closed 0)
(defvar emacs-tui-test--table-host nil)
(defvar emacs-tui-test--table-window nil)
(defvar emacs-tui-test--table-command-session nil)

(defun emacs-tui-test--table-failure (err)
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
    (insert (format "FAIL table: %S\n" err)))
  (kill-emacs 1))

(defun emacs-tui-test--table-resized ()
  (condition-case err
      (let* ((session emacs-tui-test--table-session)
             (parent (emacs-tui--workspace-origin-frame session))
             (child (emacs-tui--workspace-frame session))
             (backend (emacs-tui--workspace-backend session))
             (phase emacs-tui-test--table-phase)
             (width (if (= phase 1) 90 140))
             (height (if (= phase 1) 30 45)))
        (cl-incf emacs-tui-test--table-attempts)
        (when (> emacs-tui-test--table-attempts 100)
          (error "Embedded resize phase %s did not settle" phase))
        (redisplay t)
        (when (and (= (frame-width parent) width)
                   (<= (- height 2) (frame-height parent) height)
                   ;; Terminal dimensions may settle before automatic reflow.
                   ;; Keep the original poll bound and verify both states.
                   (equal (emacs-tui--workspace-geometry session)
                          (emacs-tui--geometry session))
                   (or (not child)
                       (and (< (frame-width child) width) (< (frame-height child) height)
                            (or (= phase 1) (> (frame-width child) emacs-tui-test--table-small-width)))))
          (cl-assert (emacs-tui-live-p session))
          (cl-assert (null (emacs-tui--workspace-query-buffer session)))
          (cl-assert (null (emacs-tui--workspace-origin session)))
          (cl-assert (equal (emacs-tui--workspace-geometry session) (emacs-tui--geometry session)))
          (cl-assert (equal (emacs-tui-marked-items session 'items) '("beta")))
          (cl-assert (eq (window-buffer (selected-window))
                         (emacs-tui--view-buffer (car (emacs-tui--workspace-views session)))))
          (cl-assert (= emacs-tui-test--table-actions 1))
          (let* ((view (car (emacs-tui--workspace-views session)))
                 (window (emacs-tui--view-window view))
                 (line-width
                  (with-current-buffer (emacs-tui--view-buffer view)
                    (save-excursion
                      (goto-char (point-min))
                      (string-width (buffer-substring
                                     (line-beginning-position) (line-end-position)))))))
            (cl-assert (= line-width (window-max-chars-per-line window)))
            ;; Check a numeric payload at the right edge in actual redisplay,
            ;; rather than only measuring the source string's allocated width.
            (with-current-buffer (emacs-tui--view-buffer view)
              (save-excursion
                (goto-char (point-min))
                (forward-line 1)
                (let* ((end (line-end-position))
                       (last (1- end))
                       (coordinates (pos-visible-in-window-p last window t)))
                  (cl-assert (= (char-before end) ?4))
                  (cl-assert (= 0 (window-hscroll window)))
                  (cl-assert coordinates)
                  (cl-assert (< (car coordinates)
                                (* (window-max-chars-per-line window)
                                   (frame-char-width (window-frame window))))))))
            (when (= phase 2)
              (cl-assert (> line-width emacs-tui-test--table-small-line-width)))
            (when (= phase 1)
              (setq emacs-tui-test--table-small-line-width line-width)))
          (if (= phase 1)
              (progn
                (setq emacs-tui-test--table-small-width (when child (frame-width child))
                      emacs-tui-test--table-phase 2
                      emacs-tui-test--table-attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
            (execute-kbd-macro (kbd "<backtab> RET"))
            (cl-assert (= emacs-tui-test--table-actions 2))
            (cl-assert (emacs-tui-live-p session))
            (execute-kbd-macro (kbd "q"))
            (cl-assert (not (emacs-tui-live-p session)))
            (cl-assert (= emacs-tui-test--table-closed 1))
            (cl-assert (null emacs-tui--sessions))
            (cl-assert (window-live-p emacs-tui-test--table-window))
            (cl-assert (eq emacs-tui-test--table-host
                           (window-buffer emacs-tui-test--table-window)))
            (cl-assert (equal (with-current-buffer emacs-tui-test--table-host
                                (buffer-string)) "unchanged"))
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; real TTY; backend=%s; lifecycle=table; rightmost numeric payload visible; actions=2; resize=120x40->90x30->140x45\n"
                              emacs-version backend)))
            (kill-emacs 0))))
    ((error quit) (emacs-tui-test--table-failure err))))

(defun emacs-tui-test--table-start ()
  (condition-case err
      (let ((source (get-buffer-create "*Table smoke host*"))
            (keymap (make-sparse-keymap)))
        (define-key keymap (kbd "r")
          (lambda () (interactive)
            (setq emacs-tui-test--table-command-session (emacs-tui-current-session))))
        (switch-to-buffer source)
        (erase-buffer)
        (insert "unchanged")
        (setq emacs-tui-test--table-host source
              emacs-tui-test--table-window (selected-window)
              emacs-tui-test--table-session
              (emacs-tui-embed
               :keymap keymap
               :view (emacs-tui-view
                      :id 'items :items '("alpha" "beta") :multi-select t
                      :columns (list (emacs-tui-column :id 'name :title "Name"
                                                       :width 'fill :value #'identity)
                                     (emacs-tui-column :id 'size :title "Size"
                                                       :width 6 :value #'length :align 'right))
                      :on-select (lambda (_app _item)
                                   (cl-incf emacs-tui-test--table-actions)))
               :on-close (lambda (_) (cl-incf emacs-tui-test--table-closed))))
        (execute-kbd-macro (kbd "n C-c C-m RET r"))
        (cl-assert (eq emacs-tui-test--table-command-session emacs-tui-test--table-session))
        (execute-kbd-macro (kbd "s s i z e RET"))
        (cl-assert (equal (emacs-tui-current-item emacs-tui-test--table-session) "beta"))
        (cl-assert (equal (car (emacs-tui--view-visible-items
                               (car (emacs-tui--workspace-views emacs-tui-test--table-session))))
                          "beta"))
        (cl-assert (= 1 (length (window-list))))
        (cl-assert (equal (with-current-buffer source (buffer-string)) "unchanged"))
        (redisplay t)
        (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))
        (run-at-time 0.05 0.05 #'emacs-tui-test--table-resized))
    ((error quit) (emacs-tui-test--table-failure err))))

(add-hook 'emacs-startup-hook
          (lambda () (run-at-time 0.1 nil #'emacs-tui-test--table-start)))
