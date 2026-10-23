;;; emacs-tui-layout.el --- Geometry for ephemeral workspaces -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: convenience, terminals
;; URL: https://github.com/vv111y/emacs-tui

;; This file is part of emacs-tui.
;;
;; emacs-tui is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; emacs-tui is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with emacs-tui.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Pure character-cell layout calculations, independent of buffers and frames.
;; A rectangle is (X Y WIDTH HEIGHT), relative to the supplied viewport.

;;; Code:

(require 'cl-lib)

(defun emacs-tui-layout--segments (extent count)
  "Divide EXTENT into COUNT positive segments.
Return a list of (OFFSET SIZE) pairs.  Earlier segments receive remainders."
  (let ((size (/ extent count))
        (remainder (% extent count))
        (offset 0)
        result)
    (dotimes (index count)
      (let ((length (+ size (if (< index remainder) 1 0))))
        (push (list offset length) result)
        (setq offset (+ offset length))))
    (nreverse result)))

(defun emacs-tui-layout-compute (ids width height &optional layout)
  "Place IDS in a WIDTH by HEIGHT character-cell viewport.
Return an alist of (ID . (X Y WIDTH HEIGHT)) entries in input order.
LAYOUT is `columns' (the default), `rows', or `grid'.  Grid placement
is row-major with approximately equal row and column counts, constrained
by the viewport.  The final row can have empty cells.

IDS must be a proper list with unique elements according to `equal'.
WIDTH and HEIGHT must be nonnegative integers.  Returned rectangles have
positive dimensions, do not overlap, and stay inside the viewport.
If space is insufficient, trailing IDs are omitted.  An empty viewport
returns nil.  No input is modified."
  (unless (proper-list-p ids)
    (error "IDS must be a proper list"))
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (id ids)
      (when (gethash id seen)
        (error "Duplicate view ID: %S" id))
      (puthash id t seen)))
  (unless (and (integerp width) (>= width 0)
               (integerp height) (>= height 0))
    (error "Viewport dimensions must be nonnegative integers"))
  (setq layout (or layout 'columns))
  (unless (memq layout '(columns rows grid))
    (error "Unknown layout: %S" layout))
  (when (and ids (> width 0) (> height 0))
    (let* ((count (min (length ids)
                       (pcase layout
                         ('columns width)
                         ('rows height)
                         ('grid (* width height)))))
           (columns
            (pcase layout
              ('columns count)
              ('rows 1)
              ('grid
               (let ((root 1))
                 (while (< (* root root) count)
                   (setq root (1+ root)))
                 (min width (max root (ceiling count height)))))))
           (rows (ceiling count columns))
           (xs (vconcat (emacs-tui-layout--segments width columns)))
           (ys (vconcat (emacs-tui-layout--segments height rows)))
           result)
      (cl-loop for id in ids
               for index from 0 below count
               for x = (aref xs (% index columns))
               for y = (aref ys (/ index columns))
               do (push (cons id (list (car x) (car y)
                                       (cadr x) (cadr y)))
                        result))
      (nreverse result))))

(provide 'emacs-tui-layout)
;;; emacs-tui-layout.el ends here
