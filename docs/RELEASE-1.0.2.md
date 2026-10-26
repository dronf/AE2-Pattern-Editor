# AE2 Pattern Editor 1.0.2

Fix the `Index 51 out of bounds for length 51` crash reported while drawing
the demo title on a 50-column OpenComputers screen. Text is now clipped by
measured display width without calling OpenOS `unicode.wtrunc`. Lua 5.2 and
5.3 tests cover the 50-column title and run the bundled application without
the unsupported `shell.getRunningProgram` call from v1.0.0.

On the OC computer, finish or recover any pending pattern transaction, then:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.2/installer.lua ape-install.lua
ape-install
pattern_editor --demo
```

After checking the demo, exit and run `pattern_editor` for real Setup. The
installer retains settings and the previous application as
`pattern_editor.lua.previous`. No pattern-editing result has yet been verified
in a live Minecraft session; use a disposable processing pattern first.
