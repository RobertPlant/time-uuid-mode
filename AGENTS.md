# AGENTS.md

## Code style

Run `make` before committing: byte-compile with warnings as errors, `checkdoc`, then the ERT suite. CI runs
the same three on Emacs 27.1 to 31.1, so nothing newer than `Package-Requires` allows.

- Keep the Doom file header filled in. Bump `Modified:` and `Version:` when behaviour changes.
- Every symbol starts with `time-uuid-mode-`, and internal ones with `time-uuid-mode--`. The group stays
  `time-uuid`.
- `defgroup`, `defconst`, `defvar`, `defcustom` and `defface` at the top of the file. Every `defcustom` has
  `:type` and `:group`.
- A one-line docstring on every function and variable, in the imperative ("Remove time uuids overlays.").
  `checkdoc` must stay clean.
- `;;;###autoload` on the mode and interactive commands only.
- `let*` names each step and each condition, then `when` for guards and `cond` / `pcase` for cases. Close
  parens on the last line, never on their own.
- Helpers compute and return values (`time-uuid-mode--parse-uuid-time`, `time-uuid-mode-describe-time-ago`).
  Overlays and hooks only change in the mode, the scan and the preview command. Buffer-local hooks use the
  `nil t` local arguments.
- `seq-*` and `mapcar` over loops. `dolist` only where the body is a side effect (making overlays).
- Nothing destructive on values you were given: `remove` not `delete`, `append` not `nconc`, `reverse` not
  `nreverse`. No `setq` on an argument, plain `let` for temporaries.
- Nor change a value once it's made, a list a call returned included: no `sort`, `setcar` or `nconc` on it.
  `seq-sort` copies (keyword `sort` is Emacs 30, newer than `Package-Requires`). A list the function is still
  building with `push` is fine.
- Values first, then effects: the `let*` bindings work out everything the body needs, then the body makes the
  overlays and changes hooks together. Only a value that needs an effect's result comes after it.
- A list is plural and each thing in it singular, a lambda's argument included: `(mapcar (lambda (window) ...)
  windows)`, never `w` or `x`. A sort's comparator keeps `(a b)`. No abbreviations.
- A function's name is a verb and its object: `parse` for text turned into a value, `format` / `describe` for
  a string, `add` / `remove` for overlays, `-p` for a predicate. Not a noun and a preposition
  (`uuid-to-iso8601`) or a bare noun (`time-ago`).
- No banner comments over a group of functions or tests (`;;;; Fixtures`); the names say what they are.
  `;;; Commentary:` and `;;; Code:` are package headers and stay.
- Never `funcall` a symbol looked up from an alist or built with `intern`.
- Functions under ~50 lines. Comments are rare one-line notes on why.
- New behaviour gets an ERT test in `test/time-uuid-mode-test.el`, and the test has to fail without the
  change.
- No em-dashes in code, comments or docs. Use a comma, hyphen or full stop.
- Commit messages are one line, past tense, full stop, under about 60 characters: `Added time-ago feature and
  flag.` Say what changed, not how. A body only for the why the diff can't show.
