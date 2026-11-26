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

PR.me.On("SettingChanged", function(scope, path, value)
    if scope ~= MODULE then return end
    if path == "rotationOn" then PR:SetEnabled(value) end
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
    end,
})
