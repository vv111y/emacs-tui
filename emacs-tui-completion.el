;;; emacs-tui-completion.el --- Optional completion-at-point popups -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Author: Willy Rempel <https://github.com/vv111y>
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Enable `emacs-tui-completion-mode' in a source buffer, then invoke ordinary
;; `completion-at-point'.  Existing completion providers and styles supply the
;; candidates.  Typing filters the active popup without changing input focus.
;; Only explicit acceptance edits the completion field.  This optional adapter
;; requires native child frames; the core toolkit does not load it.

;;; Code:
(require 'cl-lib)
(require 'minibuffer)
(require 'emacs-tui)

(defgroup emacs-tui-completion nil
  "Optional `completion-at-point' presentation."
  :group 'emacs-tui)

(defcustom emacs-tui-completion-limit 200
  "Maximum number of candidates displayed and decorated.
Completion tables still compute all matches synchronously; this is not a
provider work limit.  Providers must return promptly."
  :type '(integer 1 *))

(defcustom emacs-tui-completion-position 'south-west
  "Initial compass position for completion popups in this buffer.
Moving a popup changes the buffer-local preference."
  :type '(choice (const north) (const north-east) (const east) (const south-east)
                 (const south) (const south-west) (const west) (const north-west)))

(cl-defstruct (emacs-tui--completion (:constructor emacs-tui--make-completion))
  buffer window begin end table predicate extra valid ignore-case session projection stamp)

(defvar-local emacs-tui-completion--context nil)
(defvar-local emacs-tui-completion--active nil)
(defvar-local emacs-tui-completion--previous nil)
(defvar emacs-tui-completion-mode)

(defconst emacs-tui-completion--metadata-extra-p
  (let ((completion-extra-properties '(:emacs-tui-completion-probe t)))
    (completion-metadata-get nil 'emacs-tui-completion-probe))
  "Whether native metadata lookup already integrates extra properties.")

(defun emacs-tui-completion--stamp ()
  "Return the current source text, point and accessibility generation."
  (list (buffer-chars-modified-tick) (point) (point-min) (point-max)))

(defun emacs-tui-completion--release (context)
  "Release CONTEXT without changing another completion session."
  (when (buffer-live-p (emacs-tui--completion-buffer context))
    (with-current-buffer (emacs-tui--completion-buffer context)
      (when (eq context emacs-tui-completion--context)
        (setq emacs-tui-completion--context nil emacs-tui-completion--active nil)
        (remove-hook 'post-command-hook #'emacs-tui-completion--post-command t))))
  (let ((session (emacs-tui--completion-session context)))
    (setf (emacs-tui--completion-session context) nil)
    (set-marker (emacs-tui--completion-begin context) nil)
    (set-marker (emacs-tui--completion-end context) nil)
    (when (emacs-tui-live-p session) (emacs-tui-close session))))

(defun emacs-tui-completion--valid-p (context)
  "Whether CONTEXT still owns an accessible field in the input window."
  (let ((begin (emacs-tui--completion-begin context))
        (end (emacs-tui--completion-end context))
        (window (emacs-tui--completion-window context)))
    (and emacs-tui-completion-mode
         (eq context emacs-tui-completion--context)
         (eq completion-in-region-function #'emacs-tui-completion--in-region)
         (eq (current-buffer) (emacs-tui--completion-buffer context))
         (eq (selected-window) window) (window-live-p window)
         (eq (window-buffer window) (current-buffer))
         (eq (marker-buffer begin) (current-buffer))
         (eq (marker-buffer end) (current-buffer))
         (<= (point-min) begin (point) end (point-max))
         (or (not (emacs-tui--completion-valid context))
             (funcall (emacs-tui--completion-valid context))))))

(defun emacs-tui-completion--property (metadata property extra)
  "Read PROPERTY from METADATA, falling back to captured EXTRA on older Emacs."
  (if emacs-tui-completion--metadata-extra-p
      ;; Native nil category overrides must continue to suppress properties.
      (completion-metadata-get metadata property)
    (or (completion-metadata-get metadata property)
        (plist-get extra (intern (concat ":" (symbol-name property)))))))

(defun emacs-tui-completion--projection (context)
  "Compute raw candidates and replacement bounds for CONTEXT.
Honor completion styles, predicates, base size and the suffix boundary."
  (let* ((completion-extra-properties (emacs-tui--completion-extra context))
         (completion-ignore-case (emacs-tui--completion-ignore-case context))
         (minibuffer-completion-table (emacs-tui--completion-table context))
         (minibuffer-completion-predicate (emacs-tui--completion-predicate context))
         (begin (marker-position (emacs-tui--completion-begin context)))
         (text (buffer-substring-no-properties begin (emacs-tui--completion-end context)))
         (offset (- (point) begin))
         (prefix (substring text 0 offset))
         (suffix (substring text offset))
         (metadata (completion-metadata prefix minibuffer-completion-table
                                        minibuffer-completion-predicate))
         (tail (completion-all-completions text minibuffer-completion-table
                                           minibuffer-completion-predicate offset metadata))
         candidates)
    ;; Do not mutate a provider's list or pass the dotted base size to sorting.
    (while (consp tail)
      (unless (stringp (car tail)) (error "Completion candidate is not a string"))
      (push (copy-sequence (car tail)) candidates)
      (setq tail (cdr tail)))
    (let* ((base (or tail 0))
           (bounds (completion-boundaries prefix minibuffer-completion-table
                                          minibuffer-completion-predicate suffix)))
      (unless (and (natnump base) (<= base offset)
                   (natnump (car bounds)) (<= (car bounds) offset)
                   (natnump (cdr bounds)) (<= (cdr bounds) (length suffix)))
        (error "Invalid completion field boundaries"))
      ;; Styles can complete a wider field than the table's field at point.
      (unless (= base (car bounds))
        (setq metadata (completion-metadata (substring prefix 0 base)
                                            minibuffer-completion-table
                                            minibuffer-completion-predicate)))
      (list :candidates (delete-dups (nreverse candidates)) :metadata metadata
            :begin (+ begin base) :end (+ (point) (cdr bounds))))))

(defun emacs-tui-completion--display-string (string)
  "Make STRING safe for a single candidate row, retaining display properties."
  (replace-regexp-in-string
   "[\n\r\t]" (lambda (character)
                  (pcase character ("\n" "\\n") ("\r" "\\r") (_ "\\t")))
   string t t))

(defun emacs-tui-completion--items (context projection)
  "Decorate the bounded display subset of CONTEXT's raw PROJECTION."
  (unless (and (integerp emacs-tui-completion-limit) (> emacs-tui-completion-limit 0))
    (user-error "Completion display limit must be a positive integer"))
  (let* ((completion-extra-properties (emacs-tui--completion-extra context))
         (completion-ignore-case (emacs-tui--completion-ignore-case context))
         (minibuffer-completion-table (emacs-tui--completion-table context))
         (minibuffer-completion-predicate (emacs-tui--completion-predicate context))
         (metadata (plist-get projection :metadata))
         (extra (emacs-tui--completion-extra context))
         (sorter (emacs-tui-completion--property metadata 'display-sort-function extra))
         (affix (emacs-tui-completion--property metadata 'affixation-function extra))
         (annotate (emacs-tui-completion--property metadata 'annotation-function extra))
         (all (mapcar #'copy-sequence (plist-get projection :candidates)))
         (sorted (if sorter (funcall sorter all) all))
         (shown (cl-subseq sorted 0 (min (length sorted) emacs-tui-completion-limit)))
         (decorated (if affix (funcall affix (mapcar #'copy-sequence shown))
                      (mapcar (lambda (raw) (list raw "" (if annotate
                                                            (or (funcall annotate raw) "")
                                                          ""))) shown))))
    (unless (= (length shown) (length decorated))
      (error "Completion affixation changed the number of candidates"))
    (cl-mapcar
     (lambda (raw parts)
       (unless (and (equal raw (car parts)) (= 3 (length parts))
                    (cl-every #'stringp parts)
                    (member raw (plist-get projection :candidates)))
         (error "Invalid completion decoration or sort result"))
       (let ((value (substring-no-properties raw)))
         (list :id value :value value
               :label (emacs-tui-completion--display-string
                       (concat (nth 1 parts) raw (nth 2 parts))))))
     shown decorated)))

(defun emacs-tui-completion--refresh (context)
  "Publish CONTEXT's candidates, returning non-nil if a popup is visible."
  (unless (emacs-tui-completion--valid-p context)
    (user-error "Completion context is no longer active"))
  (let* ((stamp (emacs-tui-completion--stamp))
         (projection (emacs-tui-completion--projection context))
         (items (emacs-tui-completion--items context projection))
         (source (current-buffer)))
    (unless (and (equal stamp (emacs-tui-completion--stamp))
                 (eq context emacs-tui-completion--context))
      (error "Completion provider changed the source context"))
    (if (not items) (progn (emacs-tui-completion--release context) nil)
      (let ((title (format "Completion %d/%d | TAB accept"
                           (length items) (length (plist-get projection :candidates)))))
        (if (emacs-tui-live-p (emacs-tui--completion-session context))
            (emacs-tui-update (emacs-tui--completion-session context) 'candidates
                              :title title :items items)
          (setf (emacs-tui--completion-session context)
                (emacs-tui-popup
                 :window (emacs-tui--completion-window context)
                 :begin (emacs-tui--completion-begin context)
                 :end (emacs-tui--completion-end context)
                 :position emacs-tui-completion-position :width 48 :height 10
                 :view (emacs-tui-view :id 'candidates :title title :items items)
                 :on-close (lambda (_session)
                             (when (buffer-live-p source)
                               (with-current-buffer source
                                 (emacs-tui-completion--release context))))))))
      (setf (emacs-tui--completion-projection context) projection
            (emacs-tui--completion-stamp context) stamp)
      (setq emacs-tui-completion--active t)
      (add-hook 'post-command-hook #'emacs-tui-completion--post-command nil t)
      t)))

(defun emacs-tui-completion--in-region (begin end table &optional predicate)
  "Present completion TABLE for BEGIN..END with PREDICATE, without insertion."
  (when emacs-tui-completion--context
    (emacs-tui-completion--release emacs-tui-completion--context))
  (let ((context (emacs-tui--make-completion
                  :buffer (current-buffer) :window (selected-window)
                  :begin (copy-marker begin) :end (copy-marker end t)
                  :table table :predicate predicate
                  :extra (copy-sequence completion-extra-properties)
                  :valid completion-in-region-mode-predicate
                  :ignore-case completion-ignore-case)))
    (setq emacs-tui-completion--context context)
    (condition-case err
        (emacs-tui-completion--refresh context)
      ((error quit)
       (emacs-tui-completion--release context)
       (signal (car err) (cdr err))))))

(defun emacs-tui-completion--post-command ()
  "Refresh the active completion after native source edits or point movement."
  (let ((context emacs-tui-completion--context))
    (when context
      (condition-case err
          (cond
           ((not (emacs-tui-completion--valid-p context))
            (emacs-tui-completion--release context))
           ((not (equal (emacs-tui--completion-stamp context)
                        (emacs-tui-completion--stamp)))
            (emacs-tui-completion--refresh context)))
        ((error quit)
         (emacs-tui-completion--release context)
         (message "TUI completion: %s" (error-message-string err)))))))

(defun emacs-tui-completion--session ()
  "Return the active completion popup, or signal a user error."
  (let ((session (and emacs-tui-completion--context
                      (emacs-tui--completion-session emacs-tui-completion--context))))
    (unless (emacs-tui-live-p session) (user-error "No active completion popup"))
    session))

(defun emacs-tui-completion-next ()
  "Select the next completion without editing the source."
  (interactive)
  (emacs-tui-next-item (emacs-tui-completion--session)))

(defun emacs-tui-completion-previous ()
  "Select the previous completion without editing the source."
  (interactive)
  (emacs-tui-previous-item (emacs-tui-completion--session)))

(defun emacs-tui-completion-move ()
  "Move the completion popup clockwise through eight compass positions."
  (interactive)
  (setq-local emacs-tui-completion-position
              (emacs-tui-reposition-popup (emacs-tui-completion--session))))

(defun emacs-tui-completion-dismiss ()
  "Close the completion popup without changing the source."
  (interactive)
  (when emacs-tui-completion--context
    (emacs-tui-completion--release emacs-tui-completion--context)))

(defun emacs-tui-completion-accept ()
  "Insert the selected completion explicitly and finish this completion.
Revalidate candidates and source bounds first.  An edit failure preserves the
popup for retry.  The provider's exit callback runs once after the edit and
popup cleanup; a callback error does not roll back accepted source text."
  (interactive)
  (let* ((session (emacs-tui-completion--session))
         (context emacs-tui-completion--context)
         (raw (plist-get (emacs-tui-current-item session) :value)))
    (unless (and (emacs-tui-completion--valid-p context)
                 (equal (emacs-tui--completion-stamp context)
                        (emacs-tui-completion--stamp)))
      (emacs-tui-completion--release context)
      (user-error "Completion source changed; invoke completion again"))
    (let* ((fresh (emacs-tui-completion--projection context))
           (old (emacs-tui--completion-projection context))
           (begin (plist-get fresh :begin)) (end (plist-get fresh :end))
           (extra (emacs-tui--completion-extra context))
           (exit (plist-get extra :exit-function))
           ;; An editing hook may start another completion and release this
           ;; context's markers.  Native completion reports prefix + choice.
           (completed (concat (buffer-substring-no-properties
                               (emacs-tui--completion-begin context) begin) raw)))
      (unless (and (member raw (plist-get fresh :candidates))
                   (= begin (plist-get old :begin)) (= end (plist-get old :end))
                   (equal (emacs-tui--completion-stamp context)
                          (emacs-tui-completion--stamp))
                   (eq context emacs-tui-completion--context))
        (emacs-tui-completion--release context)
        (user-error "Completion candidate changed; invoke completion again"))
      ;; Native tables exclude the field separator from the suffix boundary,
      ;; but may include it in a candidate (notably directory names ending /).
      (when (and (< end (emacs-tui--completion-end context))
                 (> (length raw) 0) (eq (char-after end) (aref raw (1- (length raw)))))
        (setq end (1+ end)))
      (atomic-change-group
        (delete-region begin end)
        (goto-char begin)
        (insert (substring-no-properties raw)))
      (let ((completion-extra-properties extra)
            (completion-ignore-case (emacs-tui--completion-ignore-case context))
            (minibuffer-completion-table (emacs-tui--completion-table context))
            (minibuffer-completion-predicate (emacs-tui--completion-predicate context)))
        (emacs-tui-completion--release context)
        (when exit
          (let ((bounds (completion-boundaries completed minibuffer-completion-table
                                               minibuffer-completion-predicate "")))
            (funcall exit completed (if (= (car bounds) (length completed))
                                        'exact 'finished))))))))

(defvar emacs-tui-completion--map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "M-n") #'emacs-tui-completion-next)
    (define-key map (kbd "M-p") #'emacs-tui-completion-previous)
    (define-key map (kbd "TAB") #'emacs-tui-completion-accept)
    (define-key map (kbd "C-g") #'emacs-tui-completion-dismiss)
    (define-key map (kbd "C-c C-p") #'emacs-tui-completion-move)
    map)
  "Bindings enabled only while this buffer owns a completion popup.")
(add-to-list 'minor-mode-map-alist
             (cons 'emacs-tui-completion--active emacs-tui-completion--map))

(defun emacs-tui-completion--disable ()
  "Disable the optional frontend before source locals can be discarded."
  (emacs-tui-completion-mode -1))

;;;###autoload
(define-minor-mode emacs-tui-completion-mode
  "Use a source-preserving popup for this buffer's `completion-at-point'.
Invoke `completion-at-point' normally to begin.  Then type to filter, use
`emacs-tui-completion-next' and `emacs-tui-completion-previous' to select,
`emacs-tui-completion-accept' to accept, `emacs-tui-completion-move' to move,
and `emacs-tui-completion-dismiss' to dismiss.
Bindings apply only while a popup is visible.  Initial provider dispatch is
manual; arbitrary completion functions are not called on every keystroke.
Requires graphical or native TTY child frames.  Disabling restores the prior
completion frontend when this mode still owns it."
  :lighter " TUI-CAPF"
  (if emacs-tui-completion-mode
      (unless emacs-tui-completion--previous
        (unless (and (not (minibufferp)) (emacs-tui-popup-supported-p))
          (setq emacs-tui-completion-mode nil)
          (user-error "TUI completion needs a source window with native child frames"))
        (setq emacs-tui-completion--previous
              (cons (local-variable-p 'completion-in-region-function)
                    completion-in-region-function))
        (setq-local completion-in-region-function #'emacs-tui-completion--in-region)
        (add-hook 'change-major-mode-hook #'emacs-tui-completion--disable nil t)
        (add-hook 'kill-buffer-hook #'emacs-tui-completion--disable nil t))
    (emacs-tui-completion-dismiss)
    (when (and emacs-tui-completion--previous
               (eq completion-in-region-function #'emacs-tui-completion--in-region))
      (if (car emacs-tui-completion--previous)
          (setq-local completion-in-region-function (cdr emacs-tui-completion--previous))
        (kill-local-variable 'completion-in-region-function)))
    (setq emacs-tui-completion--previous nil)
    (remove-hook 'change-major-mode-hook #'emacs-tui-completion--disable t)
    (remove-hook 'kill-buffer-hook #'emacs-tui-completion--disable t)))

(provide 'emacs-tui-completion)

;; Local Variables:
;; package-lint-main-file: "emacs-tui.el"
;; End:
;;; emacs-tui-completion.el ends here
