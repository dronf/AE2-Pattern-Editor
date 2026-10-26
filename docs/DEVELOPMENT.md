# Development

[Overview](../README.md) - [Verification](VERIFICATION.md)

## Modules

| File | Responsibility |
| --- | --- |
| src/ape/model.lua | Normalized identities, compact search index, native layout, validation and draft transforms |
| src/ape/api.lua | OC callbacks, terminal enumeration/transfers, local editing and item catalog |
| src/ape/transaction.lua | Fingerprint checks, write-ahead mutations and physical-inventory recovery |
| src/ape/store.lua | Checksummed persistence with temporary/backup generations |
| src/ape/codec.lua | Deterministic, binary-safe serialization without eval/load |
| src/ape/ui.lua | Drawing, field editing, key events, hit testing and paging |
| src/ape/app.lua | Setup, search/editor/picker/preview/recovery application screens |
| src/ape/demo.lua | Disconnected AE/OC fixture for demo and regression tests |

Source `main.lua` uses OpenOS's `_` environment value to add src to the module
path. The build registers each module in package.preload and appends main.lua;
the bundled application therefore does not need path discovery at startup.
The demo is bundled but only selected with --demo; it does not access real AE
components. OpenOS component/screen access is still needed to display the demo.

## Test and build

Use Python 3.12+ and `pip install lupa==2.6`:

```sh
python tools/test.py
python tools/build.py
python tools/check_release.py
```

`tools/test.py --deps /path/to/python-deps` supports a workspace-only dependency
directory. The tests use independent Lua 5.2 and Lua 5.3 runtimes. CI executes
the same tests/build and checks that the generated pinned installer is current.
The build emits the application, installer, OC/source ZIPs and SHA256SUMS.txt.

For a dependency audit with JDK 17's javap:

```sh
python tools/verify_api.py --mods /path/to/instance/mods --output docs/api-verification.json
```

## API contracts that must remain tested

- Terminal `getInterfaces()` and `getInterfacesByLocation()` return callable
  iterator values. Their pattern map keys and transfer slots are **zero-based**.
- Terminal interface `side` may arrive as a ForgeDirection string (`UNKNOWN`
  for a full block, `NORTH` etc. for a part); normalize to the corresponding
  numeric side 0-6 before Setup filtering, comparisons or transfer calls.
- The persistent Scan result contains only titles and searchable label/ID
  strings. Read and normalize the selected full pattern when Open is pressed;
  do not retain every pattern's binary NBT in the scan cache. Catalog identities
  are read on demand when Add/Replace opens.
- Local `getInterfacePattern`, setters, and ingredient indices are **one-based**.
- Both part and full-block ME Interfaces expose `me_interface` and pattern
  callbacks. A part requires a side before the slot; Setup must select only a
  full-block editor. The optional-slot callback on a block accepts no arguments.
- Terminal `send(source,target)` moves a physical encoded pattern. It refuses
  an occupied destination. The source/target include location, side and slot.
  A target slot of `-1` asks the terminal to choose its first free slot and
  return that zero-based slot. Move journals the destination occupancy before
  calling `send`, so a crash before the returned slot is recorded is recoverable.
- Ingredient setters accept `(patternSlot,index,detail,type)`, where type is
  `item` or `fluid`. `detail.size` supplies the AE amount; native fluids also need
  `detail.amount`. Omitting detail removes an entry and **shifts native indices**.
- PatternConverter exposes inputs/outputs and `isCraftable`, meaning the
  **crafting-grid flag** in this context, not general network craftability.
- Item `tag` is compressed binary NBT when exposed by OC configuration. Never
  reconstruct renamed items from display labels, discard tags, or log them as text.
- Fluid conversion does not round-trip NBT; tagged fluids are deliberately rejected.
- Recover using actual inventories plus the saved before/after states; a phase
  alone cannot establish whether a callback ran before power loss.
- After moving a pattern, compare the terminal and Adapter recipes, including
  native layout. Their outer encoded-pattern metadata may serialize differently.
  Before writing, transfer the pattern back to its exact source slot and verify
  the Adapter slot clears; transfer it to the station again and verify it
  reappears. Journal each phase for interrupted-transfer recovery. An identical
  recipe in a different Adapter-connected interface must not count as binding.
- After editing, verify the final recipe through both the Adapter and terminal
  before returning the physical pattern to its source slot.

Relevant upstream sources:

- [Terminal driver](https://github.com/GTNewHorizons/OpenComputers/blob/1.12.64-GTNH/src/main/scala/li/cil/oc/integration/appeng/DriverPartInterfaceTerminal.scala)
- [Block-interface driver](https://github.com/GTNewHorizons/OpenComputers/blob/1.12.64-GTNH/src/main/scala/li/cil/oc/integration/appeng/DriverBlockInterface.scala)
- [Pattern editing](https://github.com/GTNewHorizons/OpenComputers/blob/1.12.64-GTNH/src/main/scala/li/cil/oc/integration/appeng/internal/PatternEnvironment.scala)
- [Pattern conversion](https://github.com/GTNewHorizons/OpenComputers/blob/1.12.64-GTNH/src/main/scala/li/cil/oc/integration/appeng/ConverterPattern.scala)
- [Item/NBT conversion](https://github.com/GTNewHorizons/OpenComputers/blob/1.12.64-GTNH/src/main/scala/li/cil/oc/integration/vanilla/ConverterItemStack.scala)

Do not claim an in-game validation unless a live session actually exercised
the installed release. A successful static dependency audit is a separate check.
