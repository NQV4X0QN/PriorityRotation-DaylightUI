-- Minimal WoW stub surface for loading the plugin headlessly (from VeritasUI's harness, qol_stub.lua).
_G.time, _G.date = os.time, os.date
local function nop() end
local hooks = {}
_G.__hooks = hooks
_G.hooksecurefunc = function(a, b, c)
  if type(a) == "string" then hooks[a] = hooks[a] or {}; table.insert(hooks[a], b)
  else hooks[tostring(b)] = hooks[tostring(b)] or {}; table.insert(hooks[tostring(b)], c) end
end
local evframes = {}
_G.__evframes = evframes
local function mkframe()
  local f = {}
  f.RegisterEvent = function(self, e) evframes[e] = evframes[e] or {}; table.insert(evframes[e], self) end
  f.UnregisterEvent, f.UnregisterAllEvents = nop, nop
  f.SetScript = function(self, s, fn) self["_"..s] = fn end
  f.HookScript = function(self, s, fn) self["_hook"..s] = fn end
  f.CreateFontString = function()
    local fs = {}
    return setmetatable(fs, { __index = function() return function() return 0 end end })
  end
  f.CreateTexture = function()
    return setmetatable({}, { __index = function() return function() end end })
  end
  -- __index must return NIL for private "_"-prefixed fields. A blanket
  -- function-returning catch-all makes every unset flag read TRUTHY, which
  -- silently defeats guards like `if frame._flag then return end`.
  return setmetatable(f, { __index = function(_, k)
    if type(k) == "string" and k:sub(1, 1) == "_" then return nil end
    return function() end
  end })
end
_G.CreateFrame = function() return mkframe() end
_G.UIParent = mkframe()
_G.C_Timer = { After = function(_, fn) if fn then end end,
               NewTimer = function() return { Cancel = nop } end,
               NewTicker = function() return { Cancel = nop } end }
-- Reads a flag rather than returning a constant: Lib localizes InCombatLockdown at load, so a
-- suite that swaps the global afterwards never reaches Lib's CombatQueue. Set _G.__inCombat.
_G.InCombatLockdown = function() return _G.__inCombat == true end
_G.strtrim = function(s) return (tostring(s):gsub("^%s+",""):gsub("%s+$","")) end
_G.CreateColor = function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
-- Blizzard's named colours (SharedColorConstants), as ColorMixin-like tables: r/g/b, GetRGB and
-- WrapTextInColorCode, which is all VeritasUI uses (owner's Blizzard-colours-only standard, 2026-11-01).
local function mkColor(r, g, b)
  local c = { r = r, g = g, b = b }
  c.GetRGB = function(self) return self.r, self.g, self.b end
  c.WrapTextInColorCode = function(self, t)
    return string.format("|cff%02x%02x%02x", math.floor(self.r * 255 + 0.5), math.floor(self.g * 255 + 0.5),
      math.floor(self.b * 255 + 0.5)) .. tostring(t) .. "|r"
  end
  return c
end
_G.NORMAL_FONT_COLOR, _G.HIGHLIGHT_FONT_COLOR = mkColor(1, 0.82, 0), mkColor(1, 1, 1)
_G.YELLOW_FONT_COLOR, _G.RED_FONT_COLOR, _G.GREEN_FONT_COLOR = mkColor(1, 1, 0), mkColor(1, 0.125, 0.125), mkColor(0.1, 1, 0.1)
_G.GRAY_FONT_COLOR, _G.DISABLED_FONT_COLOR = mkColor(0.5, 0.5, 0.5), mkColor(0.5, 0.5, 0.5)
_G.ORANGE_FONT_COLOR, _G.LIGHTBLUE_FONT_COLOR, _G.BRIGHTBLUE_FONT_COLOR = mkColor(1, 0.5, 0.25), mkColor(0.53, 0.67, 1), mkColor(0, 0.8, 1)
_G.LIGHTGRAY_FONT_COLOR = mkColor(0.6, 0.6, 0.6)
_G.ITEM_QUALITY_COLORS = {}
for i = 0, 8 do _G.ITEM_QUALITY_COLORS[i] = { r=i/8, g=0, b=0 } end
_G.ITEM_QUALITY_COLORS[1] = { r=1, g=1, b=1 }        -- Common = WHITE
_G.ITEM_QUALITY_COLORS[4] = { r=0.64, g=0.21, b=0.93 } -- Epic = purple
_G.NumberFontNormal = {}
_G.ITEM_LEVEL = "Item Level %d"
_G.SlashCmdList = {}
_G.UIPanelWindows = _G.UIPanelWindows or {}
_G.UISpecialFrames = _G.UISpecialFrames or {}
-- Blizzard_StaticPopup creates this unconditionally (StaticPopup.lua, no
-- LoadOnDemand in its TOC), so it is always present before third-party addons
-- load. The stub omitted it until v1.12.5 and got away with it ONLY because
-- Lib.lua carried `StaticPopupDialogs = StaticPopupDialogs or {}` — the very
-- Blizzard-global write that caused the v1.12.5 taint bug. The harness was
-- relying on the defect, so removing the defect broke eight suites at load.
-- Model the client here; never re-add that line to Lib to satisfy a test.
_G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
_G.ShowUIPanel, _G.HideUIPanel = function() end, function() end
local function anyobj()
  return setmetatable({}, { __index = function() return function() return anyobj() end end })
end
-- Capture setting change callbacks, keyed by the setting KEY (3rd arg), so a suite can
-- fire a toggle the way the options panel would. The previous blanket no-op made every
-- on-change path unreachable under test -- live-apply and teardown alike -- so a
-- checkbox could stop hiding what it drew and nothing would notice.
-- ⚠ module_charDB_test replaces _G.Settings wholesale after loading this stub; that
-- override still wins, so this addition does not disturb it.
_G.__settingCallbacks = {}
_G.Settings = setmetatable({
  RegisterAddOnSetting = function(_, _, key)
    local o = {}
    o.SetValueChangedCallback = function(_, fn) _G.__settingCallbacks[key] = fn end
    return setmetatable(o, { __index = function() return function() return anyobj() end end })
  end,
}, { __index = function() return function() return anyobj() end end })
_G.SettingsPanel = nil
_G.UnitName = _G.UnitName or function() return "Tester" end
_G.GetRealmName = _G.GetRealmName or function() return "TestRealm" end
_G.C_AddOns = { IsAddOnLoaded = function() return false end }
_G.GetZoneText = function() return "Test" end
_G.UnitName = function() return "Tester" end
_G.MerchantFrame = nil
_G.MinimapCluster = mkframe()
_G.WorldMapFrame = nil
_G.GetCoinTextureString = tostring
_G.C_CurrencyInfo = { GetCoinTextureString = tostring }
-- Present so QualityOfLife's Coins() exercises its PRIMARY path (GetMoneyString) rather
-- than its GetCoinTextureString fallback. Without this stub the global is nil, Coins()
-- silently takes the fallback branch, and the suite reads as coverage of a path the live
-- client never uses -- the stub-fidelity failure mode logged in the harness reference.
-- ⚠ The "M" prefix is LOAD-BEARING, not decoration: GetCoinTextureString above is
-- `tostring`, so without a distinguishing tag both paths return the identical string and
-- any "did the money render through Blizzard's formatter?" assertion passes vacuously --
-- including against v1.13.2, which used the other function. qol_vendor_test relies on it.
_G.GetMoneyString = function(copper) return "M" .. tostring(copper) end

-- Atlas registry. Present so the delve probe's atlas-resolution branch is actually
-- EXERCISED rather than skipped: its absence let a nil-namespace index ship, which
-- is the C_Console trap and the seventh stub-fidelity defect in this harness.
-- Unknown names return nil, matching the real client (GetAtlasInfo does not raise).
_G.__atlases = {
    ["common-icon-checkmark"] = { width = 16, height = 16 },
    ["UI-Frame-IconMask"]     = { width = 64, height = 64 },
}
_G.C_Texture = {
    GetAtlasInfo = function(name) return _G.__atlases[name] end,
}
