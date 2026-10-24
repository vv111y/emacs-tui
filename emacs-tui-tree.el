;;; emacs-tui-tree.el --- Identity-preserving tree projection -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Index finite application-owned forests once per source update.  Expansion
;; and local search project the original items without changing their data.

;;; Code:
(require 'cl-lib)
(require 'subr-x)
(declare-function emacs-tui--item-id "emacs-tui" (item))
(declare-function emacs-tui--item-label "emacs-tui" (item))
(declare-function emacs-tui--validate-items "emacs-tui" (items &optional unique))

(cl-defstruct (emacs-tui--tree-data (:constructor emacs-tui--make-tree-data))
  items parents children depths expanded)

(defun emacs-tui--tree-index (roots accessor &optional previous)
  "Index ROOTS using ACCESSOR; retain expansion from PREVIOUS by identity.
ACCESSOR is a plist keyword or a pure one-argument children function.
Reject duplicate identities and cyclic input before publishing any state."
  (emacs-tui--validate-items roots)
  (let ((parents (make-hash-table :test #'equal))
        (children (make-hash-table :test #'equal))
        (depths (make-hash-table :test #'equal))
        (expanded (make-hash-table :test #'equal))
        (seen (make-hash-table :test #'equal))
        (stack (mapcar (lambda (item) (list item nil 0)) roots)) items)
    (while stack
      (pcase-let* ((`(,item ,parent ,depth) (pop stack))
                   (id (emacs-tui--item-id item))
                   (descendants
                    (if (keywordp accessor)
                        (and (listp item) (plist-get item accessor))
                      (funcall accessor item))))
        (when (and (listp item) (not (plist-get item :id)))
          (error "Tree plist items require a non-nil :id"))
        (when (gethash id seen)
          (error "Tree identities must be globally unique: %S" id))
        (puthash id t seen)
        (emacs-tui--validate-items descendants)
        (puthash id parent parents)
        (puthash id depth depths)
        (puthash id (mapcar #'emacs-tui--item-id descendants) children)
        (when (and descendants previous
                   (gethash id (emacs-tui--tree-data-expanded previous)))
          (puthash id t expanded))
        (push item items)
        (dolist (child (reverse descendants))
          (push (list child id (1+ depth)) stack))))
    (emacs-tui--make-tree-data :items (nreverse items) :parents parents
                               :children children :depths depths :expanded expanded)))

(defun emacs-tui--tree-project (data terms)
  "Return (ITEMS . OPEN) for tree DATA under local search TERMS.
Without TERMS, honor stored expansion.  Search includes matches and ancestors,
revealing paths temporarily without changing stored expansion."
  (let ((kept (make-hash-table :test #'equal))
        (open (make-hash-table :test #'equal))
        (case-fold-search t) result)
    (when terms
      (dolist (item (emacs-tui--tree-data-items data))
        (when (cl-every (lambda (term)
                          (string-match-p (regexp-quote term) (emacs-tui--item-label item))) terms)
          (let ((id (emacs-tui--item-id item)))
            (while (and id (not (gethash id kept)))
              (puthash id t kept)
              (setq id (gethash id (emacs-tui--tree-data-parents data)))
              (when id (puthash id t open)))))))
    (dolist (item (emacs-tui--tree-data-items data))
      (let* ((id (emacs-tui--item-id item))
             (parent (gethash id (emacs-tui--tree-data-parents data))))
        (when (if terms (gethash id kept)
                (or (null parent)
                    (and (gethash parent kept)
                         (gethash parent (emacs-tui--tree-data-expanded data)))))
          (puthash id t kept)
          (unless terms
            (when (gethash id (emacs-tui--tree-data-expanded data))
              (puthash id t open)))
          (push item result))))
    (cons (nreverse result) open)))

(defun emacs-tui--tree-prefix (data open item)
  "Return ITEM's indentation and non-color branch cue in DATA using OPEN."
  (let ((id (emacs-tui--item-id item)))
    (concat (make-string (* 2 (gethash id (emacs-tui--tree-data-depths data))) ?\s)
            (if (gethash id (emacs-tui--tree-data-children data))
                (if (gethash id open) "- " "+ ")
              "  "))))

(provide 'emacs-tui-tree)

;; Local Variables:
;; package-lint-main-file: "emacs-tui.el"
;; End:

;;; emacs-tui-tree.el ends here
