;;; emacs-tui-inspector-demo.el --- Source-anchored object inspection -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Inspect application objects referenced by words in a disposable document.
;; Scroll and move the floating preview without leaving the source.  Explicit
;; acknowledgement changes only this buffer's in-memory application state.
;; There is no completion table, source replacement, file write or evaluation.

;;; Code:
(require 'cl-lib)
(require 'emacs-tui)
(require 'thingatpt)

(defconst emacs-tui-inspector-demo--objects
  '(("pump" :name "Cooling pump" :status "Pressure below target"
     :reading "1.8 bar" :target "2.0–2.4 bar" :related "valve"
     :notes ("A sample equipment object, supplied by this application."
             "The toolkit owns the popup; the application owns these fields."
             "Inspecting or scrolling does not acknowledge an alert."
             "An acknowledgement is a reversible, explicit action."
             "It changes session memory only, never the document or equipment."
             "Close and reopen this inspector to see the retained acknowledgement."
             "Each source buffer keeps an independent acknowledgement table."
             "Move the popup around its anchor with C-c C-p."
             "The original buffer, cursor and window remain in place."
             "Typing still edits the original document normally."
             "C-c C-l follows the related object without moving source point."
             "C-c C-b and C-c C-f travel back and forward through inspections."
             "Dismiss with C-g, then inspect another reference with M-x."
             "Killing the source buffer discards its application state."))
    ("valve" :name "Return valve" :status "Inspection requested"
     :reading "45% open" :target "40–60% open" :related "sensor"
     :notes ("A second object with its own independent acknowledgement."
             "Its details use the same read-only popup view."
             "No candidate matching, query field or origin-buffer commit is needed."
             "The application decides what its action means."
             "C-c C-a toggles acknowledgement without closing the popup."
             "No external equipment is contacted by this demonstration."
             "Use M-n and M-p to read more while retaining source focus."
             "Resize or reposition; the preview keeps its reading position."
             "Native buffer editing and undo remain available in the source."))
    ("sensor" :name "Pressure sensor" :status "Calibration due"
     :reading "1.8 bar" :target "Calibrate against reference" :related "pump"
     :notes ("This sensor measures the cooling pump's discharge pressure."
             "Follow its related pump to explore a cycle of object references."
             "Back and Forward revisit objects, not source-buffer locations."
             "Acknowledgements remain attached to each object while browsing."
             "A new Follow after Back discards the forward trail."
             "The application keeps at most 32 objects in each history direction."
             "Closing the inspector clears navigation, retaining acknowledgements."
             "No source text, external equipment or files are changed.")))
  "Immutable sample equipment records, keyed by source reference text.")

(defvar-local emacs-tui-inspector-demo--session nil)
(defvar-local emacs-tui-inspector-demo--object nil)
(defvar-local emacs-tui-inspector-demo--acknowledged nil)
(defvar-local emacs-tui-inspector-demo--active nil)
(defvar-local emacs-tui-inspector-demo--generation nil)
(defvar-local emacs-tui-inspector-demo--back nil)
(defvar-local emacs-tui-inspector-demo--forward nil)
(defvar emacs-tui-inspector-demo--publishing nil
  "Session currently publishing details; dynamically bound during rendering.")

(defun emacs-tui-inspector-demo--text (object acknowledged)
  "Format OBJECT with ACKNOWLEDGED state, without changing application data."
  (concat (propertize (plist-get (cdr object) :name) 'face 'bold)
          (format "\n\nReference: %s\nStatus: %s\nReading: %s\nTarget: %s\nAcknowledged: %s\n\n"
                  (car object) (plist-get (cdr object) :status)
                  (plist-get (cdr object) :reading) (plist-get (cdr object) :target)
                  (if acknowledged "yes" "no"))
          (format "Related: %s (C-c C-l)\nBack: C-c C-b | Forward: C-c C-f\n\n"
                  (plist-get (cdr object) :related))
          (mapconcat (lambda (note)
                       (with-temp-buffer
                         (insert note)
                         (let ((fill-column 50)) (fill-region (point-min) (point-max)))
                         (buffer-string)))
                     (plist-get (cdr object) :notes) "\n\n")))

(defun emacs-tui-inspector-demo--require ()
  "Return this source buffer's live inspector, validating its owned surface."
  (unless (and emacs-tui-inspector-demo--object
               (emacs-tui-live-p emacs-tui-inspector-demo--session))
    (user-error "Inspect pump, valve or sensor first"))
  (emacs-tui-current-view emacs-tui-inspector-demo--session)
  emacs-tui-inspector-demo--session)

(defun emacs-tui-inspector-demo-dismiss ()
  "Close this buffer's inspector without changing text or acknowledgements."
  (interactive)
  (when emacs-tui-inspector-demo--session
    (emacs-tui-close emacs-tui-inspector-demo--session)))

(defun emacs-tui-inspector-demo-down ()
  "Scroll the inspected object's preview forward three lines."
  (interactive)
  (emacs-tui-scroll-view (emacs-tui-inspector-demo--require) 'details 3))

(defun emacs-tui-inspector-demo-up ()
  "Scroll the inspected object's preview backward three lines."
  (interactive)
  (emacs-tui-scroll-view (emacs-tui-inspector-demo--require) 'details -3))

(defun emacs-tui-inspector-demo-move ()
  "Move the inspector clockwise around its original source reference."
  (interactive)
  (emacs-tui-reposition-popup (emacs-tui-inspector-demo--require)))

(defun emacs-tui-inspector-demo--publish (object acknowledged)
  "Display OBJECT with ACKNOWLEDGED state, rejecting obsolete publication."
  (let ((app (emacs-tui-inspector-demo--require))
        (source (current-buffer)) (window (selected-window))
        (generation (make-symbol "inspector-update")))
    (when (eq app emacs-tui-inspector-demo--publishing)
      (user-error "Inspector publication is already in progress"))
    (setq emacs-tui-inspector-demo--generation generation)
    (let ((emacs-tui-inspector-demo--publishing app))
      (emacs-tui-update app 'details :text (emacs-tui-inspector-demo--text object acknowledged)))
    (unless (and (eq source (current-buffer)) (eq window (selected-window))
                 (eq generation emacs-tui-inspector-demo--generation)
                 (eq app emacs-tui-inspector-demo--session)
                 (emacs-tui-live-p app))
      (user-error "Inspector changed during publication"))))

(defun emacs-tui-inspector-demo--push (object history)
  "Add OBJECT to HISTORY, retaining at most 32 entries."
  (cons object (cl-subseq history 0 (min 31 (length history)))))

(defun emacs-tui-inspector-demo--visit (direction)
  "Visit a related object or travel through history in DIRECTION.
DIRECTION is `related', `back' or `forward'.  Publish before changing history."
  (emacs-tui-inspector-demo--require)
  (let* ((old emacs-tui-inspector-demo--object)
         (back emacs-tui-inspector-demo--back)
         (forward emacs-tui-inspector-demo--forward)
         (object (pcase direction
                   ('related (assoc (plist-get (cdr old) :related)
                                    emacs-tui-inspector-demo--objects))
                   ('back (car back))
                   ('forward (car forward)))))
    (unless object (user-error "No %s object" direction))
    (emacs-tui-inspector-demo--publish
     object (gethash (car object) emacs-tui-inspector-demo--acknowledged))
    (setq emacs-tui-inspector-demo--object object
          emacs-tui-inspector-demo--back
          (if (eq direction 'back) (cdr back)
            (emacs-tui-inspector-demo--push old back))
          emacs-tui-inspector-demo--forward
          (pcase direction
            ('back (emacs-tui-inspector-demo--push old forward))
            ('forward (cdr forward))
            (_ nil)))))

(defun emacs-tui-inspector-demo-follow ()
  "Inspect the related equipment object in the same source-anchored popup."
  (interactive)
  (emacs-tui-inspector-demo--visit 'related))

(defun emacs-tui-inspector-demo-back ()
  "Revisit the previous inspected object without moving source point."
  (interactive)
  (emacs-tui-inspector-demo--visit 'back))

(defun emacs-tui-inspector-demo-forward ()
  "Revisit the next inspected object without moving source point."
  (interactive)
  (emacs-tui-inspector-demo--visit 'forward))

(defun emacs-tui-inspector-demo-acknowledge ()
  "Toggle the inspected object's acknowledgement, leaving source text intact.
Keep the popup open.  State is private to this source buffer and discarded
on major-mode change or buffer death.  Publish before changing state."
  (interactive)
  (emacs-tui-inspector-demo--require)
  (let* ((object emacs-tui-inspector-demo--object)
         (table emacs-tui-inspector-demo--acknowledged)
         (next (not (gethash (car object) table))))
    (emacs-tui-inspector-demo--publish object next)
    (puthash (car object) next table)))

(defvar emacs-tui-inspector-demo--map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "M-n") #'emacs-tui-inspector-demo-down)
    (define-key map (kbd "M-p") #'emacs-tui-inspector-demo-up)
    (define-key map (kbd "C-c C-p") #'emacs-tui-inspector-demo-move)
    (define-key map (kbd "C-c C-a") #'emacs-tui-inspector-demo-acknowledge)
    (define-key map (kbd "C-c C-l") #'emacs-tui-inspector-demo-follow)
    (define-key map (kbd "C-c C-b") #'emacs-tui-inspector-demo-back)
    (define-key map (kbd "C-c C-f") #'emacs-tui-inspector-demo-forward)
    (define-key map (kbd "C-g") #'emacs-tui-inspector-demo-dismiss)
    map)
  "Source bindings enabled only while this buffer's inspector is visible.")
(add-to-list 'minor-mode-map-alist
             (cons 'emacs-tui-inspector-demo--active emacs-tui-inspector-demo--map))

;;;###autoload
(defun emacs-tui-inspector-demo-at-point ()
  "Inspect the sample equipment reference pump, valve or sensor at point.
The popup shows the explicitly chosen object even if source text is later
edited.  Follow related objects and travel Back/Forward without moving source
point.  Dismissal clears navigation and restores bindings; no text is inserted."
  (interactive)
  (let* ((bounds (bounds-of-thing-at-point 'symbol))
         (object (and bounds
                      (assoc (buffer-substring-no-properties (car bounds) (cdr bounds))
                             emacs-tui-inspector-demo--objects)))
         (source (current-buffer)) (window (selected-window))
         (stamp (list (point) (buffer-chars-modified-tick)))
         generation app ready)
    (unless object (user-error "Place point on pump, valve or sensor"))
    (unless (emacs-tui-popup-supported-p)
      (user-error "This demo needs graphical or native TTY child frames"))
    (setq generation (make-symbol "inspector")
          emacs-tui-inspector-demo--generation generation)
    (emacs-tui-inspector-demo-dismiss)
    ;; Closing invokes native frame and application hooks. A newer inspector
    ;; started there owns this source; do not overwrite it or orphan its popup.
    (unless (and (eq source (current-buffer)) (eq window (selected-window))
                 (eq generation emacs-tui-inspector-demo--generation)
                 (equal stamp (list (point) (buffer-chars-modified-tick))))
      (user-error "Inspector changed while closing the previous popup"))
    (unless emacs-tui-inspector-demo--acknowledged
      (setq emacs-tui-inspector-demo--acknowledged (make-hash-table :test #'equal)))
    (unwind-protect
        (progn
          (setq app
                (emacs-tui-popup
                 :begin (car bounds) :end (cdr bounds) :width 58 :height 12
                 :view (emacs-tui-view
                        :id 'details :title "Inspector | M-n/p read | C-c C-a acknowledge"
                        :text (emacs-tui-inspector-demo--text
                               object (gethash (car object) emacs-tui-inspector-demo--acknowledged)))
                 :on-close (lambda (closed)
                             (when (buffer-live-p source)
                               (with-current-buffer source
                                 (when (eq closed emacs-tui-inspector-demo--session)
                                   (setq emacs-tui-inspector-demo--session nil
                                         emacs-tui-inspector-demo--object nil
                                         emacs-tui-inspector-demo--back nil
                                         emacs-tui-inspector-demo--forward nil
                                         emacs-tui-inspector-demo--active nil)
                                   (remove-hook 'change-major-mode-hook
                                                #'emacs-tui-inspector-demo-dismiss t)))))))
          (unless (and (eq source (current-buffer)) (eq window (selected-window))
                       (eq generation emacs-tui-inspector-demo--generation)
                       (equal stamp (list (point) (buffer-chars-modified-tick)))
                       (emacs-tui-live-p app))
            (user-error "Inspector changed during creation"))
          (setq emacs-tui-inspector-demo--session app
                emacs-tui-inspector-demo--object object
                emacs-tui-inspector-demo--back nil
                emacs-tui-inspector-demo--forward nil
                emacs-tui-inspector-demo--active t)
          (add-hook 'change-major-mode-hook #'emacs-tui-inspector-demo-dismiss nil t)
          (setq ready t)
          app)
      (unless ready (when app (emacs-tui-close app))))))

;;;###autoload
(defun emacs-tui-inspector-demo ()
  "Open a disposable equipment note and inspect its pump reference.
Use `emacs-tui-inspector-demo-down' and `emacs-tui-inspector-demo-up' to read,
`emacs-tui-inspector-demo-move' to move, `emacs-tui-inspector-demo-acknowledge'
to act and `emacs-tui-inspector-demo-dismiss' to dismiss.
Use `emacs-tui-inspector-demo-follow', `emacs-tui-inspector-demo-back' and
`emacs-tui-inspector-demo-forward' to browse related objects in the same popup.
No external data or files are changed."
  (interactive)
  (unless (emacs-tui-popup-supported-p)
    (user-error "This demo needs graphical or native TTY child frames"))
  (switch-to-buffer (generate-new-buffer "*TUI equipment notes*"))
  (text-mode)
  (insert "Equipment notes: inspect pump, valve or sensor with M-x emacs-tui-inspector-demo-at-point.\n"
          "M-n/p read | C-c C-p move | C-c C-a acknowledge | C-g dismiss\nC-c C-l related | C-c C-b back | C-c C-f forward\n"
          "Acknowledgements are private to this disposable document; no file is saved.\n"
          (make-string 30 ?\n))
  (goto-char (point-min)) (forward-line (max 5 (/ (window-body-height) 2)))
  (insert (make-string (max 0 (- (/ (window-body-width) 2) 4)) ?\s) "pump   valve")
  (backward-char 8)
  (setq buffer-undo-list nil)
  (set-buffer-modified-p nil)
  (emacs-tui-inspector-demo-at-point))

(provide 'emacs-tui-inspector-demo)
;;; emacs-tui-inspector-demo.el ends here
