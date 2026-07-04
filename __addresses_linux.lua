-- Persistent Data
-- Linux field-offset table for memedit, keyed by game version.
--
-- Offsets are ABI-specific and are NOT the same file as the Windows
-- "__addresses.lua". This table is populated by running memedit's in-game
-- calibration on Linux (Mod Config -> memedit -> Calibrate) while in a mission;
-- the scanner derives each offset by manipulating a known field and locating
-- the byte that changes, then writes the results here. See
-- tools/derive_offsets/README.md for the regeneration procedure.
--
-- Shipped empty so memedit boots uncalibrated and prompts for calibration on
-- Linux rather than reading unvalidated offsets. Do not hand-copy the Windows
-- offsets in as "calibrated" -- wrong offsets read/write arbitrary memory.
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["1.2.93"] = {
	};
}
return obj1
