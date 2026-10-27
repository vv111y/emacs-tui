;;; emacs-tui-multi-popup-demo.el --- Independent floating panels -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Three independently owned popups share an unchanged source window.  Individual
;; and collective toggles dispose/recreate surfaces while retaining application
;; selection.  No files, source text or external data are changed by the UI.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)

(defconst emacs-tui-multi-popup-demo--objects
  '((:id pump :label "Cooling pump" :text "Cooling pump\nPressure: 1.8 bar\nTarget: 2.0–2.4 bar\nInspection requested.\n\nRecent readings\n09:00  2.2 bar\n09:05  2.1 bar\n09:10  1.9 bar\n09:15  1.8 bar\n\nOperator note\nCheck the intake filter before restarting.")
    (:id valve :label "Return valve" :text "Return valve\nOpening: 45%\nTarget: 40–60%\nOperating normally.\n\nRecent settings\n09:00  42%\n09:05  45%\n09:10  45%\n09:15  45%\n\nOperator note\nKeep the return path open during inspection.")
    (:id sensor :label "Pressure sensor" :text "Pressure sensor\nReading: 1.8 bar\nCalibration due.\nRelated object: cooling pump.\n\nCalibration record\nReference: 2.0 bar\nLast check: 1.9 bar\nTolerance: 0.1 bar\nNext check: pending\n\nOperator note\nCompare against the reference gauge."))
  "Sample objects owned by this application.")

(defconst emacs-tui-multi-popup-demo--panels
  '((objects south-west 26 6) (details east 34 7) (keys north-west 40 8))
  "Panel identifiers, initial positions and requested dimensions.")

(defvar-local emacs-tui-multi-popup-demo--sessions nil)
(defvar-local emacs-tui-multi-popup-demo--index 0)
(defvar-local emacs-tui-multi-popup-demo--positions nil)
(defvar-local emacs-tui-multi-popup-demo--expanded nil)
(defvar-local emacs-tui-multi-popup-demo--generation nil)
(defvar emacs-tui-multi-popup-demo--busy nil)
(defvar emacs-tui-multi-popup-demo-mode nil)

(defun emacs-tui-multi-popup-demo--session (id)
  "Return the live popup for panel ID, or nil."
  (let ((app (alist-get id emacs-tui-multi-popup-demo--sessions)))
    (and (emacs-tui-live-p app) app)))

(defun emacs-tui-multi-popup-demo--hide (id)
  "Dispose panel ID without touching its siblings or the source."
  (let ((app (alist-get id emacs-tui-multi-popup-demo--sessions)))
    (setq emacs-tui-multi-popup-demo--sessions
          (assq-delete-all id emacs-tui-multi-popup-demo--sessions))
    (when app (emacs-tui-close app))))

(defun emacs-tui-multi-popup-demo--close-many (apps)
  "Attempt closure of every session in APPS, returning the first error or quit."
  (let (failure)
    (dolist (app apps)
      (condition-case err (emacs-tui-close app)
        ((error quit) (unless failure (setq failure err)))))
    failure))

(defun emacs-tui-multi-popup-demo--hide-all ()
  "Dispose all this source's panels, retaining its local demo bindings."
  (let ((apps (mapcar #'cdr emacs-tui-multi-popup-demo--sessions)))
    (setq emacs-tui-multi-popup-demo--sessions nil)
    (when emacs-tui-multi-popup-demo-mode
      (setq emacs-tui-multi-popup-demo--generation (make-symbol "multi-popup")))
    (when-let* ((failure (emacs-tui-multi-popup-demo--close-many apps)))
      (signal (car failure) (cdr failure)))))

(defun emacs-tui-multi-popup-demo--view (id)
  "Describe panel ID using the current application selection."
  (pcase id
    ('objects (emacs-tui-view :id id :title "Objects | M-n / M-p"
                              :items emacs-tui-multi-popup-demo--objects))
    ('details (emacs-tui-view
               :id id :title "Details | C-c [ / ] scroll"
               :text (plist-get (nth emacs-tui-multi-popup-demo--index
                                    emacs-tui-multi-popup-demo--objects) :text)))
    ('keys (emacs-tui-view
            :id id :title "Independent floating panels"
            :text "C-c 1 / 2 / 3: toggle each panel\nC-c 0: hide all / show all\nC-c p 1 / 2 / 3: move each panel\nM-n / M-p: browse objects\nC-c [ / ]: scroll details\nC-c C-e: expand / shrink details\nC-g: hide | C-c C-q: disable"))))

(defun emacs-tui-multi-popup-demo--check-context (source window generation)
  "Reject publication after SOURCE, WINDOW or GENERATION changed."
  (unless (and (eq source (current-buffer)) (eq window (selected-window))
               (eq source (window-buffer window)) emacs-tui-multi-popup-demo-mode
               (eq generation emacs-tui-multi-popup-demo--generation))
    (user-error "Demo changed during a panel operation")))

(defun emacs-tui-multi-popup-demo--show (id)
  "Create panel ID over the selected source, rejecting obsolete creation."
  (unless (emacs-tui-multi-popup-demo--session id)
    (let* ((spec (assq id emacs-tui-multi-popup-demo--panels))
           (source (current-buffer)) (window (selected-window))
           (generation emacs-tui-multi-popup-demo--generation) app ready)
      (unwind-protect
          (progn
            (setq app
                  (emacs-tui-popup
                   :view (emacs-tui-multi-popup-demo--view id)
                   :position (or (alist-get id emacs-tui-multi-popup-demo--positions)
                                 (nth 1 spec))
                   :width (if (and (eq id 'details) emacs-tui-multi-popup-demo--expanded)
                              50 (nth 2 spec))
                   :height (if (and (eq id 'details) emacs-tui-multi-popup-demo--expanded)
                               12 (nth 3 spec))
                   :on-close
                   (lambda (closed)
                     (when (buffer-live-p source)
                       (with-current-buffer source
                         (when (eq closed (alist-get id emacs-tui-multi-popup-demo--sessions))
                           (setq emacs-tui-multi-popup-demo--sessions
                                 (assq-delete-all id emacs-tui-multi-popup-demo--sessions))))))))
            (emacs-tui-multi-popup-demo--check-context source window generation)
            (unless (emacs-tui-live-p app) (user-error "Panel closed during creation"))
            (when (eq id 'objects)
              (emacs-tui-set-selection
               app id (plist-get (nth emacs-tui-multi-popup-demo--index
                                      emacs-tui-multi-popup-demo--objects) :id)))
            (emacs-tui-multi-popup-demo--check-context source window generation)
            (unless (emacs-tui-live-p app) (user-error "Panel closed during selection"))
            (setf (alist-get id emacs-tui-multi-popup-demo--sessions) app)
            (setq ready t)
            app)
        (unless ready (when app (emacs-tui-close app)))))))

(defun emacs-tui-multi-popup-demo--toggle (id)
  "Toggle panel ID, or all panels when ID is `all'."
  (unless emacs-tui-multi-popup-demo-mode (user-error "Enable the multi-popup demo first"))
  (when emacs-tui-multi-popup-demo--busy (user-error "A panel operation is in progress"))
  (let ((emacs-tui-multi-popup-demo--busy t))
    (if (eq id 'all)
        (if (cl-some #'emacs-tui-multi-popup-demo--session
                     (mapcar #'car emacs-tui-multi-popup-demo--panels))
            (emacs-tui-multi-popup-demo--hide-all)
          (let (opened ready)
            (unwind-protect
                (progn
                  (dolist (spec emacs-tui-multi-popup-demo--panels)
                    (push (emacs-tui-multi-popup-demo--show (car spec)) opened))
                  (setq ready t))
              (unless ready (emacs-tui-multi-popup-demo--close-many opened)))))
      (if (emacs-tui-multi-popup-demo--session id)
          (emacs-tui-multi-popup-demo--hide id)
        (emacs-tui-multi-popup-demo--show id)))))

(defun emacs-tui-multi-popup-demo-toggle-objects ()
  "Toggle the floating object list."
  (interactive) (emacs-tui-multi-popup-demo--toggle 'objects))

(defun emacs-tui-multi-popup-demo-toggle-details ()
  "Toggle the floating selected-object details."
  (interactive) (emacs-tui-multi-popup-demo--toggle 'details))

(defun emacs-tui-multi-popup-demo-toggle-keys ()
  "Toggle the floating key guide."
  (interactive) (emacs-tui-multi-popup-demo--toggle 'keys))

(defun emacs-tui-multi-popup-demo-toggle-all ()
  "Hide all panels if any is visible; otherwise show all three."
  (interactive) (emacs-tui-multi-popup-demo--toggle 'all))

(defun emacs-tui-multi-popup-demo-dismiss ()
  "Hide all panels while retaining the source's demo bindings."
  (interactive) (emacs-tui-multi-popup-demo--hide-all))

(defun emacs-tui-multi-popup-demo-disable ()
  "Close all panels and restore the source's normal bindings."
  (interactive) (emacs-tui-multi-popup-demo-mode -1))

(defun emacs-tui-multi-popup-demo--browse (delta)
  "Move application selection by DELTA, updating visible panels.
Selection changes first.  On publication failure dispose the original data
panels so reopening shows coherent application state."
  (unless emacs-tui-multi-popup-demo-mode (user-error "Enable the multi-popup demo first"))
  (when emacs-tui-multi-popup-demo--busy (user-error "A panel operation is in progress"))
  (let* ((emacs-tui-multi-popup-demo--busy t)
         (source (current-buffer)) (window (selected-window))
         (generation emacs-tui-multi-popup-demo--generation)
         (objects (emacs-tui-multi-popup-demo--session 'objects))
         (details (emacs-tui-multi-popup-demo--session 'details))
         (next (mod (+ emacs-tui-multi-popup-demo--index delta)
                    (length emacs-tui-multi-popup-demo--objects)))
         (object (nth next emacs-tui-multi-popup-demo--objects)) ready)
    (setq emacs-tui-multi-popup-demo--index next)
    (unwind-protect
        (progn
          (when details (emacs-tui-update details 'details :text (plist-get object :text)))
          (emacs-tui-multi-popup-demo--check-context source window generation)
          (when objects (emacs-tui-set-selection objects 'objects (plist-get object :id)))
          (emacs-tui-multi-popup-demo--check-context source window generation)
          (setq ready t))
      (unless ready
        (emacs-tui-multi-popup-demo--close-many (delq nil (list objects details)))))))

(defun emacs-tui-multi-popup-demo-next ()
  "Inspect the next sample object, even when its list is hidden."
  (interactive) (emacs-tui-multi-popup-demo--browse 1))

(defun emacs-tui-multi-popup-demo-previous ()
  "Inspect the previous sample object."
  (interactive) (emacs-tui-multi-popup-demo--browse -1))

(defun emacs-tui-multi-popup-demo--scroll (lines)
  "Scroll the visible Details panel by LINES without changing source focus."
  (unless emacs-tui-multi-popup-demo-mode (user-error "Enable the multi-popup demo first"))
  (when emacs-tui-multi-popup-demo--busy (user-error "A panel operation is in progress"))
  (let ((app (emacs-tui-multi-popup-demo--session 'details))
        (emacs-tui-multi-popup-demo--busy t))
    (unless app (user-error "Show the details panel first"))
    (emacs-tui-scroll-view app 'details lines)))

(defun emacs-tui-multi-popup-demo-scroll-forward ()
  "Read three lines farther in Details while typing focus stays in the source."
  (interactive) (emacs-tui-multi-popup-demo--scroll 3))

(defun emacs-tui-multi-popup-demo-scroll-backward ()
  "Read three lines earlier in Details while typing focus stays in the source."
  (interactive) (emacs-tui-multi-popup-demo--scroll -3))

(defun emacs-tui-multi-popup-demo-toggle-size ()
  "Toggle visible Details between compact and expanded requested dimensions.
Retain the choice across hide/show; native viewport bounds still apply."
  (interactive)
  (unless emacs-tui-multi-popup-demo-mode (user-error "Enable the multi-popup demo first"))
  (when emacs-tui-multi-popup-demo--busy (user-error "A panel operation is in progress"))
  (let ((app (emacs-tui-multi-popup-demo--session 'details))
        (source (current-buffer)) (window (selected-window))
        (generation emacs-tui-multi-popup-demo--generation)
        (expanded (not emacs-tui-multi-popup-demo--expanded))
        (emacs-tui-multi-popup-demo--busy t))
    (unless app (user-error "Show the details panel first"))
    (emacs-tui-resize-popup app (if expanded 50 34) (if expanded 12 7))
    (emacs-tui-multi-popup-demo--check-context source window generation)
    (unless (eq app (emacs-tui-multi-popup-demo--session 'details))
      (user-error "Panel changed during resizing"))
    (setq emacs-tui-multi-popup-demo--expanded expanded)))

(defun emacs-tui-multi-popup-demo--move (id)
  "Cycle panel ID through eight positions and remember its placement."
  (unless emacs-tui-multi-popup-demo-mode (user-error "Enable the multi-popup demo first"))
  (when emacs-tui-multi-popup-demo--busy (user-error "A panel operation is in progress"))
  (let ((app (emacs-tui-multi-popup-demo--session id))
        (source (current-buffer)) (window (selected-window))
        (generation emacs-tui-multi-popup-demo--generation)
        (emacs-tui-multi-popup-demo--busy t))
    (unless app (user-error "Show the %s panel first" id))
    (let ((position (emacs-tui-reposition-popup app)))
      (emacs-tui-multi-popup-demo--check-context source window generation)
      (unless (eq app (emacs-tui-multi-popup-demo--session id))
        (user-error "Panel changed during movement"))
      (setf (alist-get id emacs-tui-multi-popup-demo--positions) position))))

(defun emacs-tui-multi-popup-demo-move ()
  "Cycle Objects through eight positions, leaving sibling panels alone."
  (interactive) (emacs-tui-multi-popup-demo--move 'objects))

(defun emacs-tui-multi-popup-demo-move-details ()
  "Cycle Details through eight positions, leaving sibling panels alone."
  (interactive) (emacs-tui-multi-popup-demo--move 'details))

(defun emacs-tui-multi-popup-demo-move-keys ()
  "Cycle Keys through eight positions, leaving sibling panels alone."
  (interactive) (emacs-tui-multi-popup-demo--move 'keys))

(defun emacs-tui-multi-popup-demo--stop ()
  "Invalidate pending publication and release this source's panels and hooks."
  (setq emacs-tui-multi-popup-demo-mode nil
        emacs-tui-multi-popup-demo--generation nil)
  (remove-hook 'kill-buffer-hook #'emacs-tui-multi-popup-demo--stop t)
  (remove-hook 'change-major-mode-hook #'emacs-tui-multi-popup-demo--stop t)
  (emacs-tui-multi-popup-demo--hide-all))

;;;###autoload
(define-minor-mode emacs-tui-multi-popup-demo-mode
  "Toggle three independent floating panels over this unchanged source window.
\\<emacs-tui-multi-popup-demo-mode-map>
Use \\[emacs-tui-multi-popup-demo-toggle-objects],
\\[emacs-tui-multi-popup-demo-toggle-details] and
\\[emacs-tui-multi-popup-demo-toggle-keys] to toggle each panel.
Use \\[emacs-tui-multi-popup-demo-toggle-all] to hide all if any are visible,
otherwise show all.  \\[emacs-tui-multi-popup-demo-next] browses objects.
\\[emacs-tui-multi-popup-demo-dismiss] hides panels but retains bindings;
\\[emacs-tui-multi-popup-demo-disable] disables them.  Reopening retains
application selection and each panel's placement, recreating display surfaces.
Use \\[emacs-tui-multi-popup-demo-move],
\\[emacs-tui-multi-popup-demo-move-details] and
\\[emacs-tui-multi-popup-demo-move-keys] to move each panel independently.
Each cycles through eight positions.
Use \\[emacs-tui-multi-popup-demo-scroll-forward] and
\\[emacs-tui-multi-popup-demo-scroll-backward] to read Details without focusing it.
Use \\[emacs-tui-multi-popup-demo-toggle-size] to expand or shrink Details.
Scrolling and resizing require Details to be visible.  Hiding and reopening
retains its size choice but resets its reading position.
Typing and undo stay in the source.
Positions are clamped and may overlap."
  :lighter " MultiPop"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c 1") #'emacs-tui-multi-popup-demo-toggle-objects)
            (define-key map (kbd "C-c 2") #'emacs-tui-multi-popup-demo-toggle-details)
            (define-key map (kbd "C-c 3") #'emacs-tui-multi-popup-demo-toggle-keys)
            (define-key map (kbd "C-c 0") #'emacs-tui-multi-popup-demo-toggle-all)
            (define-key map (kbd "M-n") #'emacs-tui-multi-popup-demo-next)
            (define-key map (kbd "M-p") #'emacs-tui-multi-popup-demo-previous)
            (define-key map (kbd "C-c C-p") #'emacs-tui-multi-popup-demo-move)
            (define-key map (kbd "C-c p 1") #'emacs-tui-multi-popup-demo-move)
            (define-key map (kbd "C-c p 2") #'emacs-tui-multi-popup-demo-move-details)
            (define-key map (kbd "C-c ]") #'emacs-tui-multi-popup-demo-scroll-forward)
            (define-key map (kbd "C-c [") #'emacs-tui-multi-popup-demo-scroll-backward)
            (define-key map (kbd "C-c C-e") #'emacs-tui-multi-popup-demo-toggle-size)
            (define-key map (kbd "C-c p 3") #'emacs-tui-multi-popup-demo-move-keys)
            (define-key map (kbd "C-g") #'emacs-tui-multi-popup-demo-dismiss)
            (define-key map (kbd "C-c C-q") #'emacs-tui-multi-popup-demo-disable)
            map)
  (let ((source (current-buffer)) (window (selected-window)) generation)
    (if (not emacs-tui-multi-popup-demo-mode) (emacs-tui-multi-popup-demo--stop)
      (emacs-tui-multi-popup-demo--stop)
      (unless (and (eq source (current-buffer)) (eq window (selected-window)))
        (user-error "Source changed while closing previous panels"))
      (unless (emacs-tui-popup-supported-p)
        (user-error "This demo needs graphical or native TTY child frames"))
      (setq generation (make-symbol "multi-popup")
            emacs-tui-multi-popup-demo-mode t
            emacs-tui-multi-popup-demo--index 0
            emacs-tui-multi-popup-demo--positions nil
            emacs-tui-multi-popup-demo--expanded nil
            emacs-tui-multi-popup-demo--generation generation)
      (add-hook 'kill-buffer-hook #'emacs-tui-multi-popup-demo--stop nil t)
      (add-hook 'change-major-mode-hook #'emacs-tui-multi-popup-demo--stop nil t)
      (condition-case err (emacs-tui-multi-popup-demo-toggle-all)
        ((error quit)
         (when (buffer-live-p source)
           (with-current-buffer source
             (when (eq generation emacs-tui-multi-popup-demo--generation)
               (emacs-tui-multi-popup-demo--stop))))
         (signal (car err) (cdr err)))))))

;;;###autoload
(defun emacs-tui-multi-popup-demo ()
  "Open a disposable note with three independently toggleable floating panels."
  (interactive)
  (unless (emacs-tui-popup-supported-p)
    (user-error "This demo needs graphical or native TTY child frames"))
  (switch-to-buffer (generate-new-buffer "*TUI floating panels*"))
  (text-mode)
  (insert "Independent floating panels over a native editable document\n"
          "C-c 1 Objects | C-c 2 Details | C-c 3 Keys | C-c 0 All\n"
          "M-n/p browse | C-c p 1/2/3 move panels | C-g hide | C-c C-q disable\n"
          (make-string 35 ?\n))
  (goto-char (point-min)) (forward-line (max 5 (/ (window-body-height) 2)))
  (insert (make-string (max 0 (- (/ (window-body-width) 2) 4)) ?\s) "equipment")
  (setq buffer-undo-list nil)
  (set-buffer-modified-p nil)
  (emacs-tui-multi-popup-demo-mode 1))

(provide 'emacs-tui-multi-popup-demo)
;;; emacs-tui-multi-popup-demo.el ends here
