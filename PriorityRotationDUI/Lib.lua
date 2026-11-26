-- Priority Rotation (DaylightUI Plugin) / Lib.lua
-- The helpers Priority Rotation used from VeritasUI_Lib, carried over as this addon's own (ns.VUI), so the ported
-- files read the same as in VeritasUI. Only what Priority Rotation calls; Forever only.

local ADDON, ns = ...
if not ns.API then return end   -- Core.lua stopped: DaylightUI's API is missing or another major

local VUI = {}
ns.VUI = VUI

local format, ipairs, pcall, type = string.format, ipairs, pcall, type

VUI.VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
VUI.IS_FOREVER = true   -- DaylightUI is Forever only (its TOC: Interface 16001), and so is this plugin
VUI.debug = false

-- Blizzard's named colours as |c codes (WrapTextInColorCode, as Blizzard uses it). The fallbacks are those
-- constants' values, used only if one is missing.
local function ColorCode(c, fallback)
    if type(c) == "table" and c.WrapTextInColorCode then
        local ok, s = pcall(c.WrapTextInColorCode, c, "")
        if ok and type(s) == "string" and #s >= 10 then return s:sub(1, 10) end
    end
    return fallback
end
VUI.COL = {
    NORMAL     = ColorCode(_G.NORMAL_FONT_COLOR,     "|cffffd100"),
    HIGHLIGHT  = ColorCode(_G.HIGHLIGHT_FONT_COLOR,  "|cffffffff"),
    YELLOW     = ColorCode(_G.YELLOW_FONT_COLOR,     "|cffffff00"),
    RED        = ColorCode(_G.RED_FONT_COLOR,        "|cffff2020"),
    GREEN      = ColorCode(_G.GREEN_FONT_COLOR,      "|cff20ff20"),
    GRAY       = ColorCode(_G.GRAY_FONT_COLOR,       "|cff808080"),
    DISABLED   = ColorCode(_G.DISABLED_FONT_COLOR,   "|cff7f7f7f"),
    ORANGE     = ColorCode(_G.ORANGE_FONT_COLOR,     "|cffff7f3f"),
    LIGHTBLUE  = ColorCode(_G.LIGHTBLUE_FONT_COLOR,  "|cff8080ff"),
    BRIGHTBLUE = ColorCode(_G.BRIGHTBLUE_FONT_COLOR, "|cff3399ff"),
}

function VUI.Print(tag, msg)
    print(format(VUI.COL.BRIGHTBLUE .. "[%s]|r %s", tag, msg))
end

----------------------------------------------------------------
--  CombatQueue  -- deferred actions run on PLAYER_REGEN_ENABLED
----------------------------------------------------------------
VUI.CombatQueue = {}
local queue = {}

function VUI.CombatQueue.Add(fn)
    if not InCombatLockdown() then
        fn()
    else
        queue[#queue + 1] = fn
    end
end

local cqFrame = CreateFrame("Frame")
cqFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
cqFrame:SetScript("OnEvent", function()
    local pending = queue
    queue = {}
    for _, fn in ipairs(pending) do
        -- One bad action must not strand the rest; errors show only with VUI.debug on.
        local ok, err = pcall(fn)
        if not ok and VUI.debug then
            print(VUI.COL.RED .. "[Priority Rotation]|r CombatQueue error: " .. tostring(err))
        end
    end
end)

----------------------------------------------------------------
--  The window: Blizzard's UI panel manager and its sounds
----------------------------------------------------------------

function VUI.RegisterManagedPanel(frameName, opts)
    if type(frameName) ~= "string" then return end
    opts = opts or {}
    UIPanelWindows[frameName] = {
        area      = opts.area      or "left",
        pushable  = opts.pushable  or 1,
        whileDead = opts.whileDead or 1,
        extraWidth = opts.extraWidth,
    }
    for _, n in ipairs(UISpecialFrames) do
        if n == frameName then return end
    end
    table.insert(UISpecialFrames, frameName)
end

function VUI.OpenManagedPanel(frame)
    if not frame then return end
    if InCombatLockdown() then
        VUI.CombatQueue.Add(function() pcall(ShowUIPanel, frame) end)
    else
        pcall(ShowUIPanel, frame)
    end
end

-- In combat Blizzard refuses HideUIPanel from addon code (UIParentPanelManager.lua:844-848), so the window is
-- simply hidden; the manager frees the slot on its next ShowUIPanel (RepairUIPanelState).
function VUI.CloseManagedPanel(frame)
    if not frame then return end
    if InCombatLockdown() then
        if not (frame.IsProtected and frame:IsProtected()) then frame:Hide() end
    else
        pcall(HideUIPanel, frame)
    end
end

-- Blizzard's open and close sounds, as its own windows play them from OnShow / OnHide. Call it AFTER the
-- window's own SetScript("OnShow"/"OnHide"): SetScript replaces any hook made before it.
function VUI.AddWindowSounds(frame, openKit, closeKit)
    if not (frame and frame.HookScript and PlaySound and openKit and closeKit) then return end
    frame:HookScript("OnShow", function() PlaySound(openKit) end)
    frame:HookScript("OnHide", function() PlaySound(closeKit) end)
end

----------------------------------------------------------------
--  Who the player is
----------------------------------------------------------------
-- Forever leaves GetRealmName() blank; UnitFullName("player") still has the realm (measured 2026-11-24).
function VUI.RealmName()
    local ok, realm = pcall(GetRealmName)
    if ok and type(realm) == "string" and realm ~= "" then return realm end
    local okF, _, fullRealm = pcall(UnitFullName, "player")
    if okF and type(fullRealm) == "string" and fullRealm ~= "" then return fullRealm end
    return nil
end

-- VeritasUI moved lists saved under Forever's old realm names to the new ones (v1.89.5). This addon starts after
-- that, with lists already under the new names, so there is nothing to move.
function VUI.AdoptOldCharEntry() return false end
