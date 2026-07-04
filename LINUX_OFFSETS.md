# memedit on native Linux — offset table regeneration

memedit reads and writes game-object fields by raw byte offset into the game's
C++ structs. Those offsets are ABI-specific, so the native Linux build needs its
own offset table, `__addresses_linux.lua` (the Windows table is `__addresses.lua`).
`memedit.lua` selects the file per platform via the loader's `Platform` module.

## How offsets are derived (the scanner is the mechanism)

memedit does **not** hardcode offsets from a binary tool. It ships a runtime
**scanner** (`scanner/*.lua`) that derives every offset live: it takes a known
game object, changes one field through the game's own API, scans the object's
bytes for the value that changed, and records that byte offset. This is memedit's
normal calibration path on every platform and game version — the `__addresses*.lua`
files are just cached scanner output.

The native Linux memedit C library (`memedit.so`) needs no memory-API port: it
reads via in-process pointer dereference (`*(T*)(base + offset)`), identical on
Windows and Linux. Its only Windows-specific code (`windows.h`, `DllMain`) is
compiled out on Linux.

## Regenerating `__addresses_linux.lua`

1. Install the loader on the native Linux game (`install.sh`) and launch with the
   preload (`LD_PRELOAD=./libitbboot.so ./Breach`).
2. Enable the `memedit` extension (it depends on `mod_loader_extensions`, so
   enable that too) in Mod Configuration.
3. memedit boots uncalibrated (this table ships empty) and prompts for
   calibration. **Start a game and enter a mission** — most scans require a live
   board and pawns (`boardExists` / `missionBoardExists`).
4. Run the calibration (memedit's Calibrate UI). The scanner walks its scandefs,
   spawning and manipulating its own test pawns, and writes the derived offsets
   back to `__addresses_linux.lua` for the current game version.
5. On the next load memedit reports "Initialized successfully" and reads/writes
   fields correctly (AC4.2).

Calibration is per game version: a new game version needs one recalibration.

## Shortcut worth trying first

The Windows `__addresses.lua` already contains a `1.2.93` bucket — the same game
version as the current native Linux build. Many of these POD-struct offsets may
match across the two ABIs. Before a full calibration you can test whether the
Windows `1.2.93` offsets happen to be correct on Linux by reading one known field
(e.g. a pawn's `MaxHealth`) and checking the value. **Do not** ship the Windows
offsets copied in as calibrated without validating them in-game — a wrong offset
reads or writes arbitrary process memory.

## Note on the static derivation tool

An offset-derivation tool exists under `tools/derive_offsets/` (luabind
`def_readwrite` harvesting + symbol anchors). It can only recover the ~22 fields
the binary exposes through luabind — not the priority Pawn/Board/Tile/Weapon
fields, which are not luabind-exposed. The runtime scanner above supersedes it for
full-table derivation; the static tool remains only as a cross-check for the
luabind-exposed subset.
