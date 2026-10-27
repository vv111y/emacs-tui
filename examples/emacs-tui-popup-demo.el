;;; emacs-tui-popup-demo.el --- Candidates around the word being typed -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Enable the demo in your current buffer with M-x emacs-tui-popup-demo.
;; Type map, buffer or window.  M-n/p selects candidates, TAB accepts,
;; C-c C-p cycles eight compass positions, C-g dismisses, C-c C-q disables.
;; Nothing is inserted until native typing or explicit acceptance.  The source
;; window never splits.  make popup-demo starts a disposable sample document.

;;; Code:
(require 'cl-lib)
(require 'thingatpt)
(require 'emacs-tui)

(defconst emacs-tui-popup-demo--words
  '("map" "mapc" "mapcar" "mapcan" "mapconcat" "maphash" "map-keymap"
    "buffer-file-name" "buffer-list" "buffer-name" "buffer-size" "buffer-string"
    "window-body-width" "window-buffer" "window-edges" "window-list" "window-point"
    "frame-height" "frame-width" "frame-parent" "frame-selected-window"
    "insert" "insert-buffer-substring" "insert-file-contents"
    "日本語" "日本語入力" "café" "café-au-lait" "éclair")
  "Literal completion data; candidates are never evaluated.")

(defvar-local emacs-tui-popup-demo--session nil)
(defvar-local emacs-tui-popup-demo--query nil)
(defvar-local emacs-tui-popup-demo--begin nil)
(defvar-local emacs-tui-popup-demo--dismissed nil)
(defvar-local emacs-tui-popup-demo--position 'south-west)
(defvar emacs-tui-popup-demo-mode)

(defun emacs-tui-popup-demo--stamp ()
  "Return the source edit/point state used for explicit dismissal."
  (cons (point) (buffer-chars-modified-tick)))

(defun emacs-tui-popup-demo--close ()
  "Close only this buffer's candidate popup."
  (when emacs-tui-popup-demo--session
    (emacs-tui-close emacs-tui-popup-demo--session))
  (setq emacs-tui-popup-demo--session nil emacs-tui-popup-demo--query nil))

(defun emacs-tui-popup-demo--accept (app item)
  "Explicitly replace the current source word with ITEM, then close APP."
  (let ((bounds (bounds-of-thing-at-point 'symbol)))
    (unless (and bounds (= (point) (cdr bounds))
                 (equal emacs-tui-popup-demo--query
                        (buffer-substring-no-properties (car bounds) (point))))
      (user-error "The source word changed; type again before accepting"))
    (atomic-change-group
      (delete-region (car bounds) (point))
      (insert (plist-get item :label)))
    (setq emacs-tui-popup-demo--dismissed (emacs-tui-popup-demo--stamp))
    (emacs-tui-close app)))

(defun emacs-tui-popup-demo--refresh ()
  "Publish candidates for the word ending at the current source point."
  (when emacs-tui-popup-demo-mode
    (condition-case err
        (let* ((bounds (bounds-of-thing-at-point 'symbol))
               (query (and bounds (= (point) (cdr bounds))
                           (buffer-substring-no-properties (car bounds) (point))))
               (items (and query (not (equal emacs-tui-popup-demo--dismissed
                                             (emacs-tui-popup-demo--stamp)))
                           (cl-loop for word in emacs-tui-popup-demo--words
                                    when (and (string-prefix-p query word t)
                                              (not (equal query word)))
                                    collect (list :id word :label word)))))
          (if (null items) (emacs-tui-popup-demo--close)
            (unless (and (emacs-tui-live-p emacs-tui-popup-demo--session)
                         (equal (car bounds) emacs-tui-popup-demo--begin))
              (emacs-tui-popup-demo--close)
              (setq emacs-tui-popup-demo--query query
                    emacs-tui-popup-demo--begin (car bounds))
              (let ((source (current-buffer)))
                (setq emacs-tui-popup-demo--session
                      (emacs-tui-popup
                       :begin (car bounds) :end (cdr bounds)
                       :position emacs-tui-popup-demo--position :width 30
                       :height (min 8 (1+ (length items)))
                       :view (emacs-tui-view
                              :id 'candidates :title "Candidates | TAB accept"
                              :items items :on-select #'emacs-tui-popup-demo--accept)
                       :on-close (lambda (closed)
                                   (when (buffer-live-p source)
                                     (with-current-buffer source
                                       (when (eq closed emacs-tui-popup-demo--session)
                                         (setq emacs-tui-popup-demo--session nil)))))))))
            (unless (equal query emacs-tui-popup-demo--query)
              (emacs-tui-update emacs-tui-popup-demo--session 'candidates :items items)
              (setq emacs-tui-popup-demo--query query))))
      (error
       (emacs-tui-popup-demo--close)
       (message "Popup demo: %s" (error-message-string err))))))

(defun emacs-tui-popup-demo-next ()
  "Select the next candidate while retaining source typing focus."
  (interactive)
  (if (emacs-tui-live-p emacs-tui-popup-demo--session)
      (emacs-tui-next-item emacs-tui-popup-demo--session)
    (user-error "Type a candidate prefix first")))

(defun emacs-tui-popup-demo-previous ()
  "Select the previous candidate while retaining source typing focus."
  (interactive)
  (if (emacs-tui-live-p emacs-tui-popup-demo--session)
      (emacs-tui-previous-item emacs-tui-popup-demo--session)
    (user-error "Type a candidate prefix first")))

(defun emacs-tui-popup-demo-accept ()
  "Accept a candidate, or indent normally when no popup is visible."
  (interactive)
  (if (emacs-tui-live-p emacs-tui-popup-demo--session)
      (emacs-tui-select emacs-tui-popup-demo--session)
    (indent-for-tab-command)))

(defun emacs-tui-popup-demo-move ()
  "Move the visible candidate popup clockwise around the current word."
  (interactive)
  (unless (emacs-tui-live-p emacs-tui-popup-demo--session)
    (user-error "Type a candidate prefix first"))
  (setq emacs-tui-popup-demo--position
        (emacs-tui-reposition-popup emacs-tui-popup-demo--session))
  (message "Popup: %s" emacs-tui-popup-demo--position))

(defun emacs-tui-popup-demo-dismiss ()
  "Dismiss the candidate popup, or quit normally when none is visible."
  (interactive)
  (if (emacs-tui-live-p emacs-tui-popup-demo--session)
      (progn
        (setq emacs-tui-popup-demo--dismissed (emacs-tui-popup-demo--stamp))
        (emacs-tui-popup-demo--close))
    (keyboard-quit)))

(defun emacs-tui-popup-demo-stop ()
  "Disable the demo and release its candidate popup."
  (interactive)
  (emacs-tui-popup-demo-mode -1))

(defvar emacs-tui-popup-demo-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "M-n") #'emacs-tui-popup-demo-next)
    (define-key map (kbd "M-p") #'emacs-tui-popup-demo-previous)
    (define-key map (kbd "TAB") #'emacs-tui-popup-demo-accept)
    (define-key map (kbd "C-g") #'emacs-tui-popup-demo-dismiss)
    (define-key map (kbd "C-c C-p") #'emacs-tui-popup-demo-move)
    (define-key map (kbd "C-c C-q") #'emacs-tui-popup-demo-stop)
    map)
  "Local demo bindings; normal source editing remains native.")

(define-minor-mode emacs-tui-popup-demo-mode
  "Show sample candidates near the word being typed in the original buffer.
Use `emacs-tui-popup-demo-move' to cycle all eight compass positions,
`emacs-tui-popup-demo-next' and `emacs-tui-popup-demo-previous' to navigate,
and `emacs-tui-popup-demo-accept' to explicitly insert a candidate.
`emacs-tui-popup-demo-dismiss' closes without editing.  Disable the mode to
restore all host bindings and release the popup.  No files are saved."
  :lighter " TUI-Popup"
  (if emacs-tui-popup-demo-mode
      (if (emacs-tui-popup-supported-p)
          (add-hook 'post-command-hook #'emacs-tui-popup-demo--refresh nil t)
        (setq emacs-tui-popup-demo-mode nil)
        (user-error "This demo needs graphical or native TTY child frames"))
    (remove-hook 'post-command-hook #'emacs-tui-popup-demo--refresh t)
    (emacs-tui-popup-demo--close)))

;;;###autoload
(defun emacs-tui-popup-demo ()
  "Enable typing-driven sample completion in the current buffer.
The current window and source text are preserved.  Type map, buffer or window,
then use `emacs-tui-popup-demo-move' to move the popup around that word."
  (interactive)
  (emacs-tui-popup-demo-mode 1)
  (message "Type map | M-n/p candidates | TAB accept | C-c C-p move | C-g dismiss | C-c C-q stop"))

(defun emacs-tui-popup-demo-sample ()
  "Open a disposable sample document and enable the inline popup demo.
This explicit launcher creates a fresh source buffer; popup presentation
thereafter leaves that buffer and its window intact."
  (interactive)
  (unless (emacs-tui-popup-supported-p)
    (user-error "This demo needs graphical or native TTY child frames"))
  (switch-to-buffer (generate-new-buffer "*TUI popup playground*"))
  (text-mode)
  (insert "Type map at the cursor. Keep typing to filter the popup.\n"
          "M-n / M-p: select   TAB: accept   C-g: dismiss\n"
          "C-c C-p: N / NE / E / SE / S / SW / W / NW   C-c C-q: stop\n"
          "Try buffer, window, café or 日本語. Normal undo still works.\n")
  (insert (make-string 30 ?\n))
  (goto-char (point-min))
  (forward-line (max 5 (/ (window-body-height) 2)))
  (insert (make-string (max 0 (- (/ (window-body-width) 2) 2)) ?\s))
  (setq buffer-undo-list nil)
  (set-buffer-modified-p nil)
  (emacs-tui-popup-demo))

(provide 'emacs-tui-popup-demo)
;;; emacs-tui-popup-demo.el ends here
