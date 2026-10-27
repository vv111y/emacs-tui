;;; emacs-tui-table.el --- Column formatting and sorting -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Table columns project existing items without replacing their identities.
;; Formatting uses display columns, and sorting leaves source order intact.

;;; Code:
(require 'cl-lib)

(cl-defstruct (emacs-tui--column (:constructor emacs-tui--make-column))
  id title width value align lessp)

(cl-defun emacs-tui-column (&key id title (width 16) value (align 'left) lessp)
  "Describe a table column with unique ID and optional TITLE.
WIDTH is a positive number of display columns or `fill'.  One fill column per
table uses the display space left after fixed columns, separators and native
line-end indicators, with a minimum width of one.  ALIGN is `left' or `right'.
VALUE is a plist keyword or a pure one-argument item projection function.
LESSP optionally compares two projected values.  The default orders numbers
numerically before other values, then compares displayed strings.  Line breaks
and tabs display as spaces.  Projection and comparison functions must return
promptly."
  (unless (and id (or (symbolp id) (stringp id)))
    (error "Column ID must be a non-nil symbol or string"))
  (unless (or (null title) (stringp title)) (error "Column title must be a string"))
  (unless (or (eq width 'fill) (and (integerp width) (> width 0)))
    (error "Column width must be positive or fill"))
  (unless (memq align '(left right)) (error "Column alignment must be left or right"))
  (unless (or (keywordp value) (functionp value))
    (error "Column value must be a keyword or projection function"))
  (unless (or (null lessp) (functionp lessp))
    (error "Column LESSP must be a function or nil"))
  (emacs-tui--make-column :id id :title (or title (format "%s" id))
                          :width width :value value :align align :lessp lessp))

(defun emacs-tui--validate-columns (columns)
  "Validate table COLUMNS, accepting nil for an ordinary list."
  (unless (and (proper-list-p columns) (cl-every #'emacs-tui--column-p columns))
    (error "Columns must be a list of emacs-tui-column descriptions"))
  (let ((ids (mapcar #'emacs-tui--column-id columns)))
    (unless (= (length ids) (length (delete-dups (copy-sequence ids))))
      (error "Column IDs must be unique")))
  (when (> (cl-count 'fill columns :key #'emacs-tui--column-width) 1)
    (error "Only one table column may use fill width")))

(defun emacs-tui--table-resolve-columns (columns width)
  "Return COLUMNS with a `fill' column resolved for display WIDTH.
Do not copy or mutate fixed-only descriptions.  WIDTH includes two-column
separators but excludes any selection mark prefix."
  (let ((fill (cl-find 'fill columns :key #'emacs-tui--column-width)))
    (if fill
        (let* ((separators (* 2 (max 0 (1- (length columns)))))
               (fixed (cl-loop for column in columns
                               for value = (emacs-tui--column-width column)
                               when (integerp value) sum value))
               (resolved (max 1 (- (max 1 (or width 16)) fixed separators))))
          (mapcar (lambda (column)
                    (if (eq column fill)
                        (let ((copy (copy-emacs-tui--column column)))
                          (setf (emacs-tui--column-width copy) resolved)
                          copy)
                      column))
                  columns))
      columns)))

(defun emacs-tui--table-value (column item)
  "Project COLUMN's value from ITEM."
  (let ((value (emacs-tui--column-value column)))
    (if (keywordp value)
        (when (listp item) (plist-get item value))
      (funcall value item))))

(defun emacs-tui--cell-text (value)
  "Return VALUE as a single-line string, displaying nil as empty."
  (replace-regexp-in-string "[\n\r\t]" " " (if value (format "%s" value) "")))

(defun emacs-tui--table-line (columns item &optional header sort-column descending)
  "Format ITEM into COLUMNS, or format titles when HEADER is non-nil.
Mark SORT-COLUMN with its ascending or DESCENDING direction."
  (mapconcat
   (lambda (column)
     (let* ((width (emacs-tui--column-width column))
            (value (if header
                       (concat (when (equal sort-column (emacs-tui--column-id column))
                                 (if descending "v " "^ "))
                               (emacs-tui--column-title column))
                     (emacs-tui--table-value column item)))
            (text (truncate-string-to-width (emacs-tui--cell-text value) width))
            (padding (make-string (- width (string-width text)) ?\s)))
       (if (and (not header) (eq (emacs-tui--column-align column) 'right))
           (concat padding text)
         (concat text padding))))
   columns "  "))

(defun emacs-tui--table-less-p (a b)
  "Order numbers A and B numerically before other values, then compare strings."
  (cond ((and (numberp a) (numberp b)) (< a b))
        ((numberp a) t)
        ((numberp b) nil)
        (t (string-lessp (emacs-tui--cell-text a) (emacs-tui--cell-text b)))))

(defun emacs-tui--table-sort (items column descending)
  "Return a stable sorted copy of ITEMS by COLUMN, optionally DESCENDING.
Project each item's value once; never mutate the source list."
  (let ((lessp (or (emacs-tui--column-lessp column) #'emacs-tui--table-less-p)))
    (mapcar #'cdr
            (cl-stable-sort
             (mapcar (lambda (item) (cons (emacs-tui--table-value column item) item)) items)
             (lambda (a b)
               (if descending (funcall lessp (car b) (car a))
                 (funcall lessp (car a) (car b))))))))

(provide 'emacs-tui-table)

;; Local Variables:
;; package-lint-main-file: "emacs-tui.el"
;; End:

;;; emacs-tui-table.el ends here
