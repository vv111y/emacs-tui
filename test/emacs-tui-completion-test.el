;;; emacs-tui-completion-test.el --- Native completion protocol and ownership -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Real completion tables/styles and source editing run on every supported
;; version.  Only popup presentation is modeled here; tty-completion-smoke.el
;; requires actual painted child frames on supporting terminals.

;;; Code:
(require 'ert)
(require 'cl-lib)
(require 'emacs-tui-completion)
(require 'emacs-tui-popup-demo (expand-file-name "../examples/emacs-tui-popup-demo.el"
                                                      (file-name-directory (or load-file-name buffer-file-name))))

(defvar emacs-tui-completion-test--popups nil)

(defmacro emacs-tui-completion-test--source (&rest body)
  "Run BODY in a real input buffer with modeled popup presentation."
  (declare (indent 0) (debug body))
  `(save-window-excursion
     (let ((source (generate-new-buffer " *completion source*"))
           (emacs-tui-completion-test--popups nil)
           (completion-styles '(basic))
           (completion-category-defaults nil)
           (completion-category-overrides nil))
       (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) t))
                 ((symbol-function 'emacs-tui-popup)
                  (lambda (&rest options)
                    (let ((app (emacs-tui--make-workspace
                                :active t :views (list (plist-get options :view)))))
                      (push (cons app (plist-get options :on-close))
                            emacs-tui-completion-test--popups)
                      app)))
                 ((symbol-function 'emacs-tui-update)
                  (lambda (app _id &rest options)
                    (let ((view (car (emacs-tui--workspace-views app))))
                      (setf (emacs-tui--view-items view) (plist-get options :items)
                            (emacs-tui--view-title view) (plist-get options :title)))))
                 ((symbol-function 'emacs-tui-current-item)
                  (lambda (app)
                    (let ((view (car (emacs-tui--workspace-views app))))
                      (nth (emacs-tui--view-selected view) (emacs-tui--view-items view)))))
                 ((symbol-function 'emacs-tui-close)
                  (lambda (app)
                    (when (emacs-tui-live-p app)
                      (setf (emacs-tui--workspace-active app) nil)
                      (funcall (cdr (assq app emacs-tui-completion-test--popups)) app)))))
         (unwind-protect
             (progn (switch-to-buffer source) (emacs-tui-completion-mode 1) ,@body)
           (when (buffer-live-p source)
             (with-current-buffer source (emacs-tui-completion-mode -1))
             (kill-buffer source)))))))

(defun emacs-tui-completion-test--items ()
  "Return the active popup's displayed candidate descriptions."
  (emacs-tui--view-items
   (car (emacs-tui--workspace-views (emacs-tui-completion--session)))))

(ert-deftest emacs-tui-completion-native-capf-captures-metadata-and-exit ()
  (emacs-tui-completion-test--source
    (let (exits (calls 0))
      (setq-local completion-at-point-functions
                  (list (lambda ()
                          (cl-incf calls)
                          (list 1 (point-max) '("mapcar" "mapconcat")
                                :annotation-function (lambda (_raw) " [function]")
                                :exit-function (lambda (text status) (push (list text status) exits))))))
      (insert "ma")
      (let ((text (buffer-string)) (point (point)) (undo buffer-undo-list))
        (should (completion-at-point))
        (should (equal "mapcar [function]" (plist-get (car (emacs-tui-completion-test--items)) :label)))
        (should (equal text (buffer-string))) (should (= point (point)))
        (should (equal undo buffer-undo-list)))
      (insert "p")
      (emacs-tui-completion--post-command)
      (should (>= calls 2))
      (should-not exits)
      (emacs-tui-completion-accept)
      (should (equal "mapcar" (buffer-string)))
      (should (equal '(("mapcar" finished)) exits))
      (should-not emacs-tui-completion--context)
      (should-not emacs-tui-completion--active))))

(ert-deftest emacs-tui-completion-respects-predicate-style-and-category ()
  (emacs-tui-completion-test--source
    (insert "car")
    (let ((completion-category-overrides '((test-function (styles substring))))
          (table (lambda (string pred action)
                   (if (eq action 'metadata) '(metadata (category . test-function))
                     (complete-with-action action '("mapcar" "caravan" "mapconcat") string pred)))))
      (completion-in-region 1 (point) table (lambda (raw) (not (equal raw "caravan"))))
      (should (equal '("mapcar") (mapcar (lambda (item) (plist-get item :value))
                                       (emacs-tui-completion-test--items))))
      (emacs-tui-completion-accept)
      (should (equal "mapcar" (buffer-string))))))

(ert-deftest emacs-tui-completion-base-prefix-and-outside-suffix-survive-acceptance ()
  (emacs-tui-completion-test--source
    (let ((directory (make-temp-file "tui-completion-" t)) exits)
      (unwind-protect
          (let* ((prefix (file-name-as-directory directory))
                 (table (lambda (string pred action)
                          (if (eq action 'metadata) '(metadata (category . file))
                            (complete-with-action action #'read-file-name-internal string pred))))
                 (completion-extra-properties
                  (list :exit-function (lambda (text status) (push (list text status) exits)))))
            (make-directory (expand-file-name "alpha" directory))
            (make-directory (expand-file-name "alpine" directory))
            (insert prefix "al/keep.txt")
            (goto-char (+ 1 (length prefix) 2))
            (should (completion-in-region 1 (point-max) table))
            (let ((context emacs-tui-completion--context))
              (should (= (+ 1 (length prefix))
                         (plist-get (emacs-tui--completion-projection context) :begin))))
            (let ((raw (plist-get (car (emacs-tui-completion-test--items)) :value)))
              (should (member raw '("alpha/" "alpine/")))
              (emacs-tui-completion-accept)
              (should (equal (concat prefix raw "keep.txt") (buffer-string)))
              (should (equal (list (list (concat prefix raw) 'exact)) exits))
              (should (= (point) (+ 1 (length prefix) (length raw))))))
        (delete-directory directory t)))))

(ert-deftest emacs-tui-completion-affixation-overrides-annotation-and-bounds-decoration ()
  (emacs-tui-completion-test--source
    (insert "a")
    (let* ((emacs-tui-completion-limit 2) decorated
           (completion-extra-properties
            (list :display-sort-function (lambda (all) (sort all (lambda (a b) (string< b a))))
                  :annotation-function (lambda (_) (error "Annotation must not run"))
                  :affixation-function
                  (lambda (all)
                    (setq decorated (copy-sequence all))
                    (mapcar (lambda (raw) (list raw "<" ">")) all)))))
      (completion-in-region 1 (point) '("aa" "ab" "ac"))
      (should (equal '("ac" "ab") decorated))
      (should (equal '("<ac>" "<ab>")
                     (mapcar (lambda (item) (plist-get item :label))
                             (emacs-tui-completion-test--items))))
      (emacs-tui-completion-accept)
      (should (equal "ac" (buffer-string))))))

(ert-deftest emacs-tui-completion-refresh-reuses-popup-and-preserves-raw-value ()
  (emacs-tui-completion-test--source
    (let ((completion-extra-properties
           (list :annotation-function (lambda (_) "\nNOT-INSERTED\t"))))
      (insert "a")
      (completion-in-region 1 (point) '("alpha" "alpine" "azure"))
      (let ((app (emacs-tui-completion--session)))
        (insert "l") (emacs-tui-completion--post-command)
        (should (eq app (emacs-tui-completion--session)))
        (should (= 1 (length emacs-tui-completion-test--popups)))
        (should (equal "alpha\\nNOT-INSERTED\\t"
                       (plist-get (car (emacs-tui-completion-test--items)) :label)))
        (emacs-tui-completion-accept)
        (should (equal "alpha" (buffer-string)))
        (should-not (text-properties-at 1))))))

(ert-deftest emacs-tui-completion-no-match-and-provider-errors-leak-no-context ()
  (emacs-tui-completion-test--source
    (insert "z")
    (should-not (completion-in-region 1 (point) '("alpha")))
    (should-not emacs-tui-completion--context)
    (should-not emacs-tui-completion-test--popups)
    (let ((completion-extra-properties
           (list :affixation-function (lambda (_) '(("foreign" "" ""))))))
      (erase-buffer) (insert "a")
      (should-error (completion-in-region 1 (point) '("alpha")))
      (should-not emacs-tui-completion--context)
      (should-not emacs-tui-completion--active)
      (should (equal "a" (buffer-string))))))

(ert-deftest emacs-tui-completion-stale-selection-and-context-are-rejected ()
  (emacs-tui-completion-test--source
    (let* ((words '("alpha" "alpine")) (valid t)
           (table (lambda (s p a) (complete-with-action a words s p)))
           (completion-in-region-mode-predicate (lambda () valid)))
      (insert "a") (completion-in-region 1 (point) table)
      (setq words '("alpine"))
      (should-error (emacs-tui-completion-accept) :type 'user-error)
      (should (equal "a" (buffer-string)))
      (should-not emacs-tui-completion--context)
      (completion-in-region 1 (point) table)
      (setq valid nil)
      (should-error (emacs-tui-completion-accept) :type 'user-error)
      (should (equal "a" (buffer-string)))
      (should-not emacs-tui-completion--context)
      (setq valid t)
      (completion-in-region 1 (point) table)
      (insert "l")
      (should-error (emacs-tui-completion-accept) :type 'user-error)
      (should (equal "al" (buffer-string))))))

(ert-deftest emacs-tui-completion-edit-failure-keeps-popup-exit-error-does-not-undo ()
  (emacs-tui-completion-test--source
    (let* ((calls 0)
          (completion-extra-properties
           (list :exit-function (lambda (_text _status) (cl-incf calls) (error "Exit failed")))))
      (insert "a") (completion-in-region 1 (point) '("alpha"))
      (let ((buffer-read-only t))
        (should-error (emacs-tui-completion-accept) :type 'buffer-read-only)
        (should (emacs-tui-live-p (emacs-tui-completion--session)))
        (should (equal "a" (buffer-string))) (should (= 0 calls)))
      (should-error (emacs-tui-completion-accept))
      (should (= 1 calls))
      (should (equal "alpha" (buffer-string)))
      (should-not emacs-tui-completion--context)
      (should-error (emacs-tui-completion-accept) :type 'user-error)
      (should (= 1 calls)))))

(ert-deftest emacs-tui-completion-frontend-restoration-respects-locality-and-takeover ()
  (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) t)))
    (let ((original (default-value 'completion-in-region-function)))
      (unwind-protect
          (progn
            (with-temp-buffer
              (emacs-tui-completion-mode 1)
              (emacs-tui-completion-mode 1)
              (setq-default completion-in-region-function #'ignore)
              (emacs-tui-completion-mode -1)
              (should-not (local-variable-p 'completion-in-region-function))
              (should (eq completion-in-region-function #'ignore)))
            (with-temp-buffer
              (setq-local completion-in-region-function #'ignore)
              (emacs-tui-completion-mode 1)
              (emacs-tui-completion-mode -1)
              (should (local-variable-p 'completion-in-region-function))
              (should (eq completion-in-region-function #'ignore))
              (emacs-tui-completion-mode 1)
              (setq-local completion-in-region-function #'identity)
              (emacs-tui-completion-mode -1)
              (should (eq completion-in-region-function #'identity))))
        (setq-default completion-in-region-function original)))))

(ert-deftest emacs-tui-completion-bindings-only-while-visible-and-major-mode-cleanup ()
  (emacs-tui-completion-test--source
    (let ((tab (key-binding (kbd "TAB"))) (quit (key-binding (kbd "C-g"))))
      (insert "a") (completion-in-region 1 (point) '("alpha"))
      (should (eq #'emacs-tui-completion-accept (key-binding (kbd "TAB"))))
      (should (eq #'emacs-tui-completion-dismiss (key-binding (kbd "C-g"))))
      (emacs-tui-completion-dismiss)
      (should (eq tab (key-binding (kbd "TAB"))))
      (should (eq quit (key-binding (kbd "C-g"))))
      (completion-in-region 1 (point) '("alpha"))
      (let ((app (emacs-tui-completion--session))
            (context emacs-tui-completion--context))
        (text-mode)
        (should-not (emacs-tui-live-p app))
        (should-not (marker-buffer (emacs-tui--completion-begin context)))
        (should-not emacs-tui-completion-mode)
        (should-not (memq #'emacs-tui-completion--post-command post-command-hook))))))

(ert-deftest emacs-tui-completion-late-close-callback-preserves-new-session ()
  (emacs-tui-completion-test--source
    (insert "a") (completion-in-region 1 (point) '("alpha"))
    (let* ((old (emacs-tui-completion--session))
           (callback (cdr (assq old emacs-tui-completion-test--popups))))
      (completion-in-region 1 (point) '("alpine"))
      (let ((new emacs-tui-completion--context))
        (funcall callback old)
        (should (eq new emacs-tui-completion--context))
        (should (emacs-tui-live-p (emacs-tui-completion--session)))
        (should emacs-tui-completion--active)))))

(ert-deftest emacs-tui-completion-window-departure-and-narrowing-release-context ()
  (emacs-tui-completion-test--source
    (insert "alpha") (goto-char 3)
    (completion-in-region 1 (point-max) '("alpha" "alpine"))
    (let ((app (emacs-tui-completion--session))
          (context emacs-tui-completion--context))
      (narrow-to-region 2 (point-max))
      (emacs-tui-completion--post-command)
      (should-not (emacs-tui-live-p app))
      (should-not (marker-buffer (emacs-tui--completion-end context)))
      (should-not emacs-tui-completion--active))
    (widen) (goto-char 2)
    (completion-in-region 1 (point-max) '("alpha"))
    (let ((app (emacs-tui-completion--session))
          (other (split-window-below)))
      (select-window other)
      (emacs-tui-completion--post-command)
      (should-not (emacs-tui-live-p app))
      (should (eq other (selected-window)))
      (should (equal "alpha" (buffer-string))))))

(ert-deftest emacs-tui-completion-two-source-contexts-close-independently ()
  (emacs-tui-completion-test--source
    (insert "a") (completion-in-region 1 (point) '("alpha"))
    (let ((first emacs-tui-completion--context)
          (other (generate-new-buffer " *other completion*")))
      (unwind-protect
          (progn
            (switch-to-buffer other)
            (emacs-tui-completion-mode 1)
            (insert "b") (completion-in-region 1 (point) '("beta"))
            (let ((second emacs-tui-completion--context))
              (emacs-tui-completion--release first)
              (should (eq second emacs-tui-completion--context))
              (should (emacs-tui-live-p (emacs-tui-completion--session)))
              (with-current-buffer source
                (should-not emacs-tui-completion--context)
                (should-not emacs-tui-completion--active))
              (emacs-tui-completion-accept)
              (should (equal "beta" (buffer-string)))))
        (when (buffer-live-p other) (kill-buffer other))))))

(ert-deftest emacs-tui-completion-insertion-hook-error-rolls-back-and-refreshes-for-retry ()
  (emacs-tui-completion-test--source
    (insert "a") (completion-in-region 1 (point) '("alpha"))
    (let ((app (emacs-tui-completion--session))
          (hook (lambda (_begin _end old-length)
                  (when (= 0 old-length) (error "Insertion rejected")))))
      (add-hook 'after-change-functions hook nil t)
      (should-error (emacs-tui-completion-accept))
      (remove-hook 'after-change-functions hook t)
      (should (equal "a" (buffer-string)))
      (should (emacs-tui-live-p app))
      (emacs-tui-completion--post-command)
      (should (emacs-tui-live-p app))
      (emacs-tui-completion-accept)
      (should (equal "alpha" (buffer-string))))))

(ert-deftest emacs-tui-completion-accepting-hook-can-start-another-context ()
  (emacs-tui-completion-test--source
    (let* (exits
           (completion-extra-properties
            (list :exit-function (lambda (text status) (push (list text status) exits)))))
      (insert "a") (completion-in-region 1 (point) '("alpha"))
      (let* ((old emacs-tui-completion--context)
             (hook (lambda (_begin _end old-length)
                     (when (= 0 old-length)
                       (let ((completion-extra-properties nil))
                         (completion-in-region 1 (point-max) '("alphabet")))))))
        (add-hook 'after-change-functions hook nil t)
        (unwind-protect (emacs-tui-completion-accept)
          (remove-hook 'after-change-functions hook t))
        (should (equal "alpha" (buffer-string)))
        (should (equal '(("alpha" finished)) exits))
        (should-not (eq old emacs-tui-completion--context))
        (should-not (marker-buffer (emacs-tui--completion-begin old)))
        (should (emacs-tui-live-p (emacs-tui-completion--session)))
        (should emacs-tui-completion--active)
        (emacs-tui-completion-accept)
        (should (equal "alphabet" (buffer-string)))
        (should (= 1 (length exits)))))))

(ert-deftest emacs-tui-completion-dynamic-ignore-case-reaches-metadata-and-exit ()
  (emacs-tui-completion-test--source
    (let* (observed
           (completion-extra-properties
            (list :display-sort-function
                  (lambda (all) (push (list 'sort completion-ignore-case) observed) all)
                  :annotation-function
                  (lambda (_raw) (push (list 'annotation completion-ignore-case) observed) "")
                  :exit-function
                  (lambda (_text _status) (push (list 'exit completion-ignore-case) observed)))))
      (insert "A")
      (let ((completion-ignore-case t))
        (completion-in-region 1 (point) '("alpha" "alpine")))
      (insert "L") (emacs-tui-completion--post-command)
      (emacs-tui-completion-accept)
      (should (equal "alpha" (buffer-string)))
      (should (assq 'exit observed))
      (should (cl-every (lambda (event) (eq t (cadr event))) observed)))))

(ert-deftest emacs-tui-completion-invalid-display-limit-does-not-silently-hide-matches ()
  (emacs-tui-completion-test--source
    (insert "a")
    (dolist (emacs-tui-completion-limit '(0 -1 1.5))
      (should-error (completion-in-region 1 (point) '("alpha")) :type 'user-error)
      (should-not emacs-tui-completion--context)
      (should-not emacs-tui-completion--active)
      (should (equal "a" (buffer-string))))))

(ert-deftest emacs-tui-completion-preserves-native-nil-category-metadata-overrides ()
  (emacs-tui-completion-test--source
    (insert "a")
    (let* ((completion-category-overrides
            '((tui-test (annotation-function . nil) (display-sort-function . nil))))
           (completion-extra-properties
            (list :annotation-function (lambda (_) " EXTRA")
                  :display-sort-function (lambda (all) (reverse all))))
           (table (lambda (string pred action)
                    (if (eq action 'metadata) '(metadata (category . tui-test))
                      (complete-with-action action '("alpha" "alpine") string pred)))))
      (completion-in-region 1 (point) table)
      (should (equal (if emacs-tui-completion--metadata-extra-p
                         '("alpha" "alpine") '("alpine EXTRA" "alpha EXTRA"))
                     (mapcar (lambda (item) (plist-get item :label))
                             (emacs-tui-completion-test--items)))))))

(ert-deftest emacs-tui-completion-unsupported-mode-does-not-claim-frontend ()
  (with-temp-buffer
    (let ((old completion-in-region-function))
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) nil)))
        (should-error (emacs-tui-completion-mode 1) :type 'user-error))
      (should-not emacs-tui-completion-mode)
      (should-not (local-variable-p 'completion-in-region-function))
      (should (eq old completion-in-region-function)))))

(ert-deftest emacs-tui-popup-demo-major-mode-change-closes-owned-session ()
  (emacs-tui-completion-test--source
    (emacs-tui-popup-demo-mode 1)
    (insert "ma") (emacs-tui-popup-demo--refresh)
    (let ((app emacs-tui-popup-demo--session))
      (should (emacs-tui-live-p app))
      (text-mode)
      (should-not (emacs-tui-live-p app))
      (should-not emacs-tui-popup-demo-mode))))

(provide 'emacs-tui-completion-test)
;;; emacs-tui-completion-test.el ends here
