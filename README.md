# AE2 Pattern Editor

A mouse-and-keyboard OpenComputers application for finding and editing AE2
processing patterns across a GTNH 2.9 network. Search for an input such as
`Quantium Ingot`, inspect the matching recipes, edit a draft, preview changes,
then apply them through a dedicated editing interface.

**This is an OpenOS Lua application. It needs no new Minecraft JAR, server mod,
browser, or external service.** An Internet Card is needed only for downloading
the installer/application. It runs independently of Level Maintainer.

## Download and install

[Release v1.0.0](https://github.com/dronf/AE2-Pattern-Editor/releases/tag/v1.0.0)
contains the built, self-contained `pattern_editor.lua`, a verified installer,
and an offline OC ZIP. On your OpenOS computer:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.0/installer.lua ape-install.lua
ape-install
pattern_editor --demo
```

Exit the disconnected demo, connect the hardware described in
[Installation](docs/INSTALLATION.md), then run `pattern_editor` and **Setup**.
The installer downloads one pinned application, verifies its length/checksum
and Lua syntax, keeps the previous application, and preserves settings/journal.
Do not update the application during a pending pattern transaction.

## Features

- Scan terminal-visible interfaces, including interface P2P sources; search
  cached inputs, outputs or both by label or registry ID.
- Edit amounts, replace identities, add ingredients and remove ingredients on
  either side. The last input/output cannot be removed.
- **x2 / /2** scale consumed inputs and outputs together. Division requires
  whole quantities; zero-quantity catalysts remain zero.
- Preview before Apply. Draft changes do not move or modify the live pattern.
- Move the physical pattern into a normal adapter-connected interface, modify
  it, verify it, and return it to the original interface and slot.
- Persist an original snapshot and a write-ahead recovery journal. Interrupted
  saves lock other edits until **Finish** or **Restore original** succeeds.
- Mouse, arrow/page keys, scrolling, clipboard paste, ordinary number keys,
  numpad, Backspace/Delete, Ctrl+A and Tab. Layouts work at 50x16 and larger.
- Manual scans and catalog refreshes; no background network polling.

## Requirements and limits

API/bytecode compatibility checked with **OpenComputers 1.12.64-GTNH** and
**AE2 rv3-beta-1080-GTNH** from GTNH 2.9 RC2. A normal ME Interface and an ME
Interface Terminal each need an adjacent OC Adapter connected to the computer.
The editing interface must be on the same AE network as the source patterns.

**Initial release: automated integration, UI, recovery and installed-JAR API
checks passed; a live Minecraft session has not been tested.** Start with a
disposable processing pattern and follow the [in-game checklist](docs/VERIFICATION.md).

Crafting-grid patterns are viewable but read-only. Normal item and untagged
fluid processing ingredients are editable. Item NBT must be exposed by OC
(`allowItemStackNBTTags=true`) to preserve exact patterns and renamed items.
The supplied GTNH instance has this enabled. Tagged fluids and other stack
types are not writable in this version. Counts are limited to 2,147,483,647.

This edits AE instructions, not GregTech recipes: adding an impossible output
or removing an ingredient required by a machine will not make that machine
perform the modified recipe. Stop affected AE jobs before applying changes;
the application does not cancel jobs automatically.

| Guide | Contents |
| --- | --- |
| [Installation](docs/INSTALLATION.md) | Physical connections, Setup, updates and offline installation |
| [Usage](docs/USAGE.md) | Search, add/remove/replace, quantities, multipliers and controls |
| [Recovery](docs/RECOVERY.md) | Interrupted writes, occupied slots, missing chunks and journal files |
| [Verification](docs/VERIFICATION.md) | Automated coverage, actual dependency checks and in-game checklist |
| [Development](docs/DEVELOPMENT.md) | Source, test/build commands and API contracts |

## Build from source

```sh
python -m pip install lupa==2.6
python tools/test.py
python tools/build.py
python tools/check_release.py
```

The release application is `dist/pattern_editor.lua`. Source modules are bundled
using `package.preload`; OpenComputers needs only that single application file.
Source and offline-installation ZIPs plus SHA-256 checksums are produced alongside
it. See [Development](docs/DEVELOPMENT.md) for installed-JAR verification.

MIT licensed. This project uses the APIs supplied by GTNH's OpenComputers/AE2
forks and does not include their implementation code.
