;;; time-uuid-mode.el --- Minor mode for previewing time uuids as an overlay -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2024 Robert Plant
;;
;; Author: Robert Plant <rob@robertplant.io>
;; Maintainer: Robert Plant <rob@robertplant.io>
;; Created: March 10, 2023
;; Modified: October 06, 2026
;; Version: 0.0.4
;; Keywords: extensions, convenience, data, tools
;; Homepage: https://github.com/RobertPlant/time-uuid-mode
;; Package-Requires: ((emacs "27.1"))
;; SPDX-License-Identifier: GPL-3.0-only
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; This is a convenience tool to search for time UUIDs (v1) and preview the
;; corresponding date stored within it.  This can be useful when loading data
;; that uses a v1 UUID to find the latest record.
;;
;; A single function is also provided to preview a single time UUID under the
;; cursor, this will clean itself up after 5 seconds.
;;
;; Get the development version from git:
;;
;;    git clone https://github.com/RobertPlant/time-uuid-mode.git

;;; Code:

(defgroup time-uuid nil
  "Preview the timestamps stored in time-based UUIDs."
  :group 'convenience
  :prefix "time-uuid-mode-")

(defconst time-uuid-mode-regexp
  "\\b[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-1[0-9a-f]\\{3\\}-[89ab][0-9a-f]\\{3\\}-[0-9a-f]\\{12\\}\\b"
  "Define a regular expression to match time-based UUIDs.")

(defvar-local time-uuid-mode-stamp-overlays nil
  "Store the time stamp overlays in this buffer.")

(defcustom time-uuid-mode-time-ago-flag t
  "Non-nil means append a relative \"time ago\" phrase to each overlay."
  :type 'boolean
  :group 'time-uuid)

(defface time-uuid-mode-label
  '((t :background "yellow" :foreground "black"))
  "Face for the timestamp shown beside a time-based UUID."
  :group 'time-uuid)

(defun time-uuid-mode-remove-all-overlays ()
  "Remove time uuids overlays."
  (mapc #'delete-overlay time-uuid-mode-stamp-overlays)
  (setq time-uuid-mode-stamp-overlays nil))

(defun time-uuid-mode--uuid-time (uuid)
  "Return the time stored in the time-based UUID as a Lisp time value."
  (let* ((hex (replace-regexp-in-string "-" "" uuid))
         ;; time-high, time-mid, time-low; the first nibble of time-high is
         ;; the version, not part of the timestamp.
         (ticks (string-to-number (concat (substring hex 13 16)
                                          (substring hex 8 12)
                                          (substring hex 0 8))
                                  16)))
    ;; 100ns ticks since the Gregorian epoch, 1582-10-15.
    (seconds-to-time (/ (- ticks 122192928000000000) 10000000))))

(defun time-uuid-mode-uuid-to-iso8601 (uuid)
  "Convert a time-based UUID to ISO-8601 format."
  (format-time-string "%FT%T" (time-uuid-mode--uuid-time uuid)))

(defun time-uuid-mode-time-ago (time)
  "Describe how long ago TIME was, such as \"3 days ago\".
A TIME in the future is described the same way."
  (let* ((seconds (abs (float-time (time-subtract (current-time) time))))
         (minutes (floor seconds 60))
         (hours (floor minutes 60))
         (days (floor hours 24)))
    (cond
     ((>= days 1)
      (concat (number-to-string days) (if (= days 1) " day ago" " days ago")))
     ((>= hours 1)
      (concat (number-to-string hours) (if (= hours 1) " hour ago" " hours ago")))
     ((>= minutes 1)
      (concat (number-to-string minutes) (if (= minutes 1) " minute ago" " minutes ago")))
     (t
      "Less than a minute ago"))))

(defun time-uuid-mode--add-label (uuid time-ago)
  "Label the current line with the time stored in UUID and return the overlay.
Non-nil TIME-AGO appends a relative \"time ago\" phrase."
  (let ((overlay (make-overlay (1- (line-end-position)) (line-end-position)))
        (time (time-uuid-mode--uuid-time uuid)))
    (overlay-put overlay 'after-string
                 (concat " " (propertize (format-time-string "%FT%T" time)
                                         'face 'time-uuid-mode-label)
                         (when time-ago
                           (concat " - " (propertize (time-uuid-mode-time-ago time)
                                                     'face 'time-uuid-mode-label)))))
    (push overlay time-uuid-mode-stamp-overlays)
    overlay))

(defun time-uuid-mode-overlay-all-uuid-v1s (&rest _)
  "Overlay the visible time-based UUIDs with their date and time.
Only the text shown in a window is searched, or the whole buffer when
no window shows it.  The ignored arguments let this run from
`window-scroll-functions'."
  (time-uuid-mode-remove-all-overlays)
  ;; ponytail: one span from the topmost to the bottommost window, so two
  ;; windows far apart in a huge buffer scan everything between them.
  (let* ((windows (get-buffer-window-list nil nil t))
         (start (if windows (apply #'min (mapcar #'window-start windows)) (point-min)))
         (end (if windows
                  (apply #'max (mapcar (lambda (window) (window-end window t)) windows))
                (point-max))))
    (save-excursion
      (goto-char start)
      (while (re-search-forward time-uuid-mode-regexp end t)
        (time-uuid-mode--add-label (match-string 0) time-uuid-mode-time-ago-flag)))))

;;;###autoload
(define-minor-mode time-uuid-mode
  "Overlay time-based UUIDs with the corresponding date and time."
  :lighter " UUID"
  :group 'time-uuid
  (if time-uuid-mode
      (progn
        ;; `post-command-hook' runs before redisplay, so after a jump like
        ;; `end-of-buffer' it still sees the old `window-start'; the scroll
        ;; hook repaints once redisplay has moved the window.
        (add-hook 'post-command-hook #'time-uuid-mode-overlay-all-uuid-v1s nil t)
        (add-hook 'window-scroll-functions #'time-uuid-mode-overlay-all-uuid-v1s nil t))
    (time-uuid-mode-remove-all-overlays)
    (remove-hook 'post-command-hook #'time-uuid-mode-overlay-all-uuid-v1s t)
    (remove-hook 'window-scroll-functions #'time-uuid-mode-overlay-all-uuid-v1s t)))

;;;###autoload
(defun time-uuid-mode-preview-formatted-time ()
  "Preview the date time for the selected UUID.
The overlay is deleted on a timer."
  (interactive)
  (let ((uuid (if (region-active-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (thing-at-point 'uuid t))))
    (unless (and uuid (string-match-p (concat "\\`" time-uuid-mode-regexp "\\'") uuid))
      (user-error "No time-based (v1) UUID at point"))
    (run-with-timer 5 nil #'delete-overlay (time-uuid-mode--add-label uuid nil))))

(provide 'time-uuid-mode)

;;; time-uuid-mode.el ends here
