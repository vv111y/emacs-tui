;;; emacs-tui-keymap-test.el --- Native application keymap tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:GPT-6
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Application commands use ordinary maps and native interactive dispatch.

;;; Code:
(require 'ert)
(require 'emacs-tui)

(defmacro emacs-tui-keymap-test--session (form &rest body)
  "Create a session with FORM, evaluate BODY, then close."
  (declare (indent 1) (debug (form body)))
  `(save-window-excursion
     (delete-other-windows)
     (let (session)
       (unwind-protect
           (progn (setq session ,form) ,@body)
         (when session (emacs-tui-close session))))))

(ert-deftest emacs-tui-keymaps-compose-view-application-and-defaults ()
  (let ((app-map (make-sparse-keymap)) (view-map (make-sparse-keymap)) calls)
    (define-key app-map (kbd "x") (lambda () (interactive) (push 'app calls)))
    (define-key app-map (kbd "y") (lambda () (interactive) (push 'fallback calls)))
    (define-key view-map (kbd "x") (lambda () (interactive) (push 'view calls)))
    (emacs-tui-keymap-test--session
        (emacs-tui-mount :keymap app-map
                         :views (list (emacs-tui-view :id 'a :items '("A" "B") :keymap view-map)
                                      (emacs-tui-view :id 'b :items '("C"))))
      (execute-kbd-macro (kbd "x y n TAB x"))
      (should (equal '(app fallback view) calls))
      (should (equal "C" (emacs-tui-current-item session)))
      (execute-kbd-macro (kbd "<backtab>"))
      (should (equal "B" (emacs-tui-current-item session)))
      (should-not (lookup-key emacs-tui-view-mode-map (kbd "x")))
      (should-not (keymap-parent app-map))
      (should-not (keymap-parent view-map)))))

(ert-deftest emacs-tui-keymap-commands-update-current-embedded-session ()
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "r")
      (lambda () (interactive)
        (emacs-tui-update (emacs-tui-current-session) 'status :text "Updated")))
    (emacs-tui-keymap-test--session
        (emacs-tui-embed :keymap map :view (emacs-tui-view :id 'status :text "Ready"))
      (execute-kbd-macro (kbd "r"))
      (should (equal "Updated" (buffer-string)))
      (should (eq session (emacs-tui-current-session)))
      (should (emacs-tui-live-p session))
      (execute-kbd-macro (kbd "q"))
      (should-not (emacs-tui-live-p session)))))

(ert-deftest emacs-tui-keymaps-leave-query-editing-native ()
  (let ((map (make-sparse-keymap)) called)
    (define-key map (kbd "r") (lambda () (interactive) (setq called t)))
    (emacs-tui-keymap-test--session
        (emacs-tui-open :backend 'windows :keymap map
                        :views (list (emacs-tui-view :id 'a :items '("red"))))
      (execute-kbd-macro (kbd "r"))
      (should (equal "r" (emacs-tui-query session)))
      (should-not called)
      (select-window (emacs-tui--view-window (car (emacs-tui--workspace-views session))))
      (execute-kbd-macro (kbd "r"))
      (should called))))

(ert-deftest emacs-tui-keymaps-retain-live-bindings-through-reflow ()
  (let ((map (make-sparse-keymap)) called)
    (emacs-tui-keymap-test--session
        (emacs-tui-mount :keymap map :views (list (emacs-tui-view :id 'a)))
      (define-key map (kbd "x") (lambda () (interactive) (setq called t)))
      (emacs-tui-cycle-layout session)
      (execute-kbd-macro (kbd "x"))
      (should called))))

(ert-deftest emacs-tui-keymaps-reject-invalid-values-before-allocation ()
  (let ((before (buffer-list)))
    (should-error (emacs-tui-view :id 'a :keymap 1))
    (should-error (emacs-tui-mount :keymap 1 :views (list (emacs-tui-view :id 'a))))
    (should-error (emacs-tui-embed :keymap 1 :view (emacs-tui-view :id 'a)))
    (should (equal before (buffer-list)))))

(ert-deftest emacs-tui-current-session-rejects-unrelated-buffers ()
  (with-temp-buffer (should-error (emacs-tui-current-session) :type 'user-error)))

(ert-deftest emacs-tui-keymaps-preserve-prefixes-remapping-and-help-lookup ()
  (let ((app-map (make-sparse-keymap)) (view-map (make-sparse-keymap)) calls)
    (define-key app-map (kbd "C-c a") (lambda () (interactive) (push 'app calls)))
    (define-key view-map (kbd "C-c b") #'ignore)
    (define-key view-map [remap emacs-tui-next-item]
      (lambda () (interactive) (push 'remapped calls)))
    (emacs-tui-keymap-test--session
        (emacs-tui-mount :keymap app-map
                         :views (list (emacs-tui-view :id 'a :keymap view-map
                                                     :items '("A" "B"))))
      (execute-kbd-macro (kbd "C-c a C-c b n"))
      (should (equal '(remapped app) calls))
      (should (equal "A" (emacs-tui-current-item session)))
      (should (member (vconcat (kbd "C-c b"))
                      (where-is-internal #'ignore (current-local-map)))))))

(provide 'emacs-tui-keymap-test)
;;; emacs-tui-keymap-test.el ends here
