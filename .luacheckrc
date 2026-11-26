-- .luacheckrc -- Priority Rotation (DaylightUI Plugin). Run from the repo root: luacheck PriorityRotationDUI
-- WoW runs a Lua 5.1 base; the game's API is layered on as read_globals, kept to what the code uses so a
-- typo in an API name still surfaces.

std = "lua51"
max_line_length = 120

globals = {
}

read_globals = {
    "DaylightUI",
    "CreateFrame", "UIParent", "C_Timer", "GetTime", "InCombatLockdown",
}

files["tests/"] = { std = "lua51", globals = { "_G" }, allow_defined_top = true }
