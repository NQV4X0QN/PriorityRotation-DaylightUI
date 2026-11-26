-- Priority Rotation (DaylightUI Plugin) / Plugin.lua
-- Registers the plugin with DaylightUI through its public API (DaylightUI/API.md: "A plugin of your own"). Nothing
-- here touches DaylightUI's internals. DaylightUI prints one line in chat when its API is too old for `needs`.
--
-- VeritasUI's own Priority Rotation is the same rotation under the same macro, button and /pr: with it on, this
-- plugin stays off (one chat line), after copying its spell lists here once if this plugin has none yet. The TOC
-- lists it in OptionalDeps so it has loaded, saved data included, before this file runs.

local ADDON, ns = ...

local DUI = _G.DaylightUI
local API = DUI and DUI.API
if type(API) ~= "table" or API.major ~= 1 then return end

local VERITAS_PR = "VeritasUI_PriorityRotation"
local function Loaded(name)
    local f = C_AddOns and C_AddOns.IsAddOnLoaded
    if not f then return false end
    local ok, yes = pcall(f, name)
    return ok and yes and true or false
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

local function HasLists(db)
    if type(db) ~= "table" or type(db.profiles) ~= "table" then return false end
    for _, p in pairs(db.profiles) do
        if type(p) == "table" and type(p.spells) == "table" and #p.spells > 0 then return true end
    end
    return false
end
ns.HasLists = HasLists

-- Copies VeritasUI's Priority Rotation data into this plugin's when this plugin has no spell lists yet. Returns
-- true when it copied.
function ns.ImportFromVeritasUI(from)
    if not HasLists(from) or HasLists(_G.DaylightPriorityRotationDB) then return false end
    _G.DaylightPriorityRotationDB = DeepCopy(from)
    return true
end

if Loaded(VERITAS_PR) then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name ~= ADDON then return end
        self:UnregisterAllEvents()
        local copied = ns.ImportFromVeritasUI(_G.VeritasUI_PriorityRotationDB)
        print("|cff3399ff[Priority Rotation]|r VeritasUI's Priority Rotation is on, so this plugin stays off."
            .. (copied and " Your spell lists were copied over." or "")
            .. " Turn off VeritasUI - Priority Rotation in the AddOns list and /reload to use the plugin.")
    end)
    return
end

ns.API = API
ns.me = API.For(ADDON)
ns.MODULE = ADDON
ns.NEEDS = { 1, 3 }   -- options pages, settings, SettingChanged, RegisterSkin (API.md "The promise")

DUI:RegisterPlugin(ADDON, {
    needs = ns.NEEDS,
    short = "Rotation",
    color = "7fb2ff",
    blurb = "A one-button rotation from a spell list you build.",
})
