;;; emacs-tui-table-test.el --- Table behavior regressions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
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
                  (:id x :value :label :width stretch)
                  (:id x :value :label :align center) (:id x :value 7)
                  (:id x :value :label :lessp 7)))
    (should-error (apply #'emacs-tui-column args)))
  (let ((column (emacs-tui-column :id 'x :value :label)))
    (should-error (emacs-tui-view :id 'a :columns (list column column)))
    (should-error (emacs-tui-view :id 'a :columns '(invalid)))))

(ert-deftest emacs-tui-table-fill-column-uses-remainder-without-mutating-description ()
  (let* ((fill (emacs-tui-column :id 'name :value :label :width 'fill))
         (fixed (emacs-tui-column :id 'size :value :size :width 3))
         (columns (list fill fixed))
         (fixed-only (list fixed))
         (wide (emacs-tui--table-resolve-columns columns 20))
         (narrow (emacs-tui--table-resolve-columns columns 4)))
    (should (= 15 (emacs-tui--column-width (car wide))))
    (should (= 1 (emacs-tui--column-width (car narrow))))
    (should (= 20 (string-width (emacs-tui--table-line wide '(:label "Alpha" :size 7)))))
    (should (= 6 (string-width (emacs-tui--table-line narrow '(:label "Alpha" :size 7)))))
    (should (eq 'fill (emacs-tui--column-width fill)))
    (should (eq fixed (cadr wide)))
    (should (eq fixed-only (emacs-tui--table-resolve-columns fixed-only 20)))))

(ert-deftest emacs-tui-table-fill-column-preserves-rightmost-payload-in-live-window ()
  (dolist (marked '(nil t))
    (save-window-excursion
      (delete-other-windows)
      (let (session)
        (unwind-protect
            (progn
              (setq session
                    (emacs-tui-mount
                     :views
                     (list (emacs-tui-view
                            :id 'rows :items emacs-tui-table-test--rows :multi-select marked
                            :columns
                            (list (emacs-tui-column :id 'name :value :label :width 'fill)
                                  (emacs-tui-column :id 'size :value :size :width 6))))))
              (let* ((view (car (emacs-tui--workspace-views session)))
                     (window (emacs-tui--view-window view)))
                (with-current-buffer (emacs-tui--view-buffer view)
                  (goto-char (point-min))
                  (while (not (eobp))
                    (should (<= (string-width (buffer-substring
                                               (line-beginning-position)
                                               (line-end-position)))
                                (window-max-chars-per-line window)))
                    (forward-line 1))
                  (goto-char (point-min))
                  (forward-line 1)
                  (should (string-match-p "10 *$" (buffer-substring
                                                  (line-beginning-position)
                                                  (line-end-position)))))))
          (when session (emacs-tui-close session)))))))

(ert-deftest emacs-tui-table-multiple-fill-columns-preserve-rightmost-payload-in-live-window ()
  (dolist (marked '(nil t))
    (save-window-excursion
      (delete-other-windows)
      (let (session)
        (unwind-protect
            (progn
              (setq session
                    (emacs-tui-mount
                     :views
                     (list (emacs-tui-view
                            :id 'rows :items emacs-tui-table-test--rows :multi-select marked
                            :columns
                            (list (emacs-tui-column :id 'name :value :label :width 'fill)
                                  (emacs-tui-column :id 'size :value :size :width 'fill))))))
              (let* ((view (car (emacs-tui--workspace-views session)))
                     (window (emacs-tui--view-window view)))
                (with-current-buffer (emacs-tui--view-buffer view)
                  (goto-char (point-min))
                  (while (not (eobp))
                    (should (<= (string-width (buffer-substring
                                               (line-beginning-position)
                                               (line-end-position)))
                                (window-max-chars-per-line window)))
                    (forward-line 1))
                  (goto-char (point-min))
                  (forward-line 1)
                  (should (string-match-p "10 *$" (buffer-substring
                                                  (line-beginning-position)
                                                  (line-end-position)))))))
          (when session (emacs-tui-close session)))))))

(ert-deftest emacs-tui-table-native-margins-refit-without-replacing-windows ()
  (save-window-excursion
    (delete-other-windows)
    (let (session)
      (unwind-protect
          (progn
            (setq session
                  (emacs-tui-mount
                   :views
                   (list (emacs-tui-view
                          :id 'rows :items emacs-tui-table-test--rows :multi-select t
                          :columns
                          (list (emacs-tui-column :id 'name :value :label :width 'fill)
                                (emacs-tui-column :id 'size :value :size :width 'fill)))
                         (emacs-tui-view :id 'preview :text "unchanged preview"))))
            (emacs-tui-next-item session)
            (emacs-tui-toggle-mark session)
            (let* ((view (car (emacs-tui--workspace-views session)))
                   (preview (cadr (emacs-tui--workspace-views session)))
                   (window (emacs-tui--view-window view))
                   (preview-window (emacs-tui--view-window preview))
                   (preview-tick (buffer-chars-modified-tick
                                  (emacs-tui--view-buffer preview)))
                   (edges (window-edges window)))
              (dolist (margins '((3 . 4) (nil . nil)))
                (set-window-margins window (car margins) (cdr margins))
                ;; Exercise the redisplay hook in batch; the TTY fixture also
                ;; verifies delivery by native redisplay, without calling it.
                (emacs-tui--window-state-changed)
                (should (emacs-tui-live-p session))
                (should (eq window (emacs-tui--view-window view)))
                (should (eq preview-window (emacs-tui--view-window preview)))
                (should (equal edges (window-edges window)))
                (should (equal margins (window-margins window)))
                (should (eq (cadr emacs-tui-table-test--rows)
                            (emacs-tui-current-item session)))
                (should (equal (list (cadr emacs-tui-table-test--rows))
                               (emacs-tui-marked-items session)))
                (should (= preview-tick (buffer-chars-modified-tick
                                         (emacs-tui--view-buffer preview))))
                (with-current-buffer (emacs-tui--view-buffer view)
                  (save-excursion
                    (goto-char (point-min))
                    (while (not (eobp))
                      (should (= (string-width (buffer-substring
                                                 (line-beginning-position)
                                                 (line-end-position)))
                                 (window-max-chars-per-line window)))
                      (forward-line 1))))
                (let ((tick (buffer-chars-modified-tick (emacs-tui--view-buffer view))))
                  (emacs-tui--window-state-changed)
                  (should (= tick (buffer-chars-modified-tick
                                   (emacs-tui--view-buffer view))))))))
        (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-table-margin-refit-failure-disposes-session ()
  (dolist (failure '(error quit))
    (save-window-excursion
      (delete-other-windows)
      (let (session fail buffers caught)
        (unwind-protect
            (progn
              (setq session
                    (emacs-tui-mount
                     :views (list (emacs-tui-view
                                   :id 'rows :items '("alpha")
                                   :columns (list (emacs-tui-column
                                                   :id 'name :width 'fill
                                                   :value (lambda (item)
                                                            (when fail (signal failure nil))
                                                            item)))))))
              (setq buffers (mapcar #'emacs-tui--view-buffer
                                    (emacs-tui--workspace-views session)))
              (set-window-margins (emacs-tui--view-window
                                   (car (emacs-tui--workspace-views session))) 3 4)
              (setq fail t)
              (condition-case nil
                  (emacs-tui--window-state-changed)
                (quit (setq caught t)))
              (should (eq caught (eq failure 'quit)))
              (should-not (emacs-tui-live-p session))
              (should-not (memq session emacs-tui--sessions))
              (should-not (cl-some #'buffer-live-p buffers)))
          (when session (emacs-tui-close session)))))))

(ert-deftest emacs-tui-table-reflow-preserves-repurposed-window ()
  ;; Native modification hooks can yield to window-changing application code.
  ;; Test both the margin fast path and the ordinary explicit refresh path.
  (dolist (refit '(margins refresh))
    (save-window-excursion
      (delete-other-windows)
      (let ((foreign (generate-new-buffer " *table foreign window*"))
            session window replaced buffer (closed 0))
        (unwind-protect
            (progn
              (with-current-buffer foreign
                (insert (make-string 200 ?x) "\n" (make-string 200 ?y) "\n")
                (goto-char 220)
                (set-buffer-modified-p nil))
              (setq session
                    (emacs-tui-mount
                     :on-close (lambda (_) (cl-incf closed))
                     :views (list (emacs-tui-view
                                   :id 'rows :items '("alpha" "beta")
                                   :columns (list (emacs-tui-column
                                                   :id 'name :width 'fill
                                                   :value #'identity))))))
              (let ((view (car (emacs-tui--workspace-views session))))
                (setq window (emacs-tui--view-window view)
                      buffer (emacs-tui--view-buffer view))
                (with-current-buffer buffer
                  (add-hook 'after-change-functions
                            (lambda (&rest _)
                              (unless replaced
                                (setq replaced t)
                                (set-window-buffer window foreign)
                                (set-window-start window 202 t)
                                (set-window-point window 220)
                                (set-window-hscroll window 6)))
                            nil t))
                (if (eq refit 'margins)
                    (progn
                      (set-window-margins window 3 4)
                      (emacs-tui--window-state-changed))
                  (emacs-tui-refresh session))
                (should replaced)
                (should (window-live-p window))
                (should (eq (window-buffer window) foreign))
                (should (= 202 (window-start window)))
                (should (= 220 (window-point window)))
                (should (= 6 (window-hscroll window)))
                (with-current-buffer foreign
                  (should (equal (buffer-string)
                                 (concat (make-string 200 ?x) "\n"
                                         (make-string 200 ?y) "\n")))
                  (should-not (buffer-modified-p)))
                (should-not (emacs-tui-live-p session))
                (should-not (memq session emacs-tui--sessions))
                (should-not (buffer-live-p buffer))
                (should (= closed 1))
                (emacs-tui--window-state-changed)
                (should (= closed 1))))
          (when session (emacs-tui-close session))
          (kill-buffer foreign))))))

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

(ert-deftest emacs-tui-table-failed-update-preserves-source-selection-marks-and-display ()
  (emacs-tui-table-test--session (:multi-select t)
    (let* ((view (car (emacs-tui--workspace-views session)))
           (source (emacs-tui--view-items view)))
      (setf (emacs-tui--column-lessp (cadr (emacs-tui--view-columns view))) #'<)
      (emacs-tui-toggle-mark session)
      (emacs-tui-sort session 'rows 'size)
      (let ((visible (emacs-tui--view-visible-items view)) (display (buffer-string))
            (header header-line-format) (position (point)))
        (should-error (emacs-tui-update session 'rows :items
                                        '((:id c :label "C" :size 1)
                                          (:id d :label "D" :size "bad"))))
        (should (eq source (emacs-tui--view-items view)))
        (should (eq visible (emacs-tui--view-visible-items view)))
        (should (eq (car source) (emacs-tui-current-item session)))
        (should (equal (list (car source)) (emacs-tui-marked-items session)))
        (should (equal-including-properties display (buffer-string)))
        (should (equal header header-line-format))
        (should (= position (point)))))))

(ert-deftest emacs-tui-table-failed-projection-does-not-partially-render ()
  (emacs-tui-table-test--session (:multi-select t)
    (let* ((view (car (emacs-tui--workspace-views session)))
           (display (buffer-string)) (source (emacs-tui--view-items view)))
      (setf (emacs-tui--column-value (car (emacs-tui--view-columns view)))
            (lambda (row) (if (plist-get row :bad) (error "Bad cell") (plist-get row :label))))
      (should-error (emacs-tui-update session 'rows :items
                                      '((:id x :label "New") (:id y :label "Bad" :bad t))))
      (should (eq source (emacs-tui--view-items view)))
      (should (equal-including-properties display (buffer-string)))
      (should (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-table-failed-update-rolls-back-preview-transition ()
  (emacs-tui-table-test--session ()
    (let ((view (car (emacs-tui--workspace-views session))))
      (setf (emacs-tui--column-lessp (cadr (emacs-tui--view-columns view))) #'<)
      (emacs-tui-sort session 'rows 'size)
      (emacs-tui-update session 'rows :text "Preview")
      (should-error (emacs-tui-update session 'rows :text nil :items
                                      '((:label "A" :size 1) (:label "B" :size "bad"))))
      (should (equal "Preview" (emacs-tui--view-text view)))
      (should (equal "Preview" (buffer-string))))))

(ert-deftest emacs-tui-table-invalid-publication-keeps-last-valid-results ()
  (save-window-excursion
    (delete-other-windows)
    (let (session publish (cancelled 0))
      (unwind-protect
          (progn
            (setq session
                  (emacs-tui-mount
                   :debounce 60
                   :provider (lambda (_ _query emit _fail)
                               (setq publish emit) (lambda () (cl-incf cancelled)))
                   :views (list (emacs-tui-view
                                 :id 'rows :multi-select t
                                 :columns (list (emacs-tui-column :id 'n :value :size :lessp #'<))))))
            (let ((request (emacs-tui--workspace-request session)))
              (cancel-timer (emacs-tui--request-timer request))
              (emacs-tui--start-provider request))
            (should (funcall publish 'rows :items emacs-tui-table-test--rows))
            (emacs-tui-toggle-mark session)
            (emacs-tui-sort session 'rows 'n)
            (let ((display (buffer-string)))
              (should-not (funcall publish 'rows :items
                                   '((:id x :label "X" :size 1) (:id y :label "Y" :size "bad"))))
              (should (equal '(b a c) (emacs-tui-table-test--ids session)))
              (should (equal (list (car emacs-tui-table-test--rows)) (emacs-tui-marked-items session)))
              (should (equal-including-properties display (buffer-string)))
              (should (= 1 cancelled))
              (should-not (funcall publish 'rows :items nil))))
        (when session (emacs-tui-close session))))))


(ert-deftest emacs-tui-table-multiple-fill-shares-space-and-preserves-descriptions ()
  (let* ((a (emacs-tui-column :id 'a :value :label :width 'fill))
         (b (emacs-tui-column :id 'b :value :label :width 'fill :align 'right))
         (fixed (emacs-tui-column :id 'size :value :size :width 3))
         (columns (list a fixed b)))
    (should (emacs-tui-view :id 'rows :columns columns))
    (dolist (case '((20 7 6) (21 7 7) (8 1 1)))
      (let ((resolved (emacs-tui--table-resolve-columns columns (car case))))
        (should (equal (list (cadr case) 3 (caddr case))
                       (mapcar #'emacs-tui--column-width resolved)))
        (should (= (max 9 (car case))
                   (string-width (emacs-tui--table-line
                                  resolved '(:label "日本語abcdef" :size 7)))))
        (should (eq fixed (cadr resolved)))))
    (should (eq 'fill (emacs-tui--column-width a)))
    (should (eq 'fill (emacs-tui--column-width b)))))

(provide 'emacs-tui-table-test)
;;; emacs-tui-table-test.el ends here
