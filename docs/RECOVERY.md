# Interrupted saves and recovery

[Overview](../README.md) - [Usage](USAGE.md)

The application writes a checksummed, binary-safe journal before moving a
pattern and before each edit. If an operation fails or OC is interrupted, other
edits are locked. On restart it inspects the actual source/editing inventories
instead of assuming the last journal phase completed.

## Normal recovery

Keep both interfaces/adapters connected, their AE network powered and their
chunks loaded. Restart `pattern_editor`:

- **Finish** completes the saved draft and returns the pattern.
- **Restore original** reverses draft edits and returns the original contents.
- **Quit** leaves the pattern and journal where they are for later recovery.

Do not put another pattern in the original slot. If it is occupied, recovery
stops instead of overwriting it. Remove the unrelated occupant yourself, leaving
the transaction's pattern alone, then retry.

A crash after the final return can leave a pending journal even though the
pattern is already back. Finish recognizes the saved draft and acknowledges the
completed operation. Restore will not silently move an already-returned changed
pattern again; Finish first, then rescan and make a new reviewed edit if needed.

If the wrong empty interface was chosen in Setup, the remote/local pattern
comparison fails before editing. Restore original can return the unchanged
remote pattern without modifying the unrelated adapter-connected interface.
After recovery, correct Setup.
The v1.0.6 recovery path also tolerates a read error from an unrelated adapter
when restoring a remote pattern that still matches the original. Leave both
AE interfaces and the journal intact until Restore succeeds.

## When automatic recovery stops

An unexpected pattern, missing physical pattern, changed ingredients, corrupt
journal, unavailable interface or full return slot causes a stop with the
journal retained. Do not delete the journal simply to dismiss the message.

Inspect both interfaces. If another player has changed or moved the pattern,
restore the expected physical state before retrying. If it cannot be recovered,
keep the data files for inspection and restore from your world backup or an
independently saved pattern. The Lua snapshot cannot materialize a lost pattern.

## Data files

Normal operation uses `/home/.ae2-pattern-editor/`:

| File | Purpose |
| --- | --- |
| settings | Adapter component addresses and selected editing-station location |
| transaction | Write-ahead original/draft, current/next states and recovery phase |
| last-original | Original snapshot from the most recent attempted save |
| *.bak | Previous generation kept during atomic replacement |
| *.tmp | A write that did not finish being installed |

Each data file has a checksum header. Data parsing does not execute Lua.
When the journal primary is absent but its backup exists, the backup is treated
as a possible interrupted replacement. A corrupt primary raises an error rather
than silently discarding newer recovery data. Preserve all generations and
inspect them before choosing a backup manually.

Demo uses a separate directory. It cannot modify real AE patterns, and its
journal should not be copied into the real data directory.
