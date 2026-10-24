;;; tty-tree-smoke.el --- Exercise real TTY tree interaction -*- lexical-binding: t; -*-
(setq load-prefer-newer t)
(require 'cl-lib)
(require 'emacs-tui)

(defvar emacs-tui-test--tree-session nil)
(defvar emacs-tui-test--tree-phase 1)
(defvar emacs-tui-test--tree-attempts 0)
(defvar emacs-tui-test--tree-small-width nil)
(defvar emacs-tui-test--tree-actions 0)

(defun emacs-tui-test--tree-items (label)
  (list (list :id 'root :label "Root" :children (list (list :id 'leaf :label label)))))

(defun emacs-tui-test--tree-failure (err)
  (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT") (insert (format "FAIL tree: %S\n" err)))
  (kill-emacs 1))

(defun emacs-tui-test--tree-resized ()
  (condition-case err
      (let* ((session emacs-tui-test--tree-session)
             (parent (emacs-tui--workspace-origin-frame session))
             (child (emacs-tui--workspace-frame session))
             (phase emacs-tui-test--tree-phase)
             (width (if (= phase 1) 90 140))
             (height (if (= phase 1) 30 45)))
        (cl-incf emacs-tui-test--tree-attempts)
        (when (> emacs-tui-test--tree-attempts 100) (error "Tree resize did not settle"))
        (redisplay t)
        (when (and (= (frame-width parent) width)
                   (<= (- height 2) (frame-height parent) height)
                   (or (not child)
                       (and (< (frame-width child) width) (< (frame-height child) height)
                            (or (= phase 1) (> (frame-width child) emacs-tui-test--tree-small-width)))))
          (cl-assert (emacs-tui-live-p session))
          (cl-assert (eq 'leaf (plist-get (emacs-tui-current-item session) :id)))
          (cl-assert (equal "Updated" (plist-get (car (emacs-tui-marked-items session)) :label)))
          (cl-assert (= 2 (length (emacs-tui--view-visible-items (emacs-tui--focused-view session)))))
          (cl-assert (= 1 emacs-tui-test--tree-actions))
          (if (= phase 1)
              (progn
                (setq emacs-tui-test--tree-small-width (when child (frame-width child))
                      emacs-tui-test--tree-phase 2
                      emacs-tui-test--tree-attempts 0)
                (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "2")))
            (execute-kbd-macro (kbd "RET TAB"))
            (cl-assert (= 2 emacs-tui-test--tree-actions))
            (cl-assert (equal "Updated" (buffer-string)))
            (execute-kbd-macro (kbd "q"))
            (cl-assert (not (emacs-tui-live-p session)))
            (cl-assert (null emacs-tui--sessions))
            (with-temp-file (getenv "EMACS_TUI_SMOKE_REPORT")
              (insert (format "PASS Emacs %s; real TTY; backend=%s; tree=expand/collapse; marks=passed; update=passed; resize=120x40->90x30->140x45\n"
                              emacs-version (emacs-tui--workspace-backend session))))
            (kill-emacs 0))))
    ((error quit) (emacs-tui-test--tree-failure err))))

(defun emacs-tui-test--tree-start ()
  (condition-case err
      (progn
        (setq emacs-tui-test--tree-session
              (emacs-tui-mount
               :backend (if (featurep 'tty-child-frames) 'child-frame 'windows)
               :views (list (emacs-tui-tree
                             :id 'tree :multi-select t :items (emacs-tui-test--tree-items "Leaf")
                             :on-select (lambda (app item)
                                          (cl-incf emacs-tui-test--tree-actions)
                                          (emacs-tui-update app 'preview :text (plist-get item :label))))
                            (emacs-tui-view :id 'preview :text ""))))
        (execute-kbd-macro (kbd "<right> <right> C-c C-m RET <left> <left>"))
        (cl-assert (= 1 (length (emacs-tui--view-visible-items
                                (emacs-tui--focused-view emacs-tui-test--tree-session)))))
        (cl-assert (= 1 (length (emacs-tui-marked-items emacs-tui-test--tree-session))))
        (execute-kbd-macro (kbd "SPC <right>"))
        (emacs-tui-update emacs-tui-test--tree-session 'tree :items (emacs-tui-test--tree-items "Updated"))
        (redisplay t)
        (with-temp-file (getenv "EMACS_TUI_SMOKE_READY") (insert "1"))
        (run-at-time 0.05 0.05 #'emacs-tui-test--tree-resized))
    ((error quit) (emacs-tui-test--tree-failure err))))

(add-hook 'emacs-startup-hook (lambda () (run-at-time 0.1 nil #'emacs-tui-test--tree-start)))
