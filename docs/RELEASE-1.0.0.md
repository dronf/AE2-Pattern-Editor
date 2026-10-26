# AE2 Pattern Editor 1.0.0

Find AE2 processing patterns by input/output name, edit quantities and identities,
add/remove ingredients, and scale recipes with x2 or exact /2. Preview changes
before the application moves the pattern through its editing station and returns
it to its original interface slot.

This is a self-contained **OpenComputers/OpenOS Lua application**, not a Minecraft
JAR. It requires no new server mod or external service. Download
`pattern_editor.lua` or the `-oc.zip` bundle, or use the pinned installer below.

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.0/installer.lua ape-install.lua
ape-install
pattern_editor --demo
```

For real use, connect OC Adapters to an ME Interface Terminal and a dedicated
normal full-block ME Interface on the same AE network. Run `pattern_editor`,
select Setup, select the editing interface by name/coordinates, and Scan.
[Full installation guide](https://github.com/dronf/AE2-Pattern-Editor/blob/v1.0.0/docs/INSTALLATION.md).

Validation: real Lua modules and the built bundle pass automated UI, transaction,
persistence and interruption/recovery tests under Lua 5.2/5.3. Required APIs were
inspected in installed OpenComputers 1.12.64-GTNH and AE2 rv3-beta-1080-GTNH JARs
from GTNH 2.9 RC2. The pinned installer is exercised against successful, damaged,
truncated and failed-install downloads. Release checksums are attached.

**Initial prerelease: live Minecraft validation has not been performed.** Test
on a disposable processing pattern before production use. Crafting-grid patterns
are read-only; tagged fluids are unsupported. Exact pattern/item NBT requires
OC's `allowItemStackNBTTags=true`, enabled in the checked GTNH installation.
Stop affected crafting jobs before applying changes. Recovery instructions and
the in-game acceptance checklist are included in the repository and offline ZIP.
