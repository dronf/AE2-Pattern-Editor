# Verification for v1.1.1

[Overview](../README.md) - [Development](DEVELOPMENT.md)

## Scope

This is a built OpenOS Lua application, not a Java mod. Automated tests execute
the real Lua model, API adapter, transaction engine and UI under Lua 5.2 and 5.3.
Actual installed JAR bytecode is inspected separately. **Live Minecraft/OC
launches exposed a v1.0.0 startup crash, a v1.0.1 demo-title rendering crash,
and missing keyboard navigation in v1.0.2. The v1.0.3 in-game Setup then
rejected a visible full-block interface. v1.0.4 reached Scan in-world, where
the 52-interface/355-pattern network ran out of OC memory. v1.0.5 completed
the scan and reached Apply in-world, but stopped after moving a pattern when
the adapter check failed. v1.0.6 still stopped at the same check in-world;
Restore original succeeded. v1.1.0 added a more specific mismatch message and
Move, and then a same-recipe/different-metadata stop was observed in-world.
v1.1.1 adds a physical transfer probe before editing. This new behavior still
needs in-world validation.**
Simulation is not a claim of in-world validation.

## Automated checks

- Binary NBT-safe serialization, deterministic comparisons, checksums and
  rejection of malformed/cyclic data without executing it.
- Case-insensitive input/output search; quantity changes; exact item NBT;
  native fluid mB; add/replace/remove; x2 and /2; odd division/overflow rejection;
  zero catalyst handling; read-only crafting grids and unsupported tagged fluids.
- Native sparse pattern slots, zero-based terminal slots and one-based local
  editor/ingredient indices. Removing a native entry shifts later indices.
- Terminal ForgeDirection strings (`UNKNOWN` for full blocks and direction
  names for parts) normalize to numeric endpoints; Setup lists full-block
  candidates and saves the selected endpoint.
- Scans retain only an NBT-free search index. Opening a result reads its full
  current pattern; edits still verify the source fingerprint before movement.
  The Add/Replace catalog reads visible pattern identities only on demand.
- Stale-source rejection, occupied staging slot, partial edits, unexpected
  station mutation, wrong adapter binding and exact return-slot verification.
- Setup excludes part-interface OC components despite their shared
  `me_interface` type. Post-transfer binding compares the Adapter and terminal
  recipes/layouts and verifies the physical slot transition by transferring
  the original pattern out and back before writing. An unrelated Adapter with
  even an identical pattern does not clear and is rejected. Restore can return
  an untouched pattern even if an unrelated Adapter read errors.
- Move uses the terminal's first-free-slot `send` result, preserves existing
  destination patterns, rejects stale sources and full destinations, and allows
  read-only crafting-grid patterns to be relocated. Before/after interruption
  injection covers the move journal and physical transfer, including a crash
  before the chosen slot is recorded. Finish and Restore each leave one pattern.
- Exhaustive before/after interruption injection at journal saves, movements,
  writes and completion boundaries, including the additional binding probe,
  followed by Finish or Restore recovery.
- Full mouse/keyboard application journeys at 50x16, 80x25 and 160x50: scan,
  select, type amounts, remove, pick/add, multiply/divide, preview, apply, move
  and quit. Move refuses an unsaved draft rather than silently discarding it.
  Render calls are checked against screen bounds, including a 51-character
  demo title at 50 columns without `unicode.wtrunc`. Top-row/numpad keys,
  Backspace/Delete, cursor movement, Ctrl+A, paste and UTF-8 text are exercised.
- Keyboard-only demo startup: Tab selects Scan/Help/Quit, Enter activates the
  selected control, Q/Escape quits, and Ctrl+C/Ctrl+D/OpenOS interruption exits
  cleanly even while a field has focus.
- Journal persistence checks and release/installer checks described by the tests.
- Built entry-point smoke tests for `--help`, normal Setup startup and `--demo`
  under Lua 5.2 and 5.3 without the nonexistent `shell.getRunningProgram` API.

The test runner prints current assertion/fault-injection counts. These are
executed against the source modules; release validation also compiles and
executes the built bundle and its installer under controlled test components.

## Actual dependency inspection

The checked installation is GTNH 2.9 RC2, Minecraft 1.7.10, with:

- OpenComputers-1.12.64-GTNH.jar
- appliedenergistics2-rv3-beta-1080-GTNH.jar

[api-verification.json](api-verification.json) records JAR/class SHA-256 hashes
and required methods inspected by `tools/verify_api.py`. The audit checks the
terminal callbacks, local pattern setters, converter fields, 512-entry native
index boundary and `item`/`fluid` stack type IDs. The upstream integration sources
were also read at tag `1.12.64-GTNH` to verify the transfer/edit contracts.

OC's installed configuration has `allowItemStackNBTTags=true`. No assumptions
are made that another server exposes NBT or supports these GTNH-specific methods.

## In-game acceptance checklist

1. Use a disposable processing pattern first and keep a world/pattern backup.
2. Run `pattern_editor --demo`; check screen, mouse and typing at your resolution.
3. Connect the two adapters, run Setup and verify the editing-interface coordinates.
4. Scan and find the disposable pattern by input and output label.
5. Change a quantity, preview and apply. Confirm its original interface/slot and
   an empty editing slot; inspect the actual encoded recipe in AE.
6. Test Add, Replace and Remove with real stored items; test renamed item variants
   and a normal fluid processing pattern. Confirm all identities and amounts.
7. Test x2 then /2, and rejection of /2 when an amount is odd.
8. Change a pattern outside the program after scanning; Apply must refuse it.
9. Open an unchanged disposable pattern, use Move to choose another interface,
   and confirm the reported slot and source vacancy. Scan again to find it there.
   Repeat with a full destination and confirm no pattern was replaced.
10. With a disposable pattern, interrupt an in-progress save and restart. Verify
   Finish and Restore separately, including an occupied original slot.
11. If Apply stops at the Adapter check, use Back > Restore original, then report
    the exact v1.1.1 message. A correct connection should show the pattern
    leave and return during the binding probe. Keep the original Setup and
    journal until recovery succeeds.
12. Only after these checks, use it for production patterns with affected AE jobs
    stopped. Report API errors with OC/AE2 versions and retained journal files.
