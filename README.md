# time-uuid-mode

Convert time based UUIDs into their ISO8601 date times and preview them inline
as an overlay.

Exports

- **Minor Mode** `time-uuid-mode`

  Find all time based UUIDs in the buffer and preview the date time of them.

- **Command** `time-uuid-mode-preview-formatted-time ()`

  Create an overlay containing the date time beside the UUID v1 at the cursor.

- **Variables** `time-uuid-mode-time-ago-flag`

  Set to t to preview how long ago the displayed date time was, for example it
  will show "3 hours ago" beside the timestamp.

- **Variables** `time-uuid-mode-time-format`

  The `format-time-string` format for the time, `"%F %T"` by default
  (`2024-01-12 00:00:00`). Set it to `"%FT%T"` for ISO 8601.

- **Face** `time-uuid-mode-label`

  The colours of the label, yellow on black by default. Change it with
  `M-x customize-face`, or in Doom:

  ```elisp
  (custom-set-faces!
    '(time-uuid-mode-label :background "yellow" :foreground "black" :weight bold))
  ```
