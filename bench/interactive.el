;;; interactive.el --- Real command-loop latency fixture -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel
;; Assisted-by: Codex:gpt-6.1-sol-wm
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Driven one key at a time by run.py through a real PTY.  A private OSC marker
;; follows forced redisplay.  It measures terminal output, not physical paint.

;;; Code:
(require 'cl-lib)
(require 'json)
(setq load-prefer-newer t)
;; Keep deferred compilation out of the timed path, on every tested runtime.
(when (boundp 'native-comp-deferred-compilation)
  (setq native-comp-deferred-compilation nil))
(when (boundp 'native-comp-jit-compilation)
  (setq native-comp-jit-compilation nil))
(require 'emacs-tui)
(require 'emacs-tui-completion)

(defvar emacs-tui-bench--popup-p
  (equal (getenv "EMACS_TUI_BENCH_PRESENTATION") "popup"))

(defvar emacs-tui-bench--libraries nil)
(let* ((mode (getenv "EMACS_TUI_BENCH_LOAD_MODE"))
       (suffix (if (equal mode "bytecode") ".elc" ".el"))
       (root (file-name-as-directory (file-truename (getenv "EMACS_TUI_BENCH_LIBRARY_ROOT")))))
  (dolist (symbol '(emacs-tui-next-item emacs-tui-layout-compute emacs-tui-column
                                        emacs-tui--tree-project emacs-tui-action
                                        emacs-tui-completion-next))
    (let ((file (symbol-file symbol 'defun))
          (definition (symbol-function symbol)))
      (unless (and file (string-prefix-p root (file-truename file))
                   (string-suffix-p suffix file))
        (error "Benchmark %s loaded from unexpected file: %S (mode %s)" symbol file mode))
      (unless (if (equal mode "bytecode") (byte-code-function-p definition)
                (and (functionp definition) (not (byte-code-function-p definition))
                     (not (subrp definition))))
        (error "Benchmark %s has unexpected definition type (mode %s)" symbol mode))
      (push (cons (symbol-name symbol) file) emacs-tui-bench--libraries))))

(defvar emacs-tui-bench--session nil)
(defvar emacs-tui-bench--cases nil)
(defvar emacs-tui-bench--case nil)
(defvar emacs-tui-bench--index -1)
(defvar emacs-tui-bench--sequence 0)
(defvar emacs-tui-bench--rows nil)
(defvar emacs-tui-bench--matches nil)
(defvar emacs-tui-bench--start nil)
(defvar emacs-tui-bench--counts nil)
(defvar emacs-tui-bench--gc nil)
(defvar emacs-tui-bench--sample nil)
(defvar emacs-tui-bench--records nil)
(defvar emacs-tui-bench--advancing nil)
(defvar emacs-tui-bench--filter-prefix
  (or (getenv "EMACS_TUI_BENCH_FILTER_PREFIX") "")
  "Initial text in filter workloads, outside measured native edits.")


(defvar emacs-tui-bench--source nil)
(defvar emacs-tui-bench--window nil)
(defvar emacs-tui-bench--parent nil)
(defvar emacs-tui-bench--child nil)
(defvar emacs-tui-bench--anchor nil)
(defvar emacs-tui-bench--text nil)
(defvar emacs-tui-bench--table-ms 0.0)
(defvar emacs-tui-bench--table-calls 0)
(defvar emacs-tui-bench--last-position nil)

(defun emacs-tui-bench--next ()
  "Navigate the floating view without leaving its source window."
  (interactive)
  (emacs-tui-next-item emacs-tui-bench--session))

(defun emacs-tui-bench--move ()
  "Move the floating view clockwise without leaving its source window."
  (interactive)
  (emacs-tui-reposition-popup emacs-tui-bench--session))

(defun emacs-tui-bench--table (string predicate action)
  "Complete STRING against the fixture table with PREDICATE and ACTION.
Measure the actual synchronous table callback, including matching its data."
  (let ((start (current-time)))
    (unwind-protect
        (if (eq action 'metadata)
            '(metadata (display-sort-function . identity))
          (complete-with-action action emacs-tui-bench--rows string predicate))
      (when emacs-tui-bench--start
        (cl-incf emacs-tui-bench--table-ms (emacs-tui-bench--elapsed start))
        (cl-incf emacs-tui-bench--table-calls)))))

(defun emacs-tui-bench--capf ()
  "Return a real native completion source for the current fixture field."
  (list emacs-tui-bench--anchor (point) #'emacs-tui-bench--table))

(defun emacs-tui-bench--open-popup (kind size)
  "Prepare native popup workload KIND with SIZE rows outside timing."
  (unless (and (not (display-graphic-p)) (emacs-tui-popup-supported-p))
    (error "Native TTY popup benchmark unavailable; no window fallback measured"))
  (switch-to-buffer (get-buffer-create "*Popup benchmark source*"))
  (fundamental-mode)
  (erase-buffer)
  (insert (make-string 35 ?\n))
  (goto-char (point-min)) (forward-line 17)
  (insert (make-string 54 ?\s))
  (setq emacs-tui-bench--anchor (point))
  (insert "row ")
  (setq emacs-tui-bench--source (current-buffer)
        emacs-tui-bench--window (selected-window)
        emacs-tui-bench--parent (selected-frame)
        emacs-tui-bench--text (buffer-string)
        emacs-tui-bench--rows
        (cl-loop for i below size collect
                 (format "row %s%05d POPUP-BENCH-PAINT 日本語 é"
                         (if (zerop (% i 10)) "x" "y") i)))
  (buffer-disable-undo)
  (use-local-map (make-sparse-keymap))
  (local-set-key (kbd "M-n") #'emacs-tui-bench--next)
  (local-set-key (kbd "C-c C-p") #'emacs-tui-bench--move)
  (if (equal kind "filter-completion")
      (progn
        (setq-local completion-at-point-functions '(emacs-tui-bench--capf))
        (setq-local completion-styles '(basic))
        (setq-local completion-category-overrides nil)
        (setq-local completion-category-defaults nil)
        (setq-local emacs-tui-completion-limit 200)
        (setq-local emacs-tui-completion-position 'north)
        (emacs-tui-completion-mode 1)
        (completion-at-point)
        (setq emacs-tui-bench--session (emacs-tui-completion--session)))
    (setq emacs-tui-bench--session
          (emacs-tui-popup
           :view (emacs-tui-view :id 'rows
                                 :items (cl-loop for row in emacs-tui-bench--rows
                                                 for i from 0 collect (list :id i :label row)))
           :begin emacs-tui-bench--anchor :end (point)
           :position 'north :width 48 :height 8)))
  (setq emacs-tui-bench--child (emacs-tui--workspace-frame emacs-tui-bench--session)
        emacs-tui-bench--last-position (frame-position emacs-tui-bench--child)))

(defun emacs-tui-bench--check-popup ()
  "Validate actual native state after timing and before acknowledging output."
  (cl-assert (eq (selected-frame) emacs-tui-bench--parent))
  (cl-assert (eq (selected-window) emacs-tui-bench--window))
  (cl-assert (eq (current-buffer) emacs-tui-bench--source))
  (cl-assert (eq (window-buffer emacs-tui-bench--window) emacs-tui-bench--source))
  (cl-assert (= 1 (length (window-list emacs-tui-bench--parent 'no-minibuffer))))
  (cl-assert (emacs-tui-live-p emacs-tui-bench--session))
  (cl-assert (eq emacs-tui-bench--child (emacs-tui--workspace-frame emacs-tui-bench--session)))
  (cl-assert (eq (frame-parent emacs-tui-bench--child) emacs-tui-bench--parent))
  (let* ((kind (alist-get 'kind emacs-tui-bench--case))
         (size (alist-get 'size emacs-tui-bench--case))
         (filtering (equal kind "filter-completion"))
         (filtered (and filtering (zerop (% emacs-tui-bench--sequence 2))))
         (view (emacs-tui--resolve-view emacs-tui-bench--session
                                        (if filtering 'candidates 'rows)))
         (visible (length (emacs-tui--view-visible-items view))))
    (if filtering
        (progn
          (cl-assert (eq emacs-tui-bench--session (emacs-tui-completion--session)))
          (cl-assert (> emacs-tui-bench--table-calls 0))
          (cl-assert (= visible (min 200 (if filtered (/ (+ size 9) 10) size))))
          ;; Counts alone cannot detect stale contents when both sets hit the cap.
          (cl-assert
           (equal (mapcar (lambda (item) (plist-get item :value))
                          (emacs-tui--view-visible-items view))
                  (cl-subseq (if filtered
                                 (cl-remove-if-not
                                  (lambda (row) (string-prefix-p "row x" row))
                                  emacs-tui-bench--rows)
                               emacs-tui-bench--rows)
                             0 visible)))
          (cl-assert (= (point) (+ emacs-tui-bench--anchor (if filtered 5 4))))
          (cl-assert (equal (buffer-substring-no-properties emacs-tui-bench--anchor (point))
                            (if filtered "row x" "row ")))
          (cl-assert (equal emacs-tui-bench--text
                            (concat (buffer-substring-no-properties (point-min)
                                                                    (+ emacs-tui-bench--anchor 4))
                                    (buffer-substring-no-properties (point) (point-max))))))
      (cl-assert (equal emacs-tui-bench--text (buffer-string)))
      (cl-assert (= (point) (+ emacs-tui-bench--anchor 4)))
      (cl-assert (= visible size))
      (if (equal kind "navigate-popup")
          (cl-assert (= (plist-get (emacs-tui-current-item emacs-tui-bench--session) :id)
                        (mod (1+ emacs-tui-bench--sequence) size)))
        (cl-assert (eq (emacs-tui--popup-position
                        (emacs-tui--workspace-popup emacs-tui-bench--session))
                       (nth (mod (1+ emacs-tui-bench--sequence) 8)
                            emacs-tui-layout-popup-positions)))
        (cl-assert (not (equal emacs-tui-bench--last-position
                               (frame-position emacs-tui-bench--child))))
        (setq emacs-tui-bench--last-position (frame-position emacs-tui-bench--child))))
    (push `(visible_rows . ,visible) emacs-tui-bench--sample)))

(defun emacs-tui-bench--marker (kind)
  "Emit a KIND acknowledgement after display output, tagged with sample index."
  (send-string-to-terminal
   (format "\e]777;TUIBENCH;%s;%d;%d\a" kind
           emacs-tui-bench--index emacs-tui-bench--sequence)))

(defun emacs-tui-bench--fail (error-data)
  "Record ERROR-DATA and terminate with a failing status."
  (with-temp-file (getenv "EMACS_TUI_BENCH_REPORT")
    (insert (json-encode `((error . ,(format "%S" error-data))))))
  (kill-emacs 1))

(defun emacs-tui-bench--elapsed (start)
  "Return milliseconds since START."
  (* 1000.0 (float-time (time-subtract (current-time) start))))

(defun emacs-tui-bench--ack ()
  "Save the current sample and acknowledge completed terminal output."
  (if emacs-tui-bench--popup-p
      (emacs-tui-bench--check-popup)
    (let* ((view (emacs-tui--resolve-view emacs-tui-bench--session 'rows))
           (kind (alist-get 'kind emacs-tui-bench--case))
           (size (alist-get 'size emacs-tui-bench--case))
           (visible (length (emacs-tui--view-visible-items view))))
      (if (string-prefix-p "navigate-" kind)
          (cl-assert (= (plist-get (emacs-tui-current-item emacs-tui-bench--session) :id)
                        (mod (1+ emacs-tui-bench--sequence) size)))
        (cl-assert (= visible (if (zerop (% emacs-tui-bench--sequence 2))
                                  (length emacs-tui-bench--matches) size))))
      (push `(visible_rows . ,visible) emacs-tui-bench--sample)))
  (push emacs-tui-bench--sample emacs-tui-bench--records)
  (emacs-tui-bench--marker "sample")
  (cl-incf emacs-tui-bench--sequence)
  (setq emacs-tui-bench--start nil))

(defun emacs-tui-bench--provider (_session query publish _fail)
  "Schedule controlled fixture data for QUERY through PUBLISH.
The deliberate timer delay is recorded separately from publishing/redisplay."
  (let* ((start (current-time))
         (timer
          (run-at-time
           0.02 nil
           (lambda ()
             (condition-case err
                 (let* ((wait (emacs-tui-bench--elapsed start))
                        (publish-start (current-time)))
                   (funcall publish 'rows :items
                            (if (equal query "x") emacs-tui-bench--matches
                              emacs-tui-bench--rows))
                   (redisplay t)
                   (if emacs-tui-bench--start
                       (progn
                         (setq emacs-tui-bench--sample
                               (append emacs-tui-bench--sample
                                       `((provider_wait_ms . ,wait)
                                         (provider_publish_redisplay_ms
                                          . ,(emacs-tui-bench--elapsed publish-start))
                                         (command_to_result_ms
                                          . ,(emacs-tui-bench--elapsed emacs-tui-bench--start)))))
                         (emacs-tui-bench--ack))
                     (emacs-tui-bench--marker "ready")))
               ((error quit) (emacs-tui-bench--fail err)))))))
    (lambda () (cancel-timer timer))))

(defun emacs-tui-bench--write-report ()
  "Write environment and raw command-loop records to the report file."
  (with-temp-file (getenv "EMACS_TUI_BENCH_REPORT")
    (insert
     (json-encode
      `((emacs . ,emacs-version)
        (system_configuration . ,system-configuration)
        (features . ,system-configuration-features)
        (backend . ,(if emacs-tui-bench--popup-p "native-tty-popup" "windows"))
        (terminal . ,(tty-type))
        (frame_columns . ,(frame-width)) (frame_rows . ,(frame-height))
        (gc_cons_threshold . ,gc-cons-threshold)
        (gc_cons_percentage . ,gc-cons-percentage)
        (deferred_native_compilation . :json-false)
        (library . ,(symbol-file 'emacs-tui-next-item 'defun))
        (loaded_libraries . ,emacs-tui-bench--libraries)
        (records . ,(vconcat (nreverse emacs-tui-bench--records))))))))

(defun emacs-tui-bench--advance ()
  "Prepare the next workload outside the measured command path."
  (interactive)
  (condition-case err
      (progn
        (setq emacs-tui-bench--advancing t emacs-tui-bench--start nil)
        (when emacs-tui-completion-mode (emacs-tui-completion-mode -1))
        (when emacs-tui-bench--session
          (emacs-tui-close emacs-tui-bench--session)
          (when emacs-tui-bench--popup-p
            (cl-assert (not (frame-live-p emacs-tui-bench--child)))
            (cl-assert (not emacs-tui-completion--context))
            (cl-assert (null emacs-tui--sessions))))
        (cl-incf emacs-tui-bench--index)
        (setq emacs-tui-bench--case (pop emacs-tui-bench--cases)
              emacs-tui-bench--sequence 0)
        (if (not emacs-tui-bench--case)
            (progn (emacs-tui-bench--write-report)
                   (emacs-tui-bench--marker "done") (kill-emacs 0))
          (let* ((kind (alist-get 'kind emacs-tui-bench--case))
                 (size (alist-get 'size emacs-tui-bench--case))
                 (provider (equal kind "provider-list"))
                 (filtering (string-prefix-p "filter-" kind))
                 (table (string-suffix-p "table" kind))
                 (map (make-sparse-keymap)))
            (if emacs-tui-bench--popup-p
                (emacs-tui-bench--open-popup kind size)
              (define-key map (kbd "C-c C-b") #'emacs-tui-bench--advance)
              (setq emacs-tui-bench--rows
                    (cl-loop for i below size collect
                             (list :id i :label (format "%s row %05d 日本語 é"
                                                        (if (zerop (% i 10)) "x" "item") i)
                                   :bytes (* i 17)))
                    emacs-tui-bench--matches
                    (cl-remove-if-not (lambda (item) (zerop (% (plist-get item :id) 10)))
                                      emacs-tui-bench--rows))
              (let* ((view (emacs-tui-view
                            :id 'rows :items (unless provider emacs-tui-bench--rows)
                            :columns (when table
                                       (list (emacs-tui-column :id 'name :title "Name"
                                                               :width 35 :value :label)
                                             (emacs-tui-column :id 'bytes :title "Bytes"
                                                               :width 12 :value :bytes :align 'right)))))
                     (views (if filtering
                                (list (emacs-tui-input
                                       :id 'query
                                       :value emacs-tui-bench--filter-prefix
                                       :on-change (lambda (session _id value)
                                                    (emacs-tui-set-query session 'rows value))) view)
                              (list view))))
                (setq emacs-tui-bench--session
                      (if provider
                          (emacs-tui-open :views views :backend 'windows :keymap map
                                          :provider #'emacs-tui-bench--provider :debounce 0.01)
                        (emacs-tui-mount :views views :backend 'windows :keymap map))))
              (when filtering
                (emacs-tui-set-query emacs-tui-bench--session 'rows emacs-tui-bench--filter-prefix)
                (cl-assert (= size (length (emacs-tui--view-visible-items
                                            (emacs-tui--resolve-view emacs-tui-bench--session 'rows)))))
                ;; Type after the initial terms, as an actual user would.
                (goto-char (point-max))))
            ;; Start each workload with ordinary GC settings but no old fixture garbage.
            (garbage-collect)
            ;; Force fresh paint outside timing, even for identical case data.
            (when emacs-tui-bench--popup-p (redraw-display))
            (redisplay t)
            (unless provider (emacs-tui-bench--marker "ready")))))
    ((error quit) (emacs-tui-bench--fail err))))

(defun emacs-tui-bench--before ()
  "Begin a measured native keyboard command."
  (setq emacs-tui-bench--advancing nil)
  (when (memq this-command '(emacs-tui-next-item emacs-tui-previous-item
                                                 self-insert-command backward-delete-char-untabify
                                                 delete-backward-char emacs-tui-bench--next
                                                 emacs-tui-bench--move))
    (setq emacs-tui-bench--table-ms 0.0 emacs-tui-bench--table-calls 0
          emacs-tui-bench--counts (memory-use-counts)
          emacs-tui-bench--gc (cons gcs-done gc-elapsed)
          emacs-tui-bench--start (current-time))))

(defun emacs-tui-bench--after ()
  "Force redisplay and measure the completed native command."
  (when (and emacs-tui-bench--start (not emacs-tui-bench--advancing))
    (condition-case err
        (let* ((redisplay-start (current-time))
               (_ (redisplay t))
               (redisplay-ms (emacs-tui-bench--elapsed redisplay-start))
               (elapsed (emacs-tui-bench--elapsed emacs-tui-bench--start))
               (counts (memory-use-counts)))
          (setq emacs-tui-bench--sample
                `((case . ,emacs-tui-bench--index)
                  (sequence . ,emacs-tui-bench--sequence)
                  (command . ,(symbol-name this-command))
                  (command_redisplay_ms . ,elapsed)
                  (cons_cells . ,(- (car counts) (car emacs-tui-bench--counts)))
                  (string_chars . ,(- (nth 4 counts) (nth 4 emacs-tui-bench--counts)))
                  (gc_count . ,(- gcs-done (car emacs-tui-bench--gc)))
                  (gc_ms . ,(* 1000.0 (- gc-elapsed (cdr emacs-tui-bench--gc))))))
          (when emacs-tui-bench--popup-p
            (setq emacs-tui-bench--sample
                  (append emacs-tui-bench--sample
                          `((table_callback_ms . ,emacs-tui-bench--table-ms)
                            (table_callback_calls . ,emacs-tui-bench--table-calls)
                            (command_without_table_ms . ,(- elapsed emacs-tui-bench--table-ms))
                            (final_redisplay_ms . ,redisplay-ms)))))
          (unless (equal (alist-get 'kind emacs-tui-bench--case) "provider-list")
            (emacs-tui-bench--ack)
            (setq emacs-tui-bench--start nil)))
      ((error quit) (emacs-tui-bench--fail err)))))

(add-hook 'pre-command-hook #'emacs-tui-bench--before)
(add-hook 'post-command-hook #'emacs-tui-bench--after t)
;; The ephemeral query field deliberately retains ordinary editing keymaps.
(global-set-key (kbd "C-c C-b") #'emacs-tui-bench--advance)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq emacs-tui-bench--cases
                  (json-read-from-string (getenv "EMACS_TUI_BENCH_CASES")))
            ;; json-read defaults to vectors, whereas the fixture consumes a list.
            (setq emacs-tui-bench--cases (append emacs-tui-bench--cases nil))
            (run-at-time 0.05 nil #'emacs-tui-bench--advance)))

;;; interactive.el ends here
