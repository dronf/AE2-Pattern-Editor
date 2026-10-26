# AE2 Pattern Editor 1.0.1

v1.0.0 crashed immediately on GTNH OpenOS with
`attempt to call a nil value (field 'getRunningProgram')`. This release removes
the unsupported call. The bundled application's normal, demo and help startup
paths now pass regression tests under Lua 5.2 and 5.3 without a shell mock.

On the OC computer, finish or recover any pending pattern transaction, then:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.1/installer.lua ape-install.lua
ape-install
pattern_editor --demo
```

After checking the demo, exit and run `pattern_editor` for real Setup. The
installer retains settings and the previous application as
`pattern_editor.lua.previous`. No pattern-editing result has yet been verified
in a live Minecraft session; use a disposable processing pattern first.
