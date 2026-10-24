;;; emacs-tui-demo-test.el --- Exercise the graph application -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Test the example through its public commands and explicit commit boundary.

;;; Code:
(require 'ert)
(require 'emacs-tui-demo (expand-file-name "examples/emacs-tui-demo.el"))

(defmacro emacs-tui-demo-test--workspace (&rest body)
  "Open the graph demo, evaluate BODY, then release its resources."
  (declare (indent 0) (debug body))
  `(save-window-excursion
     (delete-other-windows)
     (let ((source (generate-new-buffer " *tui-demo-test*")) session)
       (unwind-protect
           (progn
             (switch-to-buffer source)
             (insert "Origin:")
             (setq session (emacs-tui-demo))
             ,@body)
         (when session (emacs-tui-close session))
         (when (buffer-live-p source) (kill-buffer source))))))

(ert-deftest emacs-tui-demo-batch-commit-is-explicit-and-source-ordered ()
  (emacs-tui-demo-test--workspace
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-previous-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-select session)
    (should (equal (with-current-buffer source (buffer-string)) "Origin:"))
    (emacs-tui-commit session)
    (should (equal (with-current-buffer source (buffer-string))
                   "Origin:[[demo:emacs][Emacs]]\n[[demo:org][Org]]"))))

(ert-deftest emacs-tui-demo-node-query-does-not-hide-forward-links ()
  (emacs-tui-demo-test--workspace
    (insert "Emacs")
    (emacs-tui-select session)
    (emacs-tui-next-view session)
    (emacs-tui-next-view session)
    (should (equal (plist-get (emacs-tui-current-item session) :id) "org"))
    (emacs-tui-next-item session)
    (should (equal (plist-get (emacs-tui-current-item session) :id) "lisp"))
    (should (equal (with-current-buffer source (buffer-string)) "Origin:"))))

(ert-deftest emacs-tui-demo-bulk-marks-commit-filtered-graph-results-explicitly ()
  (emacs-tui-demo-test--workspace
    (execute-kbd-macro (kbd "E m a c s C-c *"))
    (should (equal "Emacs" (emacs-tui-query session)))
    (should (equal '("emacs" "lisp")
                   (mapcar (lambda (item) (plist-get item :id))
                           (emacs-tui-marked-items session 'nodes))))
    (should (equal "RET to inspect a node"
                   (emacs-tui--view-text (emacs-tui--resolve-view session 'preview))))
    (execute-kbd-macro (kbd "C-c C-t"))
    (should-not (emacs-tui-marked-items session 'nodes))
    (execute-kbd-macro (kbd "C-c * RET"))
    (should (equal "Origin:" (with-current-buffer source (buffer-string))))
    (emacs-tui-commit session)
    (should (equal "Origin:[[demo:emacs][Emacs]]\n[[demo:lisp][Emacs Lisp]]"
                   (with-current-buffer source (buffer-string))))))

(defun emacs-tui-demo-test--preview (session)
  "Read SESSION's inspected-node preview."
  (emacs-tui--view-text (emacs-tui--resolve-view session 'preview)))

(defun emacs-tui-demo-test--visit (session id)
  "Explicitly inspect node ID from SESSION's node list."
  (emacs-tui-focus-view session 'nodes)
  (emacs-tui-set-selection session 'nodes id)
  (emacs-tui-select session))

(ert-deftest emacs-tui-demo-history-follows-forward-and-backlinks ()
  (emacs-tui-demo-test--workspace
    (should-error (emacs-tui-act session 'back) :type 'user-error)
    (should-error (emacs-tui-act session 'forward) :type 'user-error)
    (emacs-tui-demo-test--visit session "emacs")
    (should-error (emacs-tui-act session 'back) :type 'user-error)
    (emacs-tui-focus-view session 'links)
    (emacs-tui-select session) ; Emacs -> Org.
    (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session)))
    (emacs-tui-act session 'back)
    (should (string-prefix-p "Emacs\n" (emacs-tui-demo-test--preview session)))
    (should (equal "org" (plist-get (emacs-tui-current-item session 'links) :id)))
    (emacs-tui-act session 'forward)
    (emacs-tui-focus-view session 'backlinks)
    (emacs-tui-set-selection session 'backlinks "graph")
    (emacs-tui-select session) ; Org <- Knowledge graph.
    (should (string-prefix-p "Knowledge graph\n" (emacs-tui-demo-test--preview session)))
    (emacs-tui-act session 'back)
    (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session)))
    (emacs-tui-act session 'back)
    (should (string-prefix-p "Emacs\n" (emacs-tui-demo-test--preview session)))
    (should-error (emacs-tui-act session 'back) :type 'user-error)
    (should (emacs-tui-live-p session))
    (should (equal "Origin:" (with-current-buffer source (buffer-string))))))

(ert-deftest emacs-tui-demo-history-reinspection-and-new-branch ()
  (emacs-tui-demo-test--workspace
    (emacs-tui-demo-test--visit session "emacs")
    (emacs-tui-demo-test--visit session "org")
    (emacs-tui-demo-test--visit session "org")
    (emacs-tui-demo-test--visit session "graph")
    (emacs-tui-act session 'back)
    (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session)))
    ;; Reinspection after Back preserves the forward route to Graph.
    (emacs-tui-set-selection session 'nodes "org")
    (emacs-tui-select session)
    (emacs-tui-act session 'forward)
    (should (string-prefix-p "Knowledge graph\n" (emacs-tui-demo-test--preview session)))
    (emacs-tui-act session 'back)
    (emacs-tui-demo-test--visit session "lisp")
    (should-error (emacs-tui-act session 'forward) :type 'user-error)
    (emacs-tui-act session 'back)
    (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session)))
    (emacs-tui-act session 'back)
    (should (string-prefix-p "Emacs\n" (emacs-tui-demo-test--preview session)))
    (should-error (emacs-tui-act session 'back) :type 'user-error)))

(ert-deftest emacs-tui-demo-history-is-independent-of-query-focus-and-node-marks ()
  (emacs-tui-demo-test--workspace
    (execute-kbd-macro (kbd "E m a c s C-c * RET"))
    (emacs-tui-focus-view session 'links)
    (emacs-tui-select session)
    (emacs-tui-focus-view session 'preview)
    (let ((query-buffer (current-buffer)) (position (point)))
      ;; Empty-target preview actions are available from native query input.
      (cl-letf (((symbol-function 'completing-read)
                 (lambda (_prompt choices &rest _)
                   (should (equal '("Back (back)") (mapcar #'car choices)))
                   "Back (back)")))
        (execute-kbd-macro (kbd "C-c C-a")))
      (should (eq (emacs-tui-current-view session) 'preview))
      (should (eq (current-buffer) query-buffer))
      (should (= (point) position))
      (should (equal "Emacs" (emacs-tui-query session)))
      (should (equal '("emacs" "lisp")
                     (mapcar (lambda (item) (plist-get item :id))
                             (emacs-tui-marked-items session 'nodes))))
      (emacs-tui-act session 'forward)
      (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session))))
    (should (equal "Origin:" (with-current-buffer source (buffer-string))))))

(ert-deftest emacs-tui-demo-history-ignores-noninspection-navigation ()
  (emacs-tui-demo-test--workspace
    (emacs-tui-next-item session)
    (emacs-tui-toggle-mark session)
    (emacs-tui-next-view session)
    (emacs-tui-cycle-layout session)
    (emacs-tui-toggle-maximize session)
    (insert "Emacs")
    (should (equal "RET to inspect a node" (emacs-tui-demo-test--preview session)))
    (should-error (emacs-tui-act session 'back) :type 'user-error)
    (should-error (emacs-tui-act session 'forward) :type 'user-error)))

(ert-deftest emacs-tui-demo-history-failed-inspection-keeps-stacks-for-retry ()
  (emacs-tui-demo-test--workspace
    (emacs-tui-demo-test--visit session "emacs")
    (emacs-tui-demo-test--visit session "org")
    (let ((update (symbol-function 'emacs-tui-update)))
      (cl-letf (((symbol-function 'emacs-tui-update)
                 (lambda (app id &rest args)
                   (if (eq id 'links) (error "Display failure")
                     (apply update app id args)))))
        (should-error (emacs-tui-act session 'back)))
      (should-error (emacs-tui-act session 'forward) :type 'user-error)
      (emacs-tui-act session 'back)
      (should (string-prefix-p "Emacs\n" (emacs-tui-demo-test--preview session)))
      (should-error (emacs-tui-act session 'back) :type 'user-error)
      (emacs-tui-act session 'forward)
      (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session)))
      ;; A failed fresh visit must not create an entry or discard the future.
      (emacs-tui-act session 'back)
      (cl-letf (((symbol-function 'emacs-tui-update)
                 (lambda (&rest _) (error "Display failure"))))
        (should-error (emacs-tui-demo-test--visit session "lisp")))
      (emacs-tui-act session 'forward)
      (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session))))))

(ert-deftest emacs-tui-demo-history-native-view-keys-and-explicit-commit ()
  (emacs-tui-demo-test--workspace
    (emacs-tui-demo-test--visit session "emacs")
    (emacs-tui-demo-test--visit session "org")
    (emacs-tui-focus-view session 'preview)
    (let* ((view (emacs-tui--resolve-view session 'preview))
           (query (emacs-tui--workspace-query-buffer session)))
      (with-selected-window (emacs-tui--view-window view)
        (execute-kbd-macro (kbd "C-c ["))
        (should (string-prefix-p "Emacs\n" (emacs-tui-demo-test--preview session)))
        (execute-kbd-macro (kbd "C-c ]"))
        (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session))))
      (should (eq (window-buffer (selected-window)) query)))
    ;; History is inspection, not a hidden commit target: commit still uses
    ;; the explicit focused selection, even if another node is being previewed.
    (emacs-tui-focus-view session 'nodes)
    (emacs-tui-set-selection session 'nodes "lisp")
    (should (equal "Origin:" (with-current-buffer source (buffer-string))))
    (emacs-tui-commit session)
    (should (equal "Origin:[[demo:lisp][Emacs Lisp]]"
                   (with-current-buffer source (buffer-string))))))

(ert-deftest emacs-tui-demo-history-sessions-are-independent ()
  (emacs-tui-demo-test--workspace
    (emacs-tui-demo-test--visit session "emacs")
    (emacs-tui-demo-test--visit session "org")
    (select-window (get-buffer-window source))
    (let ((other (emacs-tui-demo)))
      (unwind-protect
          (progn
            (should-error (emacs-tui-act other 'back) :type 'user-error)
            (emacs-tui-demo-test--visit other "lisp")
            (emacs-tui-demo-test--visit other "graph")
            (emacs-tui-act other 'back)
            (should (string-prefix-p "Emacs Lisp\n" (emacs-tui-demo-test--preview other)))
            (should (string-prefix-p "Org\n" (emacs-tui-demo-test--preview session))))
        (emacs-tui-close other)))
    (emacs-tui-act session 'back)
    (should (string-prefix-p "Emacs\n" (emacs-tui-demo-test--preview session)))
    (emacs-tui-close session)
    (should-error (emacs-tui-act session 'forward) :type 'user-error)))

(provide 'emacs-tui-demo-test)
;;; emacs-tui-demo-test.el ends here
