;;; package-metadata-smoke.el --- Validate release package metadata -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Parse the main source exactly as package.el does and compare its version to
;; the release version supplied by CI.  package-build creates a dated snapshot
;; archive, so its artifact name cannot establish tagged source metadata.

;;; Code:
(require 'package)

(let* ((expected (or (getenv "EMACS_TUI_EXPECT_PACKAGE_VERSION")
                     (error "Missing expected package version")))
       (source (expand-file-name "emacs-tui.el" default-directory))
       (descriptor
        (with-temp-buffer
          (setq buffer-file-name source)
          (insert-file-contents source)
          (package-buffer-info)))
       (actual (package-desc-version descriptor))
       (canonical (package-version-join actual)))
  (unless (equal actual (version-to-list expected))
    (error "Expected package version %s, got %s" expected canonical))
  (princ (format "PASS package metadata %s (header %s)\n" canonical expected)))

;;; package-metadata-smoke.el ends here
