-- Priority Rotation (DaylightUI Plugin) / Sounds.lua
-- Mute Sounds: chosen game sounds stay silent. Carried over from VeritasUI's Interface module (v1.84.0).
-- These are engine sounds, not interface ones. The game's MuteSoundFile / UnmuteSoundFile mute a sound file by its
-- ID until the client closes (warcraft.wiki.gg API MuteSoundFile, "forever 1.60.1"), so every chosen group is
-- muted at each login, and a change applies at once. A group is only unmuted when it is switched off after this
-- addon muted it, so a sound another AddOn muted is never unmuted here. A file the game does not have is a
-- harmless no-op. File IDs and their sources (2026-11-08) are in VeritasUI's Interface.lua beside the same list.
-- ⚠ That each group is exactly what a player hears is UNMEASURED: no Lua event reports a sound playing.
-- DaylightUI mutes only interface sounds it replaces with its own (DaylightUI/Sound.lua Sound.REPLACE), none of
-- these; but its alert sounds can be the Ready Check file (Sound.ALERT_PUNCHY, 567409), which this group silences.

local _, PR = ...
local VUI = PR.VUI
if not VUI then return end

local SOUND_GROUPS = {
    { id = "fizzle", label = "Spell Fizzle", tip = "The fizzle a spell makes when it fails to cast. The red error "
        .. "message still shows unless its group is hidden on the Error Messages page.",
      files = { 569772, 569773, 569774, 569775, 569776 } },
    { id = "chimes", label = "Clock Chimes", tip = "The bells and horns that ring the hour in cities.",
      files = { 565853, 566027, 566064, 566254, 566558, 566564 } },
    { id = "ready", label = "Ready Check", tip = "The ready check sound. The game plays the same sound for role "
        .. "checks and when a dungeon or battleground queue is ready, so those are silent too, and so is a "
        .. "DaylightUI alert set to the Ready check sound.",
      files = { 567409, 567478 } },
    { id = "trains", label = "Trains", tip = "The train whistle of the /train emote, every race.",
      files = { 539203, 539219, 539516, 539730, 539802, 539881, 540271, 540275, 540535, 540734, 540870, 540947,
        541157, 541239, 541463, 541601, 541769, 542017, 542035, 542206, 542526, 542600, 542818, 542896, 543085,
        543093, 630296, 630298, 636621, 1304872, 1306531, 1313588, 1316209, 1730534, 1730908, 1731282, 1731656,
        1732030, 1732405, 1732785, 1733163, 1902030, 1902543, 1903049, 1903522, 1951457, 1951458, 2491898,
        2531204, 3106252, 3106717, 3107182, 3107651, 4737561, 4738601, 4739531, 4741007, 6021052, 6021067,
        7652669, 7652671, 7652673, 7652679, 7652681, 7652995, 7652997, 7681676, 7681678, 7681680, 7744513,
        7744921 } },
    { id = "vault", label = "Guild Vault", tip = "The idle clanking of the mechanical guild vaults, such as the ones "
        .. "in Booty Bay and Winterspring.",
      files = { 566289 } },
    { id = "airships", label = "Airships and Zeppelins", tip = "Engines, propellers and horns of airships and "
        .. "zeppelins, the mounts and the ones you travel on.",
      files = { 565623, 566258, 566604, 566719, 567042, 603149, 603224, 652796, 1659491, 1659492, 1659493,
        1659494, 1659495, 1659496, 1659497, 1659498, 1659499, 1659500, 1659501, 1659502, 1659503, 1659504,
        1659505, 1659506, 1659507, 1659508, 1659509, 1659510, 1659511, 1659512, 1659513, 1659514, 1659515,
        1659516, 1659517, 1659518, 1659519, 1659520, 1659521, 1659522, 1659523, 1659524, 1659525, 1659526,
        1659527, 1659528, 1659529, 1659530, 1685499, 1686533, 1686534, 1686535, 1686536, 1686537, 1686538,
        1686539, 1686540, 1686541 } },
    { id = "steps", label = "Mount Footsteps", tip = "Footsteps of horse mounts and of mechanical mounts.",
      files = { 550500, 550501, 550507, 550514, 552058, 552060, 552062, 552063, 552065, 552066, 552068, 552070,
        552071, 552072, 552073, 552075, 552076, 552077, 552078, 552079, 552081, 552082, 552083, 552084, 552085,
        552086, 552087, 552089, 552090, 893935, 893937, 893939, 893941, 893943, 893945, 893947, 893949 } },
    { id = "striders", label = "Mechanostriders", tip = "The whirring and clanking of mechanostrider mounts.",
      files = { 555123, 555124, 555125, 555126, 555127, 555128, 555129, 555130, 555131, 555132, 555133 } },
    { id = "yawns", label = "Cat Yawns", tip = "The yawn of big cats, hunter pets included.",
      files = { 562388 } },
}
PR.SOUND_GROUPS = SOUND_GROUPS

-- The option key of a group: "muteSound_fizzle" and so on.
function PR.SoundKey(g) return "muteSound_" .. g.id end

local muted = {}   -- [group id] = true once this session muted it
-- Mutes the groups `get` says are on, unmutes the ones this session muted that are now off.
function PR.ApplySoundMutes(get)
    local mute, unmute = _G.MuteSoundFile, _G.UnmuteSoundFile
    if type(mute) ~= "function" or type(unmute) ~= "function" then return end
    for _, g in ipairs(SOUND_GROUPS) do
        local on = get(PR.SoundKey(g)) == true
        if on and not muted[g.id] then
            for _, id in ipairs(g.files) do pcall(mute, id) end
            muted[g.id] = true
        elseif not on and muted[g.id] then
            for _, id in ipairs(g.files) do pcall(unmute, id) end
            muted[g.id] = nil
        end
    end
end
