;;; emacs-tui-popup-test.el --- Anchored popup geometry and ownership -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Geometry and failure paths work on the declared floor.  Positive native
;; presentation, real focus and typed input are covered by tty-popup-smoke.el.

;;; Code:
(require 'ert)
(require 'cl-lib)
(require 'emacs-tui)
(require 'emacs-tui-gallery (expand-file-name "../examples/emacs-tui-gallery.el"
                                                   (file-name-directory (or load-file-name buffer-file-name))))
(require 'emacs-tui-popup-demo (expand-file-name "../examples/emacs-tui-popup-demo.el"
                                                      (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest emacs-tui-popup-eight-positions-surround-the-whole-word ()
  (let ((expected '((45 33 20 6) (61 33 20 6) (61 38 20 6) (61 43 20 6)
                    (45 43 20 6) (29 43 20 6) (29 38 20 6) (29 33 20 6))))
    (should (equal expected
                   (mapcar (lambda (position)
                             (emacs-tui-layout-popup '(50 40 10 2) 20 6 '(0 0 120 80)
                                                     position '(1 . 1)))
                           emacs-tui-layout-popup-positions)))))

(ert-deftest emacs-tui-popup-clamps-all-edges-and-validates-before-placement ()
  (dolist (position emacs-tui-layout-popup-positions)
    (should (equal '(5 7 20 10)
                   (emacs-tui-layout-popup '(5 7 1 1) 40 30 '(5 7 20 10) position)))
    (dolist (anchor '((0 0 1 1) (99 0 1 1) (0 39 1 1) (99 39 1 1)))
      (pcase-let ((`(,x ,y ,w ,h)
                   (emacs-tui-layout-popup anchor 20 8 '(0 0 100 40) position)))
        (should (<= 0 x (- 100 w)))
        (should (<= 0 y (- 40 h))))))
  (dolist (args '(((1 2 0 4) 2 2 (0 0 20 20) north)
                  ((1 2 3 4) 0 2 (0 0 20 20) north)
                  ((1 2 3 4) 2 2 (0 0 20 20) nowhere)))
    (should-error (apply #'emacs-tui-layout-popup args))))

(defmacro emacs-tui-popup-test--source (&rest body)
  "Evaluate BODY with a temporary source and clean up owned sessions."
  (declare (indent 0) (debug body))
  `(save-window-excursion
     (let ((source (generate-new-buffer " *popup-test source*"))
           (before emacs-tui--sessions))
       (unwind-protect
           (progn (switch-to-buffer source) (insert "日本語 café") ,@body)
         (dolist (app (copy-sequence emacs-tui--sessions))
           (unless (memq app before) (emacs-tui-close app)))
         (when (buffer-live-p source) (kill-buffer source))))))

(ert-deftest emacs-tui-popup-unsupported-display-does-not-touch-host ()
  (emacs-tui-popup-test--source
    (let ((windows (window-state-get)) (buffers (buffer-list)) (point (point)))
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) nil)))
        (should-error (emacs-tui-popup :view (emacs-tui-view :id 'a :items '("Alpha")))
                      :type 'user-error))
      (should (equal windows (window-state-get)))
      (should (equal buffers (buffer-list)))
      (should (= point (point)))
      (should (equal "日本語 café" (buffer-string))))))

(ert-deftest emacs-tui-popup-unavailable-gallery-entry-preserves-chooser-and-source ()
  (emacs-tui-popup-test--source
    (let ((gallery (emacs-tui-gallery)))
      (emacs-tui-set-selection gallery 'demos 'popup)
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) nil)))
        (should-error (emacs-tui-gallery-launch) :type 'user-error)
        (should (emacs-tui-live-p gallery))
        (emacs-tui-close gallery)
        (with-current-buffer source
          (should-error (emacs-tui-popup-demo-mode 1) :type 'user-error)
          (should-not emacs-tui-popup-demo-mode)
          (should-not (memq #'emacs-tui-popup-demo--refresh post-command-hook))
          (should (equal "日本語 café" (buffer-string))))))))

(ert-deftest emacs-tui-popup-invalid-source-bounds-allocate-nothing ()
  (emacs-tui-popup-test--source
    (let ((buffers (buffer-list)) (calls 0))
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) t))
                ((symbol-function 'make-frame) (lambda (&rest _) (cl-incf calls))))
        (should-error (emacs-tui-popup :view (emacs-tui-input :id 'a) :begin 1 :end 2))
        (should-error (emacs-tui-popup :view (emacs-tui-view :id 'a) :begin 4 :end 2))
        (should-error (emacs-tui-popup :view (emacs-tui-view :id 'a) :position 'bad))
        (should-error (emacs-tui-popup :view (emacs-tui-view :id 'a) :width 0)))
      (should (= 0 calls))
      (should (equal buffers (buffer-list))))))

(ert-deftest emacs-tui-popup-native-creation-failure-releases-every-owned-resource ()
  (emacs-tui-popup-test--source
    (let ((buffers (buffer-list)) (windows (window-state-get))
          (frames (frame-list)) (surface (symbol-function 'emacs-tui--make-popup-surface))
          (closed 0) captured)
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) t))
                ((symbol-function 'emacs-tui--make-popup-surface)
                 (lambda (app) (setq captured app) (funcall surface app)))
                ((symbol-function 'make-frame) (lambda (&rest _) (error "Native failure"))))
        (should-error
         (emacs-tui-popup :view (emacs-tui-view :id 'a :items '("Alpha"))
                          :on-close (lambda (_app) (cl-incf closed)))))
      (should (= closed 1))
      (should-not (emacs-tui-live-p captured))
      (should-not (marker-buffer (emacs-tui--popup-begin (emacs-tui--workspace-popup captured))))
      (should-not (marker-buffer (emacs-tui--popup-end (emacs-tui--workspace-popup captured))))
      (should-not (memq #'emacs-tui--popup-post-command post-command-hook))
      (should-not (memq #'emacs-tui--popup-terminal-deleted delete-terminal-functions))
      (should (equal windows (window-state-get)))
      (should (equal buffers (buffer-list)))
      (should (equal frames (frame-list))))))

(ert-deftest emacs-tui-popup-failed-start-respects-close-callback-focus-choice ()
  (emacs-tui-popup-test--source
    (let ((other (split-window-below)))
      (cl-letf (((symbol-function 'emacs-tui-popup-supported-p) (lambda (&rest _) t))
                ((symbol-function 'make-frame) (lambda (&rest _) (error "Native failure"))))
        (should-error
         (emacs-tui-popup :view (emacs-tui-view :id 'a)
                          :on-close (lambda (_app)
                                      (select-window other)
                                      (error "Callback failed after choosing focus")))))
      (should (eq other (selected-window)))
      (should (equal "日本語 café" (buffer-string))))))

(ert-deftest emacs-tui-popup-source-identity-and-accessible-bounds-are-required ()
  (emacs-tui-popup-test--source
    (let* ((popup (emacs-tui--make-popup :buffer source :begin (copy-marker 1)
                                       :end (copy-marker 4 t)))
           (app (emacs-tui--make-workspace :active t :popup popup
                                          :origin-window (selected-window)
                                          :origin-frame (selected-frame)))
           (alternative (generate-new-buffer " *popup alternative*")))
      (unwind-protect
          (progn
            (should (emacs-tui--popup-source-valid-p app))
            (save-restriction
              (narrow-to-region 4 (point-max))
              (should-not (emacs-tui--popup-source-valid-p app)))
            (switch-to-buffer alternative)
            (should-not (emacs-tui--popup-source-valid-p app))
            (kill-buffer (current-buffer))
            (switch-to-buffer source)
            (should (emacs-tui--popup-source-valid-p app))
            (set-marker (emacs-tui--popup-end popup) nil)
            (should-not (emacs-tui--popup-source-valid-p app)))
        (when (buffer-live-p alternative) (kill-buffer alternative))
        (set-marker (emacs-tui--popup-begin popup) nil)
        (set-marker (emacs-tui--popup-end popup) nil)))))

(defun emacs-tui-popup-test--posn (x y width height)
  "Return native-shaped glyph position data for X, Y, WIDTH and HEIGHT."
  (list (selected-window) 1 (cons x y) 0 nil 1 '(0 . 0) nil '(0 . 0)
        (cons width height)))

(ert-deftest emacs-tui-popup-native-glyph-bounds-cover-wide-and-combining-text ()
  (emacs-tui-popup-test--source
    (let* ((popup (emacs-tui--make-popup :buffer source :begin (copy-marker 1)
                                       :end (copy-marker 4 t)))
           (app (emacs-tui--make-workspace :active t :popup popup
                                          :origin-window (selected-window)
                                          :origin-frame (selected-frame))))
      (unwind-protect
          (cl-letf (((symbol-function 'window-inside-pixel-edges)
                     (lambda (&rest _) '(100 200 400 500)))
                    ((symbol-function 'posn-at-point)
                     (lambda (pos &rest _)
                       (emacs-tui-popup-test--posn (+ 10 (* 2 (1- pos))) 20 2 3))))
            (should (equal '(110 220 6 3) (emacs-tui--popup-anchor app)))
            ;; A combined glyph leaves the exclusive endpoint at the preceding
            ;; glyph boundary; the anchor must not invent an extra text cell.
            (cl-letf (((symbol-function 'posn-at-point)
                       (lambda (pos &rest _)
                         (emacs-tui-popup-test--posn (+ 10 (* 2 (min 2 (1- pos)))) 20 0 3))))
              (should (equal '(110 220 4 3) (emacs-tui--popup-anchor app)))))
        (set-marker (emacs-tui--popup-begin popup) nil)
        (set-marker (emacs-tui--popup-end popup) nil)))))

(ert-deftest emacs-tui-popup-reentrant-movement-preserves-requested-placement ()
  (let* ((popup (emacs-tui--make-popup :position 'south-west))
         (app (emacs-tui--make-workspace :active t :popup popup))
         (emacs-tui--refreshing t))
    ;; Reflow cannot execute within another reflow.  Both explicit and cycling
    ;; requests must reject without silently changing the later placement.
    (cl-letf (((symbol-function 'emacs-tui--subtree) (lambda (_) t)))
      (dolist (position '(north nil))
        (should-error (emacs-tui-reposition-popup app position) :type 'user-error)
        (should (eq 'south-west (emacs-tui--popup-position popup)))
        (should (emacs-tui-live-p app))))))

(ert-deftest emacs-tui-popup-invalid-or-reentrant-resize-preserves-dimensions ()
  (let* ((popup (emacs-tui--make-popup :width 32 :height 8))
         (app (emacs-tui--make-workspace :active t :popup popup)))
    (cl-letf (((symbol-function 'emacs-tui--subtree) (lambda (_) t)))
      (dolist (size '((0 8) (32 1) (2.5 8) (32 nil) (nil 8)))
        (should-error (apply #'emacs-tui-resize-popup app size))
        (should (equal '(32 8) (list (emacs-tui--popup-width popup)
                                     (emacs-tui--popup-height popup)))))
      (let ((emacs-tui--refreshing t))
        (should-error (emacs-tui-resize-popup app 50 12) :type 'user-error))
      (should (equal '(32 8) (list (emacs-tui--popup-width popup)
                                   (emacs-tui--popup-height popup))))
      (should (emacs-tui-live-p app)))))

(ert-deftest emacs-tui-popup-resize-rejects-ordinary-session-without-window-changes ()
  (save-window-excursion
    (let ((app (emacs-tui-mount :views (list (emacs-tui-view :id 'a :text "Preview")))))
      (unwind-protect
          (let ((windows (window-state-get)))
            (should-error (emacs-tui-resize-popup app 50 12) :type 'user-error)
            (should (emacs-tui-live-p app))
            (should (equal windows (window-state-get))))
        (emacs-tui-close app)))))

(ert-deftest emacs-tui-popup-movement-invalidates-changed-content-viewport ()
  ;; Use real windows/rendering; model only unavailable native frame fitting.
  (save-window-excursion
    (let ((app (emacs-tui-mount
                :backend 'windows
                :views (list (emacs-tui-view :id 'rows :items '("alpha" "beta"))))))
      (unwind-protect
          (cl-letf (((symbol-function 'emacs-tui--popup-source-valid-p) (lambda (_) t))
                    ((symbol-function 'emacs-tui--popup-anchor) (lambda (_) '(20 10 4 1)))
                    ((symbol-function 'emacs-tui--fit-child) (lambda (_) nil)))
            (setf (emacs-tui--workspace-popup app) (emacs-tui--make-popup :position 'north)
                  (emacs-tui--workspace-frame app) (selected-frame)
                  (emacs-tui--workspace-geometry app) (emacs-tui--geometry app))
            (let* ((window (emacs-tui--workspace-root app))
                   (buffer (window-buffer window))
                   (tick (with-current-buffer buffer (buffer-chars-modified-tick))))
              (emacs-tui-reposition-popup app)
              (should (= tick (with-current-buffer buffer (buffer-chars-modified-tick))))
              ;; Outer dimensions are unchanged; the usable viewport is not.
              (with-current-buffer buffer (setq-local left-margin-width 3))
              (set-window-margins window 3 0)
              (should-not (equal (emacs-tui--workspace-geometry app)
                                 (emacs-tui--geometry app)))
              (emacs-tui-reposition-popup app)
              (should (< tick (with-current-buffer buffer (buffer-chars-modified-tick))))
              (setq tick (with-current-buffer buffer (buffer-chars-modified-tick)))
              (emacs-tui-refresh app)
              (should (< tick (with-current-buffer buffer (buffer-chars-modified-tick))))))
        ;; Never dispose the actual parent used to model the native child handle.
        (setf (emacs-tui--workspace-frame app) nil
              (emacs-tui--workspace-popup app) nil)
        (emacs-tui-close app)))))

(ert-deftest emacs-tui-popup-frames-are-excluded-from-modal-focus-routing ()
  (let ((popup (emacs-tui--make-workspace :active t :frame (selected-frame)
                                        :popup (emacs-tui--make-popup))))
    (should-not (emacs-tui--tty-child-p popup))
    (let ((emacs-tui--sessions (list popup)))
      (emacs-tui--remember-tty-focus)
      (should-not (emacs-tui--workspace-tty-focus popup)))))

(ert-deftest emacs-tui-popup-terminal-disposal-is-scoped-and-complete ()
  (emacs-tui-popup-test--source
    ;; Model terminal identities; actual 31.1 child-frame input is a PTY gate.
    (let ((emacs-tui--sessions nil)
          (post-command-hook post-command-hook)
          (delete-terminal-functions delete-terminal-functions)
          (own (frame-terminal (selected-frame)))
          (foreign (make-symbol "other-terminal")) apps closed)
      (unwind-protect
          (cl-labels
              ((model (terminal)
                 (let* ((buffer (generate-new-buffer " *popup owned view*"))
                        (popup (emacs-tui--make-popup
                                :buffer source :begin (copy-marker 1) :end (copy-marker 4 t)
                                :terminal terminal))
                        (app (emacs-tui--make-workspace
                              :active t :popup popup :origin-window (selected-window)
                              :origin-frame (selected-frame)
                              :views (list (emacs-tui--make-view :id 'a :buffer buffer))
                              :on-close (lambda (handle) (push handle closed))))
                        (hook (lambda () (emacs-tui-close app))))
                   (setf (emacs-tui--workspace-origin-kill-hook app) hook)
                   (add-hook 'kill-buffer-hook hook nil t)
                   (push app apps) (push app emacs-tui--sessions)
                   app)))
            (let* ((first (model own)) (second (model foreign))
                   (view (emacs-tui--view-buffer (car (emacs-tui--workspace-views first)))))
              (add-hook 'post-command-hook #'emacs-tui--popup-post-command)
              (add-hook 'delete-terminal-functions #'emacs-tui--popup-terminal-deleted)
              (emacs-tui--popup-terminal-deleted own)
              (should-not (emacs-tui-live-p first))
              (should-not (buffer-live-p view))
              (should-not (marker-buffer (emacs-tui--popup-begin (emacs-tui--workspace-popup first))))
              (should-not (marker-buffer (emacs-tui--popup-end (emacs-tui--workspace-popup first))))
              (should (emacs-tui-live-p second))
              (should (memq #'emacs-tui--popup-post-command post-command-hook))
              (emacs-tui--popup-terminal-deleted own)
              (should (= 1 (length closed)))
              (emacs-tui--popup-terminal-deleted foreign)
              (should (= 2 (length closed)))
              (should-not emacs-tui--sessions)
              (should-not (memq #'emacs-tui--popup-post-command post-command-hook))
              (should-not (memq #'emacs-tui--popup-terminal-deleted delete-terminal-functions))
              (dolist (app apps)
                (should-not (memq (emacs-tui--workspace-origin-kill-hook app) kill-buffer-hook)))
              (should (equal "日本語 café" (buffer-string)))))
        (dolist (app apps) (emacs-tui-close app))))))

(provide 'emacs-tui-popup-test)
;;; emacs-tui-popup-test.el ends here
