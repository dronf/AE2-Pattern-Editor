# Installation

[Overview](../README.md) - [Usage](USAGE.md) - [Recovery](RECOVERY.md)

## Hardware and connections

Use an ordinary powered OC computer running OpenOS, with a hard drive, keyboard,
GPU/screen, and enough RAM for OpenOS plus the interface-pattern snapshot.
The application requires at least 50x16 resolution and uses the GPU/screen's
maximum available resolution while running, restoring the previous one on exit.
Higher resolution is useful for long labels; large networks require more RAM.
The CPU tier does not add memory. Install the largest RAM modules your case
supports before scanning a large AE network. No exact RAM minimum has been
established across all network sizes.

Connect these two paths to the computer's **OC network**:

1. **Terminal access:** an OC Adapter touching the cable block holding a normal
   ME Interface Terminal. This exposes `me_interface_terminal` and lets the
   program enumerate and move patterns through that terminal's AE network.
2. **Editing access:** another OC Adapter touching a **normal full-block ME
   Interface**. This exposes `me_interface` and the local pattern-edit callbacks.
   Connect this interface to the same main AE network as the terminal.

Rename the editing interface **Pattern Editor** using your usual AE naming
method so it is easy to identify in Setup. Keep it dedicated: no machines on
its other faces, no stocking requests, and no manually stored patterns. The
application reserves its first pattern slot (displayed as slot 1).

Two adapters can share the computer's OC cable network. They do not require two
computers. Both AE devices need normal power/channels and terminal visibility.
Load the source and editing-interface chunks during transactions.

Keep P2P **sources** visible in the AE Interface Terminal. P2P outputs do not
need separate pattern copies and are excluded from enumeration. Interfaces on
separate AE subnets and patterns sitting in chests/storage cells are outside
this terminal's view.

## NBT access

The exact pattern snapshot and renamed item identities require
`allowItemStackNBTTags=true` in OpenComputers configuration. This is enabled in
the GTNH 2.9 RC2 instance used for compatibility checks. If the server disables
it, the editor can browse, but Apply refuses to write an opaque pattern; tagged
ingredients may also prevent preview. A client Lua script cannot override a
server's OC setting. No new server mod is required.

Tagged fluids remain read-only even with this setting enabled: the OC fluid
parser does not preserve their NBT. Ordinary GTNH gases/fluids without tags are
supported, including their mB quantities.

## Install the built application

An Internet Card is needed for this download, not normal use:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.6/installer.lua ape-install.lua
ape-install
```

The installer fetches the pinned v1.0.6 release application, verifies it, then
installs `/home/pattern_editor.lua`. The previous file is retained as
`pattern_editor.lua.previous`. Run `pattern_editor --demo` to inspect the UI
without accessing real AE components. Demo data lives separately.

If an older version crashes with `getRunningProgram` nil or
`Index 51 out of bounds for length 51`, or the demo cannot select Quit with
the keyboard, reinstall using the v1.0.6 command above. Run
`pattern_editor --demo` first, then `pattern_editor` for
real Setup. An Adapter beside the Interface Terminal's cable does not make a
visible AE cable join; check detection at the OpenOS `lua>` prompt with the
single expression `=require("component").isAvailable("me_interface_terminal")`.
If v1.0.3 showed `No terminal-visible full-block interface` despite an
interface on the same AE grid, update to v1.0.4. OpenComputers reports a
full-block interface's side as `UNKNOWN`, which older versions rejected.
If v1.0.4 instead stops with `not enough memory` during Scan, update to
v1.0.5 and install more OC RAM if needed. The scan now retains only a compact
search index; opening a result reads that pattern's full data on demand.
If v1.0.5 stopped after moving a pattern with an adapter mismatch error, use
**Restore original** before updating. v1.0.6 excludes part-interface adapters
from Setup and checks the terminal and adapter views of the destination.

For offline installation, download and extract the release's OC ZIP on your
PC, then copy `pattern_editor.lua` onto the OC hard drive using your available
disk/filesystem transfer method. Do not paste the whole application through
the OC clipboard: it is larger than the paste limit. No Python, Java compiler,
or source directory is needed on the OC computer.

## First real setup

1. Run `pattern_editor` and select **Setup**.
2. If more than one terminal/editor component is available, select the correct
   component address. With one of each, those selections are automatic. The
   editor filters out interface-part components; its adapter must touch a
   full-block ME Interface.
3. Select **Pattern Editor** from the terminal's full-block interface list.
   Verify its displayed coordinates against the physical interface touching
   the editing adapter. It must be the same interface, not another empty one.
   If it is still absent after updating, check that the ME Interface itself
   has a channel on the terminal's AE grid. The OC adapter connection alone
   does not make it visible to the AE Interface Terminal.
4. Select **Scan**, then test on a disposable processing pattern first.
5. Open a result, make a draft change, Preview, and Apply. Check the original
   interface to confirm the pattern returned and the editing slot is empty.

Setup checks both slots are empty. After the first transfer it also compares
the remote and adapter-visible pattern before writing. A mismatch retains the
journal and offers Restore original; it does not blindly edit another interface.

## Updates and removal

Finish/recover any pending transaction before replacing the application.
Download and run the installer from the desired release, just as above.
User data is preserved in `/home/.ae2-pattern-editor`; the application never
edits Level Maintainer files. Demo uses `/home/.ae2-pattern-editor-demo`.

To stop using it, exit the application. Resolve any pending transaction before
removing its files or the editing hardware. Keep the data directory and original
pattern snapshot if you need an audit record.
