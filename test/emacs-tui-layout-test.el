;;; emacs-tui-layout-test.el --- Layout invariant tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Geometry examples and invariants, including constrained terminal sizes.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'emacs-tui-layout)

(ert-deftest emacs-tui-layout-columns-distribute-remainders ()
  (should (equal (emacs-tui-layout-compute '(a b c) 8 7)
                 '((a 0 0 3 7) (b 3 0 3 7) (c 6 0 2 7)))))

(ert-deftest emacs-tui-layout-rows-distribute-remainders ()
  (should (equal (emacs-tui-layout-compute '(a b c) 7 8 'rows)
                 '((a 0 0 7 3) (b 0 3 7 3) (c 0 6 7 2)))))

(ert-deftest emacs-tui-layout-grid-is-row-major ()
  (should (equal (emacs-tui-layout-compute '(a b c d e) 10 5 'grid)
                 '((a 0 0 4 3) (b 4 0 3 3) (c 7 0 3 3)
                   (d 0 3 4 2) (e 4 3 3 2)))))

(ert-deftest emacs-tui-layout-tiny-viewports-omit-trailing-views ()
  (should (equal (mapcar #'car
                         (emacs-tui-layout-compute '(a b c) 2 9))
                 '(a b)))
  (should (equal (mapcar #'car
                         (emacs-tui-layout-compute '(a b c) 9 2 'rows))
                 '(a b)))
  (should (equal (emacs-tui-layout-compute '(a b c d e) 2 2 'grid)
                 '((a 0 0 1 1) (b 1 0 1 1)
                   (c 0 1 1 1) (d 1 1 1 1)))))

(ert-deftest emacs-tui-layout-empty-input-and-viewport ()
  (dolist (layout '(columns rows grid))
    (should-not (emacs-tui-layout-compute nil 10 10 layout))
    (should-not (emacs-tui-layout-compute '(a) 0 10 layout))
    (should-not (emacs-tui-layout-compute '(a) 10 0 layout))))

(ert-deftest emacs-tui-layout-validates-input-before-layout ()
  (dolist (size '(-1 1.0 "2" nil))
    (should-error (emacs-tui-layout-compute '(a) size 2))
    (should-error (emacs-tui-layout-compute '(a) 2 size)))
  (should-error (emacs-tui-layout-compute '(a . b) 4 4))
  (should-error (emacs-tui-layout-compute '(a b a) 0 0))
  (should-error (emacs-tui-layout-compute (list "a" (copy-sequence "a")) 4 4))
  (should-error (emacs-tui-layout-compute nil 0 0 'unknown))
  (should (equal (emacs-tui-layout-compute '(nil a) 2 1)
                 '((nil 0 0 1 1) (a 1 0 1 1)))))

(defun emacs-tui-layout-test--overlap-p (a b)
  "Return non-nil if rectangles A and B overlap."
  (pcase-let ((`(,ax ,ay ,aw ,ah) a)
              (`(,bx ,by ,bw ,bh) b))
    (and (< ax (+ bx bw)) (< bx (+ ax aw))
         (< ay (+ by bh)) (< by (+ ay ah)))))

(ert-deftest emacs-tui-layout-invariants-across-terminal-sizes ()
  (dolist (layout '(columns rows grid))
    (dolist (width '(0 1 2 3 7 20 81))
      (dolist (height '(0 1 2 3 7 24))
        (dotimes (count 14)
          (let* ((ids (number-sequence 1 count))
                 (snapshot (copy-tree ids))
                 (result (emacs-tui-layout-compute ids width height layout))
                 (capacity (if (or (= width 0) (= height 0)) 0
                             (pcase layout
                               ('columns width)
                               ('rows height)
                               ('grid (* width height))))))
            (should (equal ids snapshot))
            (should (= (length result) (min count capacity)))
            (should (equal (mapcar #'car result)
                           (cl-subseq ids 0 (length result))))
            (cl-loop for tail on result
                     for rectangle = (cdar tail)
                     do (pcase-let ((`(,x ,y ,w ,h) rectangle))
                          (should (cl-every #'integerp rectangle))
                          (should (and (>= x 0) (>= y 0) (> w 0) (> h 0)))
                          (should (<= (+ x w) width))
                          (should (<= (+ y h) height)))
                     do (dolist (other (cdr tail))
                          (should-not
                           (emacs-tui-layout-test--overlap-p
                            rectangle (cdr other)))))))))))

(provide 'emacs-tui-layout-test)
;;; emacs-tui-layout-test.el ends here
