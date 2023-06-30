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
  will show "3 Hours ago" beside the timestamp.
