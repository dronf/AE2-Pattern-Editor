# Changelog

## 1.1.0 - 2026-10-26

Add **Move** to the pattern detail screen. It lists other terminal-visible
interfaces, confirms the choice and sends the unchanged physical pattern to
the first free pattern slot. The terminal reports the actual destination slot.
An occupied or full destination is never overwritten. A separate write-ahead
move journal allows Finish or Restore original after interruption, including a
crash between physical transfer and recording its returned slot. Crafting-grid
patterns may be moved without enabling ingredient editing. Unsaved draft edits
must be applied or discarded first.

The protective editing-Adapter comparison now retries a briefly stale read
and reports whether it sees an empty slot, a different recipe or matching
recipe with different pattern metadata. In-world reports show v1.0.6 could
still stop at this check; v1.1.0 retains the stop until binding is established.

## 1.0.6 - 2026-10-26

Address two potential causes of an adapter-mismatch stop. Setup
now excludes AE interface-part OC components, which share `me_interface` with
full blocks but require different callback arguments. After moving a pattern,
the editor compares the terminal and adapter reads of the destination rather
than comparing a post-move read with pre-move outer metadata. The recipe must
still match the original before any editing. Restore original now tolerates an
unrelated adapter read error when the remote pattern is unchanged.

## 1.0.5 - 2026-10-26

Reduce OC memory use during network scans. Cache only a small, NBT-free search
index instead of full copies of every encoded pattern. Read the selected
pattern when it is opened; preserve the fingerprint check before moving or
editing it. Gather pattern ingredient identities on demand for Add/Replace.
This addresses the `not enough memory` report after 355 patterns across 52
interfaces, although large networks may still require more OC RAM.

## 1.0.4 - 2026-10-26

Fix Setup incorrectly reporting that no full-block interface is visible when
OpenComputers returns the interface side as the ForgeDirection string
`UNKNOWN`. Normalize all terminal side names before matching, reading and
moving patterns. Simulate actual terminal direction values in the regression
fixture and exercise first-run Setup through the full UI.

## 1.0.3 - 2026-10-26

Make every enabled screen button reachable by Tab and activatable by Enter,
including Scan, Help and Quit in the disconnected demo. Highlight the selected
button. Escape/Q exits the main screen, and Ctrl+C/Ctrl+D or OpenOS's
`interrupted` event exits cleanly from any screen while restoring the GPU.
Add keyboard-only demo and interrupt regression tests.

## 1.0.2 - 2026-10-26

Fix the OpenOS `Index 51 out of bounds for length 51` crash when drawing the
demo title on a 50-column screen. Clip text by measured display width without
calling `unicode.wtrunc`; keep substring indices within the string. Add a
50-column rendering regression and make the Lua startup/UI tests reject any
future use of `unicode.wtrunc` in this path.

## 1.0.1 - 2026-10-26

Fix the startup crash on actual GTNH OpenOS: the bundled application no longer
calls the nonexistent `shell.getRunningProgram` method. Add regression coverage
that launches the built file in normal and demo modes without that method.
The installer preserves existing settings and recovery data on update.

## 1.0.0 - 2026-10-25

Initial OpenOS application: terminal-wide processing-pattern search, input/output
draft edits, ingredient add/replace/remove, x2 and exact /2 scaling, before/after
preview, staging-interface writes and recovery journal. Includes a disconnected
demo, paginated keyboard/mouse UI, pinned installer, single-file build and tests.

Crafting-grid patterns are read-only. Tagged fluids/other stack types are not
writable. Automated integration/recovery/UI checks and actual JAR API inspection
are included; live Minecraft validation remains to be performed.
