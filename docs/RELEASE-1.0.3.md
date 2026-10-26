# AE2 Pattern Editor 1.0.3

Fix missing keyboard navigation and exit controls reported after the demo
started in v1.0.2. Tab cycles enabled buttons and fields; Enter activates the
highlighted button. Escape or Q exits from the main screen. Ctrl+C, Ctrl+D and
OpenOS's `interrupted` event exit from any screen and restore the GPU. The
release tests include keyboard-only demo operation under Lua 5.2 and 5.3.

On the OC computer, finish or recover any pending pattern transaction, then:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.3/installer.lua ape-install.lua
ape-install
pattern_editor --demo
```

In the demo, press Tab once to select Scan, then Enter. Press Tab repeatedly
to reach Help, Quit and other buttons; the selected button is highlighted.
After checking the demo, exit and run `pattern_editor` for real Setup. The
installer retains settings and the previous application as
`pattern_editor.lua.previous`. No pattern-editing result has yet been verified
in a live Minecraft session; use a disposable processing pattern first.
