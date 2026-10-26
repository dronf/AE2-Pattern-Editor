# AE2 Pattern Editor 1.0.4

Fix first-run Setup reporting `No terminal-visible full-block interface` even
when one is attached to the AE network. The GTNH OpenComputers terminal reports
full-block interfaces with side `UNKNOWN`; the editor had only accepted numeric
side `6`. This release normalizes direction names for discovery, reads and
transfers and includes a first-run Setup regression test.

On the OpenOS computer, finish or recover any pending pattern transaction,
then run:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.4/installer.lua ape-install.lua
ape-install
pattern_editor
```

Run **Setup** again and select the interface touching the editing OC Adapter.
The installer preserves settings and the prior application. If the interface
is still absent, check its AE channel and that it belongs to the terminal's
AE grid. Live pattern editing has not yet been verified; first use a disposable
processing pattern.
