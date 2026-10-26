# Using the editor

[Overview](../README.md) - [Installation](INSTALLATION.md) - [Recovery](RECOVERY.md)

## Find a recipe

Click **Scan**, or press Tab then Enter. The terminal supplies a snapshot of its supported, visible
interfaces and encoded patterns. Results include a pattern's output names and
its containing interface. The editing station is excluded. Unsupported pattern
stack types are counted as skipped rather than silently treated as normal items.

Click Search and type `quantium ingot`. Search is case-insensitive, literal text
matching against labels and registry IDs; it is not a regular expression and
does not perform spelling correction. Cycle **Match** between both, inputs and
outputs. Search filters the cached snapshot, not the AE network on each keypress.

Click a result and Open, press Enter, or click the selected row again. Two
patterns producing the same output remain separate results. Their interface
name is shown; the application tracks their location, side and native slot.
Crafting-grid patterns display a read-only notice.

## Edit a processing-pattern draft

Use **Inputs** or **Outputs** to choose a side. Select an ingredient with the
mouse or arrow keys:

| Control | Behavior |
| --- | --- |
| Amount / Enter | Edit the selected quantity; units for items, mB for fluids |
| Add | Search known identities and append a new ingredient, then enter its amount |
| Replace | Choose another identity while initially retaining the old quantity |
| Remove / Delete | Confirm removal of the selected ingredient from the draft |
| x2 | Double every positive input and output amount |
| /2 | Halve every positive amount only when all results are positive whole numbers |
| Preview | Validate and show the before/after changes |
| Back | Leave, with a discard confirmation if the draft changed |

Add/Replace searches ingredients already found in scanned patterns plus currently
stored AE items and fluids. The catalog is fetched on demand and cached until
the next pattern scan or successful save. An identity absent from both must first
be stored in AE or appear in a scanned pattern. Registry ID, kind and a short NBT
checksum distinguish picker entries; the checksum is a display aid, not the
identity itself. Exact binary item NBT is preserved when OC exposes it.

For renamed assembly-line ingredients, select the actual renamed variant in the
picker. Merely typing a display name into a search field does not create/rename
an item. Zero input quantities represent nonconsumed catalysts and stay zero
when scaling. Outputs must be positive. The final input or output cannot be
removed. Editing the actual GregTech recipe is outside this application's scope.

Amounts must be whole numbers, at most 2,147,483,647. Invalid division/overflow
leaves the draft unchanged. There are at most 512 native entries per side;
patterns with sparse native layouts may reach the native index limit sooner.
The application preserves their real indices when modifying them.

## Review and Apply

Draft changes are local Lua data; no pattern is moved until you click **Apply**
on Preview. Scroll or use Page Up/Down to inspect a long preview. The comparison
is by row, so deleting a row can also show subsequent rows shifting up.

Stop crafting jobs using the affected recipe before applying. The editor does
not query/cancel every CPU automatically and cannot change ingredients already
dispatched to machines. It cannot guarantee behavior if another player edits,
moves or replaces the pattern during the transaction.

Apply checks the original fingerprint against a fresh read and refuses stale
changes. It then journals the original/draft, moves the physical pattern to the
editing slot, writes only changed entries, reads back each step and returns the
pattern to its exact original slot. A fresh read verifies the returned contents.
The original slot must remain empty until return. Other pattern metadata is not
rewritten by the editing callbacks.

If interrupted, read [Recovery](RECOVERY.md). A logical recovery journal is not
a duplicate encoded pattern item and cannot create a missing physical pattern.

## Keyboard, mouse and screen size

- Click a text field to focus it. Ordinary number keys and numpad produce one
  character per key-down event. Backspace and Delete remove characters.
- Ctrl+A selects all; typing/pasting replaces the selection. Left/Right and
  Home/End move the cursor. Tab cycles enabled buttons and text fields; the
  selected button is highlighted, and Enter activates it.
- Enter commits an amount or leaves Search; a second Enter opens/selects the
  highlighted result. Esc first leaves a focused field, then goes back. On the
  main screen Esc or Q quits. Ctrl+C, Ctrl+D and OpenOS interrupt quit from any
  screen, restoring the previous GPU resolution.
- Delete removes an ingredient only while the ingredient list has focus.
- Arrow keys, Page Up/Down and mouse wheel navigate lists. Click buttons or
  select them with Tab/Enter to switch sides, preview or apply. Long lists are
  paginated.

At 50x16, labels/status lines may be truncated; the picker shows registry/NBT
details as space allows. A higher-tier screen/GPU makes these easier to inspect.
The app does not change Minecraft NEI search or process Minecraft key events.
