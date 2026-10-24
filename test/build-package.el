;;; build-package.el --- Build the candidate recipe at the tested commit -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Use real package-build with a preseeded source cache and fetching disabled.
;; The runner supplies an isolated clone containing exactly the tested commit.

;;; Code:
(require 'package-build)

(let* ((root (file-name-as-directory (or (getenv "EMACS_TUI_PACKAGE_ROOT")
                                        (error "Missing package test root"))))
       (sha (getenv "EMACS_TUI_PACKAGE_SHA"))
       (recipe-file (getenv "EMACS_TUI_PACKAGE_RECIPE"))
       (recipe (with-temp-buffer (insert-file-contents recipe-file) (read (current-buffer)))))
  (unless (and sha (string-match-p "\\`[0-9a-f]\\{40\\}\\'" sha))
    (error "Invalid source commit: %S" sha))
  (unless (and (eq (car recipe) 'emacs-tui)
               (equal (plist-get (cdr recipe) :repo) "vv111y/emacs-tui"))
    (error "Unexpected candidate recipe"))
  (setq package-build-working-dir (expand-file-name "working/" root)
        package-build-recipes-dir (expand-file-name "recipes/" root)
        package-build-archive-dir (expand-file-name "archive/" root)
        package-build--inhibit-fetch t)
  (make-directory package-build-recipes-dir t)
  (with-temp-file (expand-file-name "emacs-tui" package-build-recipes-dir)
    (prin1 (cons (car recipe) (plist-put (cdr recipe) :commit sha)) (current-buffer)))
  (package-build-archive "emacs-tui" t)
  (let ((archives (directory-files package-build-archive-dir t "\\.tar\\'"))
        (default-directory (expand-file-name "emacs-tui/" package-build-working-dir)))
    (unless (= 1 (length archives)) (error "Expected one built tar archive: %S" archives))
    (unless (equal sha (car (process-lines "git" "rev-parse" "HEAD")))
      (error "package-build did not retain the tested source commit"))
    (with-temp-file (expand-file-name "artifact-path.txt" root) (insert (car archives)))
    (princ (format "Built candidate recipe at %s: %s\n" sha (file-name-nondirectory (car archives))))))

;;; build-package.el ends here
