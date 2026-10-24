;;; emacs-tui-table-test.el --- Table behavior regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Tables retain object identity through formatting, filtering and sorting.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defconst emacs-tui-table-test--rows
  '((:id a :label "Alpha" :size 10 :kind "Lisp")
    (:id b :label "Beta" :size 2 :kind "Text")
    (:id c :label "Gamma" :size 10 :kind "Text")))

(defun emacs-tui-table-test--columns ()
  "Return the example table columns."
  (list (emacs-tui-column :id 'name :title "Name" :width 8 :value :label)
        (emacs-tui-column :id 'size :title "Size" :width 6 :value :size :align 'right)
        (emacs-tui-column :id 'kind :title "Kind" :width 6 :value :kind)))

(defmacro emacs-tui-table-test--session (options &rest body)
  "Mount a test table with OPTIONS and evaluate BODY before cleanup."
  (declare (indent 1) (debug (form body)))
  `(save-window-excursion
     (delete-other-windows)
     (let (session)
       (unwind-protect
           (progn
             (setq session
                   (emacs-tui-mount
                    :views (list (emacs-tui-view
                                  :id 'rows :items emacs-tui-table-test--rows
                                  :columns (emacs-tui-table-test--columns) ,@options))))
             ,@body)
         (when session (emacs-tui-close session))))))

(defun emacs-tui-table-test--ids (session)
  "Return visible row identities in SESSION."
  (mapcar (lambda (item) (plist-get item :id))
          (emacs-tui--view-visible-items (car (emacs-tui--workspace-views session)))))

(ert-deftest emacs-tui-table-renders-columns-and-returns-original-item ()
  (emacs-tui-table-test--session ()
    (should (string-match-p "Name +Size +Kind *\nAlpha +10 +Lisp" (buffer-string)))
    (should (eq (car emacs-tui-table-test--rows) (emacs-tui-current-item session)))
    (should (= 2 (line-number-at-pos)))))

(ert-deftest emacs-tui-table-sort-stable-numeric-and-restorable ()
  (emacs-tui-table-test--session ()
    (emacs-tui-sort session 'rows 'size)
    (should (equal '(b a c) (emacs-tui-table-test--ids session)))
    (should (equal 'a (plist-get (emacs-tui-current-item session) :id)))
    (should (string-match-p "\\^ Size" (buffer-string)))
    (emacs-tui-sort session 'rows 'size t)
    (should (equal '(a c b) (emacs-tui-table-test--ids session)))
    (emacs-tui-sort session 'rows nil)
    (should (equal '(a b c) (emacs-tui-table-test--ids session)))
    (should (equal '(a b c) (mapcar (lambda (row) (plist-get row :id))
                                   emacs-tui-table-test--rows)))))

(ert-deftest emacs-tui-table-sort-keeps-marks-and-action-payload ()
  (let (selected)
    (emacs-tui-table-test--session
        (:multi-select t :on-select (lambda (_ item) (setq selected item)))
      (emacs-tui-next-item session)
      (emacs-tui-toggle-mark session)
      (emacs-tui-sort session 'rows 'size t)
      (emacs-tui-select session)
      (should (eq selected (cadr emacs-tui-table-test--rows)))
      (should (equal (list selected) (emacs-tui-marked-items session)))
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-table-updates-retain-sort-selection-and-new-values ()
  (emacs-tui-table-test--session ()
    (emacs-tui-sort session 'rows 'size)
    (emacs-tui-update session 'rows :items
                      '((:id a :label "Changed" :size 1) (:id b :label "Beta" :size 20)))
    (should (equal '(a b) (emacs-tui-table-test--ids session)))
    (should (equal "Changed" (plist-get (emacs-tui-current-item session) :label)))
    (should (string-match-p "Changed +1" (buffer-string)))))

(ert-deftest emacs-tui-table-query-searches-untruncated-cell-values ()
  (save-window-excursion
    (delete-other-windows)
    (let (session)
      (unwind-protect
          (progn
            (setq session (emacs-tui-open :backend 'windows
                                          :views (list (emacs-tui-view
                                                        :id 'rows :items emacs-tui-table-test--rows
                                                        :columns (emacs-tui-table-test--columns)))))
            (emacs-tui-sort session 'rows 'size)
            (insert "Text")
            (should (equal '(b c) (emacs-tui-table-test--ids session)))
            (erase-buffer)
            (insert "Lisp 10")
            (should (equal '(a) (emacs-tui-table-test--ids session))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-table-formatting-handles-wide-and-multiline-cells ()
  (let* ((columns (list (emacs-tui-column :id 'name :value :label :width 4)
                        (emacs-tui-column :id 'size :value :size :width 3 :align 'right)))
         (line (emacs-tui--table-line columns '(:label "界界界" :size 7))))
    (should (= 9 (string-width line)))
    (should (string-prefix-p "界界" line))
    (should (string-suffix-p "  7" line))
    (should (= 1 (length (split-string
                          (emacs-tui--table-line columns '(:label "a\nb\tc\r")) "\n"))))))

(ert-deftest emacs-tui-table-column-validation-rejects-invalid-layouts ()
  (dolist (args '((:id x :value :label :width 0) (:id x :value :label :width 1.5)
                  (:id x :value :label :align center) (:id x :value 7)
                  (:id x :value :label :lessp 7)))
    (should-error (apply #'emacs-tui-column args)))
  (let ((column (emacs-tui-column :id 'x :value :label)))
    (should-error (emacs-tui-view :id 'a :columns (list column column)))
    (should-error (emacs-tui-view :id 'a :columns '(invalid)))))

(ert-deftest emacs-tui-table-comparison-failure-keeps-previous-order ()
  (emacs-tui-table-test--session ()
    (let ((view (car (emacs-tui--workspace-views session))))
      (setf (emacs-tui--column-lessp (cadr (emacs-tui--view-columns view)))
            (lambda (_a _b) (error "Comparator failed")))
      (should-error (emacs-tui-sort session 'rows 'size))
      (should (equal '(a b c) (emacs-tui-table-test--ids session)))
      (should-not (emacs-tui--view-sort-column view))
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-table-mixed-values-have-consistent-order ()
  (let ((column (emacs-tui-column :id 'value :value :size)))
    (should (equal '(2 10 "11")
                   (mapcar (lambda (row) (plist-get row :size))
                           (emacs-tui--table-sort '((:size 10) (:size "11") (:size 2))
                                                  column nil))))))

(ert-deftest emacs-tui-table-projections-run-once-per-row-during-sort ()
  (let ((count 0))
    (emacs-tui--table-sort emacs-tui-table-test--rows
                          (emacs-tui-column :id 'size
                                            :value (lambda (row) (cl-incf count)
                                                     (plist-get row :size))) nil)
    (should (= 3 count))))

(ert-deftest emacs-tui-table-sort-rejects-non-table-and-missing-column ()
  (emacs-tui-table-test--session ()
    (should-error (emacs-tui-sort session 'rows 'missing) :type 'user-error)
    (emacs-tui-update session 'rows :text "Preview")
    (should-error (emacs-tui-sort session 'rows 'size) :type 'user-error)))

(ert-deftest emacs-tui-table-streaming-updates-retain-sort-and-identity ()
  (save-window-excursion
    (delete-other-windows)
    (let (session publish)
      (unwind-protect
          (progn
            (setq session
                  (emacs-tui-mount
                   :debounce 60
                   :provider (lambda (_app _query emit _fail) (setq publish emit) nil)
                   :views (list (emacs-tui-view :id 'rows :columns (emacs-tui-table-test--columns)
                                               :multi-select t))))
            (let ((request (emacs-tui--workspace-request session)))
              (cancel-timer (emacs-tui--request-timer request))
              (emacs-tui--start-provider request))
            (funcall publish 'rows :items emacs-tui-table-test--rows)
            (emacs-tui-toggle-mark session)
            (emacs-tui-sort session 'rows 'size)
            (funcall publish 'rows :items
                     '((:id b :label "B" :size 5) (:id a :label "A new" :size 1)))
            (should (equal '(a b) (emacs-tui-table-test--ids session)))
            (should (equal "A new" (plist-get (emacs-tui-current-item session) :label)))
            (should (equal "A new" (plist-get (car (emacs-tui-marked-items session)) :label))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-table-custom-comparison-uses-raw-projected-values ()
  (let ((column (emacs-tui-column :id 'name :value :label
                                 :lessp (lambda (a b) (string-lessp (downcase a) (downcase b))))))
    (should (equal '("alpha" "Beta")
                   (mapcar (lambda (row) (plist-get row :label))
                           (emacs-tui--table-sort '((:label "Beta") (:label "alpha")) column nil))))))

(provide 'emacs-tui-table-test)
;;; emacs-tui-table-test.el ends here
