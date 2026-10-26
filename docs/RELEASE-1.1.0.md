# AE2 Pattern Editor 1.1.0

Open a pattern and click **Move** to relocate it to another terminal-visible
interface. Choose the destination by name and coordinates, then confirm. The
Interface Terminal selects its first empty pattern slot; the editor verifies
and reports that slot. Existing destination patterns are never overwritten.
Move works for crafting-grid patterns too. Apply or discard any unsaved recipe
draft before moving.

An interrupted move has its own recovery journal: **Finish** completes the
relocation, while **Restore original** returns the physical pattern to its
source slot. Keep both interfaces powered and loaded until recovery finishes.

Apply now retries a briefly stale Adapter read and says whether the Adapter
sees an empty slot, a different recipe, or different pattern metadata. A
reported Adapter mismatch remains a protective stop; v1.0.6 did not resolve
every in-world case. Use **Back > Restore original** if one occurs and report
the exact new message. The Move feature uses the Interface Terminal rather
than the editing Adapter.

**Resolve any pending transaction before updating.** Then run on OpenOS:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.1.0/installer.lua ape-install.lua
ape-install
pattern_editor
```

Automated Lua 5.2/5.3 and release checks pass. This version has not yet been
verified in-world; start with a disposable pattern.
