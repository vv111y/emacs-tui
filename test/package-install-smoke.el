;;; package-install-smoke.el --- Validate a clean installed package -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Run in a separate Emacs with an empty working directory and no checkout
;; load path.  Assert that both library resolution and actual definitions come
;; from the fresh package installation before exercising public interfaces.

;;; Code:
(require 'package)

(let* ((root (file-name-as-directory (or (getenv "EMACS_TUI_INSTALL_ROOT")
                                        (error "Missing install test root"))))
       (archive (getenv "EMACS_TUI_PACKAGE_ARCHIVE"))
       (expected (getenv "EMACS_TUI_EXPECT_VERSION")))
  (when (and expected (not (version= expected emacs-version)))
    (error "Expected Emacs %s, got %s" expected emacs-version))
  (setq user-emacs-directory root
        package-user-dir (expand-file-name "elpa/" root)
        package-archives nil)
  (when (file-exists-p package-user-dir) (error "Installation directory must be fresh"))
  (package-initialize)
  (package-install-file archive)
  (require 'emacs-tui)
  (when (featurep 'emacs-tui-completion)
    (error "Core loaded the optional completion adapter eagerly"))
  (require 'emacs-tui-completion)
  (dolist (library '(emacs-tui emacs-tui-layout emacs-tui-table emacs-tui-tree emacs-tui-action emacs-tui-completion))
    (unless (file-in-directory-p (locate-library (symbol-name library)) package-user-dir)
      (error "Library did not load from installation: %s" library)))
  (unless (file-in-directory-p (symbol-file 'emacs-tui-mount 'defun) package-user-dir)
    (error "Actual definitions did not load from the installed package"))
  (unless (file-exists-p (expand-file-name "LICENSE" (file-name-directory (locate-library "emacs-tui"))))
    (error "Installed package lacks its license"))
  (dolist (function '(emacs-tui-popup emacs-tui-popup-supported-p emacs-tui-reposition-popup
                       emacs-tui-scroll-view))
    (unless (and (fboundp function)
                 (file-in-directory-p (symbol-file function 'defun) package-user-dir))
      (error "Popup API did not load from the installed package: %s" function)))
  (when (emacs-tui-popup-supported-p)
    (error "Batch installation smoke must not advertise native popup display"))
  (save-window-excursion
    (let* ((alpha (list :id 'alpha :label "Alpha"))
           (beta (list :id 'beta :label "Beta")) session)
      (unwind-protect
          (progn
            (setq session
                  (emacs-tui-mount
                   :views
                   (list (emacs-tui-view
                          :id 'results :items (list alpha beta) :multi-select t
                          :columns (list (emacs-tui-column :id 'name :value :label))
                          :actions (list (emacs-tui-action :id 'targets :run (lambda (_app items) items))))
                         (emacs-tui-input :id 'input :value "draft")
                         (emacs-tui-tree :id 'tree :items '((:id root :label "Root" :children ("Leaf")))))))
            (emacs-tui-set-selection session 'results 'beta)
            (emacs-tui-first-item session)
            (unless (eq alpha (emacs-tui-current-item session)) (error "Installed first-item failed"))
            (emacs-tui-last-item session)
            (unless (eq beta (emacs-tui-current-item session)) (error "Installed last-item failed"))
            (emacs-tui-mark-all session)
            (unless (equal (list alpha beta) (emacs-tui-marked-items session))
              (error "Installed bulk marking failed"))
            (emacs-tui-invert-marks session)
            (when (emacs-tui-marked-items session) (error "Installed mark inversion failed"))
            (emacs-tui-first-item session)
            (emacs-tui-toggle-mark session)
            (emacs-tui-set-query session 'results "Beta")
            (unless (eq beta (emacs-tui-current-item session)) (error "Installed filtering failed"))
            (unless (eq alpha (car (emacs-tui-act session 'targets))) (error "Installed batch action failed"))
            (emacs-tui-next-view session)
            (insert "x")
            (undo-boundary)
            (emacs-tui-update session 'input :title "Draft 50% ready")
            (emacs-tui-set-layout session 'rows)
            (undo-only 1)
            (unless (equal "draft" (emacs-tui-input-value session)) (error "Installed input undo failed"))
            (emacs-tui-next-view session)
            (emacs-tui-tree-expand session)
            (emacs-tui-next-item session)
            (unless (equal "Leaf" (emacs-tui-current-item session)) (error "Installed tree failed"))
            (emacs-tui-tree-collapse-all session)
            (unless (eq 'root (plist-get (emacs-tui-current-item session) :id))
              (error "Installed bulk collapse failed"))
            (emacs-tui-tree-expand-all session)
            (emacs-tui-set-selection session 'tree "Leaf")
            (unless (equal "Leaf" (emacs-tui-current-item session))
              (error "Installed bulk expansion failed"))
            (emacs-tui-toggle-maximize session)
            (emacs-tui-set-layout session 'grid)
            (emacs-tui-focus-view session 'results)
            (unless (eq beta (emacs-tui-current-item session))
              (error "Installed hidden-view focus failed")))
        (when session (emacs-tui-close session)))
      (when (emacs-tui-live-p session) (error "Installed interface did not close"))))
  (save-window-excursion
    (let (session)
      (unwind-protect
          (progn
            (setq session
                  (emacs-tui-mount
                   :views (list (emacs-tui-view :id 'items :items '("Keep focus"))
                                (emacs-tui-view
                                 :id 'preview
                                 :text (mapconcat #'number-to-string
                                                  (number-sequence 1 200) "\n")))))
            ;; Discover the pane through public focus, then return to the list.
            (emacs-tui-focus-view session 'preview)
            (let* ((preview (selected-window))
                   (start (window-start preview)))
              (emacs-tui-focus-view session 'items)
              (let ((source (selected-window))
                    (buffer (current-buffer))
                    (position (point))
                    (text (buffer-string)))
                (emacs-tui-scroll-view session 'preview 3)
                (unless (and (> (window-start preview) start)
                             (eq source (selected-window))
                             (eq buffer (current-buffer))
                             (= position (point))
                             (equal text (buffer-string))
                             (eq 'items (emacs-tui-current-view session))
                             (equal "Keep focus" (emacs-tui-current-item session)))
                  (error "Installed preview scroll changed source or failed to scroll")))))
        (when session (emacs-tui-close session)))))
  (princ (format "PASS clean package installation on Emacs %s; public API smoke passed\n" emacs-version)))

;;; package-install-smoke.el ends here
