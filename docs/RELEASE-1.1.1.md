# AE2 Pattern Editor 1.1.1

Fix Apply stopping when the Interface Terminal and editing Adapter report the
same recipe with different encoded-pattern metadata. Before any ingredient is
written, Apply now transfers the pattern back to its source, confirms the
Adapter slot becomes empty, returns the pattern to the editing interface, and
confirms it reappears. An Adapter attached to a different interface still
causes a safe stop, even if that interface holds an identical pattern. The
additional transfers are journaled for Finish/Restore recovery. Apply also
verifies the final recipe through the terminal before returning the pattern.

**Use Back > Restore original in v1.1.0 before updating if an Apply transaction
is pending.** Then on the OpenOS computer:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.1.1/installer.lua ape-install.lua
ape-install
pattern_editor
```

Automated Lua 5.2/5.3 and release checks cover metadata disagreement, a wrong
Adapter and interrupted transfers. This update has not yet been verified in
Minecraft. Test Preview > Apply on a disposable processing pattern first and
confirm the changed pattern returns to its original interface and slot.
