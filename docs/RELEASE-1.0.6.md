# AE2 Pattern Editor 1.0.6

Fix a protective stop after moving a pattern into the editing interface.
GTNH exposes both full-block and part interfaces as `me_interface`, but the
part callback needs a side argument. Setup now excludes parts. The post-move
binding check compares the terminal and adapter views of the selected
destination; it still refuses to edit if they differ or if the recipe changed
during transfer. Restore original can return an unchanged pattern even if an
unrelated adapter cannot be read.

**If v1.0.5 has a pending transaction, use Back > Restore original first.**
Keep the interfaces, adapters and journal intact until the original pattern
is back. If recovery fails, stop and retain the journal for diagnosis.

After recovery, update on the OpenOS computer:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.6/installer.lua ape-install.lua
ape-install
pattern_editor
```

Run Setup again and choose the named, full-block editing interface by its
coordinates. First test Apply with a disposable processing pattern. This
release passed automated tests but has not yet been verified in-world.
