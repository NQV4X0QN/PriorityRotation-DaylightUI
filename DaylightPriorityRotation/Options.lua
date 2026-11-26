-- Priority Rotation (DaylightUI Plugin) / Options.lua
-- The plugin's page in DaylightUI's options window (DaylightUI/API.md "Put your settings on a Daylight UI page":
-- RegisterModule `options.pages`, rows toggle / button / text). Its values are saved in the player's DaylightUI
-- profile and read with API.GetSetting(module, key); a change arrives as the SettingChanged event (API.md "Hear
-- when they change": scope, path, value).

local _, PR = ...
local VUI = PR.VUI
if not VUI then return end

local API, MODULE = PR.API, PR.MODULE

PR.defaults = {
    rotationOn = true,
}
-- Hide Error Text (ErrorText.lua): one switch per group, all off to start.
for _, g in ipairs(PR.ERROR_GROUPS or {}) do PR.defaults[PR.ErrorKey(g)] = false end
-- Mute Sounds (Sounds.lua): one switch per group, all off to start.
for _, g in ipairs(PR.SOUND_GROUPS or {}) do PR.defaults[PR.SoundKey(g)] = false end

local function Get(key)
    local ok, v = pcall(API.GetSetting, MODULE, key)
    if not ok or v == nil then return PR.defaults[key] end
    return v
end
PR.GetOption = Get

local function OpenWindow()
    if PR.MainWindow and not PR.MainWindow:IsShown() then PR.MainWindow:ShowTab("editor") end
end

PR.pages = {
    { id = "main", label = "Priority Rotation",
      desc = "A one-button rotation: each press casts the next spell on your list that is ready.",
      groups = {
          { label = "Rotation", items = {
              { type = "toggle", key = "rotationOn", label = "Priority Rotation",
                desc = "Your rotation key steps through the spell list you build in the rotation window." },
              { type = "button", label = "Open the rotation window", func = OpenWindow },
              { type = "text", label = "Type /pr to open or close the rotation window, and /pr help for its commands." },
          } },
      } },
}

-- The Error Messages page: DaylightUI's own error settings stay on beside these (ErrorText.lua says why).
local errorRows = {}
for _, g in ipairs(PR.ERROR_GROUPS or {}) do
    errorRows[#errorRows + 1] = { type = "toggle", key = PR.ErrorKey(g), label = g.label, desc = g.tip, reload = true }
end
PR.pages[#PR.pages + 1] = { id = "errors", label = "Error Messages",
    desc = "Keep chosen groups of the game's red error messages off the screen, and their voice lines quiet.",
    groups = { { label = "Hide error text", items = errorRows } } }

-- The Sounds page: applies at once.
local soundRows = {}
for _, g in ipairs(PR.SOUND_GROUPS or {}) do
    soundRows[#soundRows + 1] = { type = "toggle", key = PR.SoundKey(g), label = g.label, desc = g.tip }
end
PR.pages[#PR.pages + 1] = { id = "sounds", label = "Sounds",
    desc = "Silence chosen game sounds. A change applies at once.",
    groups = { { label = "Mute sounds", items = soundRows } } }

-- The Gear page: Auto Equip Upgrades (AutoEquip.lua), one switch to turn it on and one per quality under it, the
-- qualities greyed while it is off (a row's `disabled` takes a function of `get`, API.md).
PR.defaults.autoEquip = false
local QUALITY_ROWS = {
    { "autoEquipPoor",      "Poor (Grey)",        true },
    { "autoEquipCommon",    "Common (White)",     true },
    { "autoEquipUncommon",  "Uncommon (Green)",   false },
    { "autoEquipRare",      "Rare (Blue)",        false },
    { "autoEquipEpic",      "Epic (Purple)",      false },
    { "autoEquipLegendary", "Legendary (Orange)", false },
}
local gearRows = {
    { type = "toggle", key = "autoEquip", label = "Auto Equip Upgrades",
      desc = "Puts on gear from your bags that beats what you're wearing in that slot, or fills an empty slot. "
        .. "Stats come first: a piece with at least as much of every stat and more of one wins, and one with less "
        .. "never replaces, whatever the item level. Otherwise a higher item level wins, or heavier armor your class "
        .. "can wear at the same item level, never a lighter armor type. Only gear you can use, never gear that "
        .. "would bind when equipped. A piece with the wrong main stat for you replaces gear with your main stat only "
        .. "when it is at least 5 item levels or 25% higher, whichever is more. Trinkets are left alone, and weapons "
        .. "only replace one of the same kind. Not in combat. Each swap is named in chat. Type /pr equipcheck to "
        .. "see what it would do." },
}
for _, q in ipairs(QUALITY_ROWS) do
    PR.defaults[q[1]] = q[3]
    gearRows[#gearRows + 1] = { type = "toggle", key = q[1], label = q[2], desc = q[2] .. " gear counts as an upgrade.",
        disabled = function(get) return get("autoEquip") ~= true end }
end
PR.pages[#PR.pages + 1] = { id = "gear", label = "Gear",
    desc = "Put on upgrades from your bags as you find them.",
    groups = { { label = "Auto equip", items = gearRows } } }

PR.me.On("SettingChanged", function(scope, path, value)
    if scope ~= MODULE then return end
    if path == "rotationOn" then PR:SetEnabled(value) end
    if type(path) == "string" and path:find("^hideErrors_") and PR.SaveErrorChoices then PR.SaveErrorChoices(Get) end
    if type(path) == "string" and path:find("^muteSound_") and PR.ApplySoundMutes then PR.ApplySoundMutes(Get) end
    if type(path) == "string" and path:find("^autoEquip") and value == true and PR.AutoEquipRun then PR.AutoEquipRun() end
end)

PR.DUI_MODULE = _G.DaylightUI:RegisterModule(MODULE, {
    plugin = MODULE,
    label = "Priority Rotation",
    defaults = PR.defaults,
    options = { pages = PR.pages },
    -- DaylightUI turns its modules on in its PLAYER_LOGIN, before Priority Rotation's own login work: the
    -- rotation picks up the saved switch here without compiling twice.
    OnEnable = function()
        if PR.db then PR.db.enabled = Get("rotationOn") ~= false end
        -- The error choices this profile holds, for the next load (ErrorText.lua reads them at ADDON_LOADED).
        if PR.SaveErrorChoices then PR.SaveErrorChoices(Get) end
        -- A mute lasts until the game closes, so the chosen sounds are muted again at every login.
        if PR.ApplySoundMutes then PR.ApplySoundMutes(Get) end
    end,
})
