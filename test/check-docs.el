;;; check-docs.el --- Check package documentation -*- lexical-binding: t; -*-
(require 'checkdoc)
(let ((checkdoc-spellcheck-documentation-flag nil))
  (dolist (file '("emacs-tui-layout.el" "emacs-tui.el"))
    (checkdoc-file file)))
(when (get-buffer "*Warnings*")
  (princ (with-current-buffer "*Warnings*" (buffer-string)))
  (kill-emacs 1))
