# AE2 Pattern Editor 1.0.5

Reduce memory use while scanning large AE networks. The v1.0.4 live scan ran
out of OC memory after 355 patterns across 52 interfaces because it retained
every encoded pattern, including NBT. This release keeps a compact search
index and reads full data for one pattern when it is opened. Add/Replace reads
visible pattern identities on demand. Existing source-change checks remain in
place before any pattern is moved or edited.

On the OpenOS computer, finish or recover any pending transaction, then run:

```sh
cd /home
wget -f https://raw.githubusercontent.com/dronf/AE2-Pattern-Editor/v1.0.5/installer.lua ape-install.lua
ape-install
pattern_editor
```

Press Scan again. If OpenComputers still reports `not enough memory`, install
more RAM in the OC computer; the CPU tier does not add RAM. This release has
passed simulated tests but still needs an in-game retest on the reported
network. First test editing with a disposable processing pattern.
