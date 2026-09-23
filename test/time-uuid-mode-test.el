;;; time-uuid-mode-test.el --- Tests for time-uuid-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Rob Plant

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Run with:
;;
;;   make test
;;
;; or directly:
;;
;;   emacs -Q --batch -L . -L test \
;;     -l test/time-uuid-mode-test.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'time-uuid-mode)

;; The decoder formats in the local zone, so the fixed vectors below only
;; hold if the zone is pinned.  Do it once, at load, for the whole suite.
(setenv "TZ" "UTC")

;;;; Fixtures

(defconst time-uuid-mode-test--uuid "8757c000-b0dd-11ee-89ab-0123456789ab"
  "A v1 UUID whose embedded time is 2024-01-12T00:00:00Z.")

(defconst time-uuid-mode-test--iso "2024-01-12T00:00:00"
  "The decoding of `time-uuid-mode-test--uuid'.")

(defmacro time-uuid-mode-test--with-buffer (text &rest body)
  "Run BODY in a temp buffer holding TEXT, point at `point-min'.
Overlays and any preview timers are torn down afterwards so tests
cannot leak state into one another."
  (declare (indent 1) (debug (form body)))
  `(unwind-protect
       (with-temp-buffer
         (insert ,text)
         (goto-char (point-min))
         ,@body)
     (time-uuid-mode-remove-all-overlays)
     (dolist (timer timer-list)
       (when (eq (timer--function timer) #'delete-overlay)
         (cancel-timer timer)))))

(defun time-uuid-mode-test--labels ()
  "Return the overlay strings painted in the buffer, in buffer order."
  (let (labels)
    (dolist (overlay (sort (overlays-in (point-min) (point-max))
                           (lambda (a b) (< (overlay-start a) (overlay-start b)))))
      (let ((after (overlay-get overlay 'after-string)))
        (when after
          (push (substring-no-properties after) labels))))
    (nreverse labels)))

(defun time-uuid-mode-test--ago (seconds-ago)
  "Return the time-ago phrase for a timestamp SECONDS-AGO in the past."
  (time-uuid-mode-time-ago
   (format-time-string "%FT%T" (time-subtract (current-time) seconds-ago))))

;;;; Decoding

(ert-deftest time-uuid-mode-test-decodes-known-uuid ()
  "A v1 UUID decodes to the timestamp packed into its first three fields."
  (should (equal (time-uuid-mode-uuid-to-iso8601 time-uuid-mode-test--uuid)
                 time-uuid-mode-test--iso)))

(ert-deftest time-uuid-mode-test-decode-ignores-clock-and-node ()
  "Only time-low, time-mid and time-high feed the timestamp."
  (should (equal (time-uuid-mode-uuid-to-iso8601
                  "8757c000-b0dd-11ee-bfff-ffffffffffff")
                 time-uuid-mode-test--iso)))

(ert-deftest time-uuid-mode-test-decode-is-case-insensitive-on-digits ()
  "Uppercase hex decodes the same as lowercase."
  (should (equal (time-uuid-mode-uuid-to-iso8601
                  (upcase time-uuid-mode-test--uuid))
                 time-uuid-mode-test--iso)))

(ert-deftest time-uuid-mode-test-decode-crosses-the-32-bit-boundary ()
  "time-low wrapping into time-mid must not lose the carry.
The UUID epoch is 1582; these timestamps are far wider than 32 bits,
so a decoder that truncates anywhere shows a wildly wrong year."
  (should (equal (time-uuid-mode-uuid-to-iso8601
                  "ffffffff-b0dd-11ee-89ab-0123456789ab")
                 "2024-01-12T00:03:22"))
  ;; One 100ns tick later, with the carry landing in time-mid: a decoder
  ;; that truncates puts these two decades apart.
  (should (equal (time-uuid-mode-uuid-to-iso8601
                  "00000000-b0de-11ee-89ab-0123456789ab")
                 "2024-01-12T00:03:22")))

;;;; The regexp

(ert-deftest time-uuid-mode-test-regexp-matches-v1 ()
  "The regexp finds a v1 UUID embedded in surrounding text."
  (should (string-match time-uuid-mode-regexp
                        (concat "id=" time-uuid-mode-test--uuid ",")))
  (should (equal (match-string 0 (concat "id=" time-uuid-mode-test--uuid ","))
                 time-uuid-mode-test--uuid)))

(ert-deftest time-uuid-mode-test-regexp-rejects-other-versions ()
  "v4 UUIDs carry no timestamp, so they must not be matched."
  (should-not (string-match time-uuid-mode-regexp
                            "8757c000-b0dd-41ee-89ab-0123456789ab")))

(ert-deftest time-uuid-mode-test-regexp-rejects-bad-variant ()
  "The variant nibble must be one of 8, 9, a or b."
  (should-not (string-match time-uuid-mode-regexp
                            "8757c000-b0dd-11ee-79ab-0123456789ab")))

;;;; Painting

(ert-deftest time-uuid-mode-test-overlays-every-uuid ()
  "Each matching UUID gets its own end-of-line label."
  (time-uuid-mode-test--with-buffer
      (concat time-uuid-mode-test--uuid "\n" time-uuid-mode-test--uuid "\n")
    (let ((time-uuid-mode-time-ago-flag nil))
      (time-uuid-mode-overlay-all-uuid-v1s)
      (should (equal (time-uuid-mode-test--labels)
                     (list (concat " " time-uuid-mode-test--iso)
                           (concat " " time-uuid-mode-test--iso)))))))

(ert-deftest time-uuid-mode-test-overlay-includes-time-ago-when-enabled ()
  "With the flag on, the label carries the relative time too."
  (time-uuid-mode-test--with-buffer time-uuid-mode-test--uuid
    (let ((time-uuid-mode-time-ago-flag t))
      (time-uuid-mode-overlay-all-uuid-v1s)
      (should (string-prefix-p (concat " " time-uuid-mode-test--iso " - ")
                               (car (time-uuid-mode-test--labels))))
      (should (string-suffix-p "days ago" (car (time-uuid-mode-test--labels)))))))

(ert-deftest time-uuid-mode-test-overlay-skips-non-v1 ()
  "A buffer with no v1 UUID gets no overlays."
  (time-uuid-mode-test--with-buffer "8757c000-b0dd-41ee-89ab-0123456789ab\n"
    (time-uuid-mode-overlay-all-uuid-v1s)
    (should (equal (time-uuid-mode-test--labels) nil))))

(ert-deftest time-uuid-mode-test-repaint-does-not-accumulate ()
  "Painting twice replaces the overlays rather than stacking them.
The mode repaints from `post-command-hook', so a leak here grows
without bound as the user types."
  (time-uuid-mode-test--with-buffer time-uuid-mode-test--uuid
    (time-uuid-mode-overlay-all-uuid-v1s)
    (time-uuid-mode-overlay-all-uuid-v1s)
    (should (= 1 (length time-uuid-mode-stamp-overlays)))
    (should (= 1 (length (time-uuid-mode-test--labels))))))

(ert-deftest time-uuid-mode-test-disabling-the-mode-clears-overlays ()
  "Turning the mode off removes what it painted."
  (time-uuid-mode-test--with-buffer time-uuid-mode-test--uuid
    (time-uuid-mode 1)
    (time-uuid-mode-overlay-all-uuid-v1s)
    (should (time-uuid-mode-test--labels))
    (time-uuid-mode -1)
    (should (equal (time-uuid-mode-test--labels) nil))
    (should-not (memq #'time-uuid-mode-overlay-all-uuid-v1s
                      (buffer-local-value 'post-command-hook (current-buffer))))))

;;;; Time ago

(ert-deftest time-uuid-mode-test-time-ago-units ()
  "Each unit is picked at its own threshold and pluralised."
  (should (equal (time-uuid-mode-test--ago 30) "Less than a minute ago"))
  (should (equal (time-uuid-mode-test--ago 60) "1 minute ago"))
  (should (equal (time-uuid-mode-test--ago (* 5 60)) "5 minutes ago"))
  (should (equal (time-uuid-mode-test--ago 3600) "1 hour ago"))
  (should (equal (time-uuid-mode-test--ago (* 3 3600)) "3 hours ago"))
  (should (equal (time-uuid-mode-test--ago 86400) "1 day ago"))
  (should (equal (time-uuid-mode-test--ago (* 9 86400)) "9 days ago")))

(ert-deftest time-uuid-mode-test-time-ago-is-unsigned ()
  "The difference is taken as an absolute value, so future stamps read \"ago\".
Documenting the current behaviour: v1 UUIDs from a clock running ahead
would otherwise produce a negative count."
  (should (equal (time-uuid-mode-test--ago (* -2 86400)) "2 days ago")))

;;;; Preview

(ert-deftest time-uuid-mode-test-preview-labels-uuid-at-point ()
  "The preview command labels the UUID under the cursor."
  (time-uuid-mode-test--with-buffer time-uuid-mode-test--uuid
    (goto-char (+ (point-min) 4))
    (time-uuid-mode-preview-formatted-time)
    (should (equal (time-uuid-mode-test--labels)
                   (list (concat " " time-uuid-mode-test--iso))))))

(provide 'time-uuid-mode-test)
;;; time-uuid-mode-test.el ends here
