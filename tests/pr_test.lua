-- pr_test -- Priority Rotation headless suite, carried over from VeritasUI (audit 2026-10-11, P1-P5) with its
-- Retail-only checks removed: this plugin is WoW Forever only.
--
-- Loads the REAL Core.lua, Profiles.lua, Editor.lua and Settings.lua under a stubbed client
-- with a working macro list, action slots, key bindings, CVars and a simulated restricted
-- environment, so the secure stepping snippet (WrapScript body) and the Execute() calls that
-- fill `macros` actually run.
--
-- DISCRIMINATION: against v1.17.9 the P1, P2, P3 and P4 groups fail; the P5 group (compiler
-- and stepping) passes on both, by design -- it pins existing behaviour so the fixes cannot
-- change it.

local out = print
local pass, fail = 0, 0
local function check(name, ok, detail)
  if ok then pass = pass + 1; out("  PASS  " .. name)
  else fail = fail + 1; out("  FAIL  " .. name .. (detail and ("  -> " .. tostring(detail)) or "")) end
end

local W  -- the current world

-- DaylightUI, as much of its public API as the plugin calls (DaylightUI/API.md). Settings live in
-- _G.__duiSettings[key]; SettingChanged handlers in _G.__duiHandlers; registered modules in _G.__duiModules.
local function DaylightStub(opts)
  _G.__duiSettings = opts.settings or {}
  _G.__duiHandlers, _G.__duiModules, _G.__duiPlugins = {}, {}, {}
  _G.DaylightUI = {
    API = { major = 1, minor = 16,
      GetSetting = function(scope, key) if scope == "PriorityRotationDUI" then return _G.__duiSettings[key] end end,
      For = function() return {
        On = function(ev, fn) _G.__duiHandlers[ev] = _G.__duiHandlers[ev] or {}; table.insert(_G.__duiHandlers[ev], fn) end,
        RegisterSkin = function() return false end,
      } end,
      -- The look calls (API.md "Look like Daylight UI"): frames and font strings of the stubbed client, with
      -- what the suite reads back recorded on them.
      Skin = function(f, o) f._skin = o; return f end,
      Text = function(parent, size) local fs = parent:CreateFontString(); rawset(fs, "_size", size); return fs end,
      Button = function(parent, text, h) local b = CreateFrame("Button", nil, parent)
        b.text = b:CreateFontString(); b.text:SetText(text or ""); b._h = h
        b.SetOff = function(off) b._off = off end; b.SetGlow = function() end; return b end,
      MainButton = function(b, on) b._main = on ~= false; return true end,
      Close = function(parent, fn) local b = CreateFrame("Button", nil, parent); b._close = fn; return b end,
      Switch = function(parent) local b = CreateFrame("Button", nil, parent)
        b.SetOn = function(on) b._on = on end; return b end,
      Colors = function() return { VALUE = { 1, 1, 1 }, TEXT = { .9, .9, .9 }, LABEL = { .7, .6, .5 },
        OFF = { .4, .4, .4 }, GOOD = { 0, 1, 0 }, WARN = { 1, .8, 0 }, BAD = { 1, 0, 0 } } end,
      Accent = function() return 0.4, 0.6, 1 end,
      ClassColor = function() return 0.78, 0.61, 0.43 end,
      Media = function(f) return "media:" .. f end,
    },
    RegisterPlugin = function(_, name, o) _G.__duiPlugins[name] = o end,
    RegisterModule = function(_, name, def) _G.__duiModules[name] = def; return def end,
  }
end
-- A change on its options page, as DaylightUI reports it.
local function SetOption(key, value)
  _G.__duiSettings[key] = value
  for _, fn in ipairs(_G.__duiHandlers.SettingChanged or {}) do fn("PriorityRotationDUI", key, value) end
end

local function boot(opts)
  opts = opts or {}
  _G.__inCombat = opts.combat or false
  _G.print = function() end
  dofile("tests/stub.lua")
  DaylightStub(opts)
  local log = {}
  _G.print = function(s) log[#log + 1] = tostring(s) end

  local w = { log = log, timers = {}, cvarWrites = {}, overrides = {}, created = 0, edited = 0 }
  W = w

  -- ── timers ──
  _G.C_Timer = {
    After = function(_, fn) w.timers[#w.timers + 1] = { fn = fn } end,
    NewTimer = function(delay, fn)
      local t = { fn = fn, delay = delay }; t.Cancel = function(s) s.dead = true end
      w.timers[#w.timers + 1] = t; return t
    end,
    NewTicker = function() return { Cancel = function() end } end,
  }
  -- Timers longer than 10 s (the buff-skip wake-up) wait for w.runLater, so runTimers does not fire them early.
  w.later = {}
  function w.runTimers()
    for _ = 1, 20 do
      local q = w.timers; w.timers = {}
      if #q == 0 then return end
      for _, t in ipairs(q) do
        if (t.delay or 0) > 10 then w.later[#w.later + 1] = t
        elseif not t.dead and t.fn then t.fn() end
      end
    end
  end
  function w.runLater()
    local q = w.later; w.later = {}
    for _, t in ipairs(q) do if not t.dead and t.fn then t.fn() end end
    w.runTimers()
  end

  -- ── macros ──
  w.macros = {}
  for _, m in ipairs(opts.macros or {}) do w.macros[#w.macros + 1] = { name = m[1], icon = m[2], body = m[3] } end
  local function idxOf(x)
    if type(x) == "number" then return w.macros[x] and x or nil end
    for i, m in ipairs(w.macros) do if m.name == x then return i end end
  end
  _G.GetMacroIndexByName = function(n) return idxOf(n) or 0 end
  _G.GetMacroInfo = function(x) local i = idxOf(x); local m = i and w.macros[i]
    if m then return m.name, m.icon, m.body end end
  _G.GetMacroBody = function(x) local i = idxOf(x); return i and w.macros[i].body end
  _G.GetNumMacros = function() return #w.macros, 0 end
  _G.MAX_ACCOUNT_MACROS = 120
  _G.EditMacro = function(i, name, icon, body)
    w.edited = w.edited + 1; w.macros[i] = { name = name, icon = icon, body = body } end
  _G.CreateMacro = function(name, icon, body)
    w.created = w.created + 1; w.macros[#w.macros + 1] = { name = name, icon = icon, body = body } end

  -- ── action slots and bindings ──
  w.actions = opts.actions or {}       -- [slot] = macro name
  _G.GetActionInfo = function(slot)
    local n = w.actions[slot]; if not n then return nil end
    return "macro", idxOf(n)
  end
  w.bindings = opts.bindings or {}     -- [command] = key
  _G.GetBindingKey = function(cmd) return w.bindings[cmd] end
  _G.SetOverrideBindingClick = function(_, _, key, btn) w.overrides[key] = btn end
  _G.ClearOverrideBindings = function() w.overrides = {} end

  -- ── CVars ──
  w.cvars = { ActionButtonUseKeyDown = opts.keyDown or "1" }
  _G.C_CVar = {
    GetCVar = function(n) return w.cvars[n] end,
    GetCVarDefault = function(n) if n == "ActionButtonUseKeyDown" then return "1" end end,
    SetCVar = function(n, v) w.cvarWrites[#w.cvarWrites + 1] = { n, v }; w.cvars[n] = v; return true end,
  }

  -- ── spells / spec ──
  w.spells = {
    [1] = { name = "Alpha", iconID = 101 }, [2] = { name = "Bravo", iconID = 102 },
    [3] = { name = "Charlie", iconID = 103 },
    [4] = { name = "Single-Button Assistant", iconID = 104 },
    [6603] = { name = "Attack", iconID = 105 },
  }
  -- Blizzard's assistant: GetActionSpell gives its spell, IsAvailable whether the game offers it.
  _G.C_AssistedCombat = opts.sba and {
    GetActionSpell = function() return 4 end,
  } or nil
  -- Tooltip cast-time row: "Channeled" for spells listed in opts.tipChannel, else "Instant".
  _G.C_TooltipInfo = { GetSpellByID = function(id)
    return { lines = { { leftText = "Name" }, { leftText = "30 Fury" },
                       { leftText = (opts.tipChannel or {})[id] and (opts.tipWord or "Channeled") or "Instant" } } }
  end }
  _G.C_Spell = { GetSpellName = function(id) return w.spells[id] and w.spells[id].name end,
                 -- w.cooldowns[name] = seconds of cooldown showing now (absent = 0, ready).
                 GetSpellCooldown = function(x) return { duration = (w.cooldowns or {})[x] or 0, startTime = 0,
                                                          isEnabled = true, isActive = false, modRate = 1 } end,
                 GetSpellInfo = function(x)
    if type(x) == "number" then local s = w.spells[x]; return s and { name = s.name, iconID = s.iconID, spellID = x } end
    for id, s in pairs(w.spells) do if s.name == x then return { name = s.name, iconID = s.iconID, spellID = id } end end
  end }
  _G.C_SpecializationInfo = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function() return 9999, "Test", "", 555 end,
  }
  _G.GetNumSpecializations = function() return opts.specs or 1 end
  _G.UnitClass = function() return "Tester", "WARRIOR" end
  _G.strtrim = _G.strtrim

  -- Window furniture Blizzard provides (P6 builds the real window).
  _G.GameTooltip = _G.GameTooltip or setmetatable({}, { __index = function() return function() end end })
  _G.PanelTemplates_TabResize = _G.PanelTemplates_TabResize or function() end
  _G.PanelTemplates_SetNumTabs = _G.PanelTemplates_SetNumTabs or function() end
  _G.PanelTemplates_SetTab = _G.PanelTemplates_SetTab or function() end

  -- ── frames: attributes, scripts and a simulated restricted environment ──
  local realCreate = _G.CreateFrame
  w.frames = {}
  w.texts = {}
  w.atlases = {}
  w.fsPoints = {}
  _G.CreateFrame = function(ftype, name, parent, template)
    local f = realCreate(ftype, name, parent, template)
    -- Window checks (P6): template, anchors, button and font-string text.
    f._tmpl = template
    f.GetName = function() return name end
    f.RegisterUnitEvent = function(self, e) return self:RegisterEvent(e) end
    w.frames[#w.frames + 1] = f
    f.SetPoint = function(self, ...) self._points = self._points or {}; self._points[#self._points + 1] = { ... } end
    f.SetText = function(self, t) self._text = t end
    f.SetSize = function(self, w2, h) self._w, self._h = w2, h end
    f.SetShown = function(self, s) self._shown = s and true or false end
    f.Show = function(self) self._shown = true end
    f.Hide = function(self) self._shown = false end
    local mktex = f.CreateTexture
    f.CreateTexture = function(self, ...)
      local t = mktex(self, ...)
      rawset(t, "SetAtlas", function(_, a) w.atlases[a] = (w.atlases[a] or 0) + 1 end)
      return t
    end
    f.SetHighlightAtlas = function(_, a) w.atlases[a] = (w.atlases[a] or 0) + 1 end
    local mkfs = f.CreateFontString
    f.CreateFontString = function(self, ...)
      local fs = mkfs(self, ...)
      local pts = {}
      rawset(fs, "SetPoint", function(_, ...) pts[#pts + 1] = { ... } end)
      rawset(fs, "SetText", function(_, t) w.texts[#w.texts + 1] = tostring(t); w.fsPoints[tostring(t)] = pts end)
      return fs
    end
    if template == "ButtonFrameTemplate" or template == "PortraitFrameTemplate" then
      local tex = function() return setmetatable({}, { __index = function() return function() end end }) end
      f.CloseButton = realCreate("Button")
      f.PortraitContainer = { portrait = tex() }
      f.TitleContainer = { TitleText = tex() }
      f.SetTitle = function() end
      -- A real frame reads an unset field as nil; the stub answers every field with a function. The spec switcher
      -- is not built with one spec (audit 2026-11-09 P2), so the window must read it as absent.
      f.specDD = false
      w.window = f
    end
    if template == "ButtonFrameTemplate" then
      f.Inset = realCreate("Frame")
      f.Inset.Bg = setmetatable({}, { __index = function() return function() end end })
      f.Inset.Bg.SetAtlas = function(self, a) self._atlas = a end
    end
    if template == "LargeSideTabButtonTemplate" then
      -- What Lib's VUI.CreateSideTabs touches: Icon, SelectedTexture, the custom mouse-up handler and
      -- Forever's SetFillToInterior (SharedUIPanelTemplates, Gethe forever branch).
      f.Icon = { SetTexture = function(self, t) self._tex = t end }
      f.SelectedTexture = { SetShown = function(self, s) self._shown = s end }
      f.SetCustomOnMouseUpHandler = function(self, h) self._mouseUp = h end
      f.SetFillToInterior = function(self, v) self._fill = v end
      w.sideTabs = w.sideTabs or {}
      w.sideTabs[#w.sideTabs + 1] = f
    end
    if name == "PRAttackButton" then
      -- SecureCmdOptionParse models only what the After snippet asks: "[channeling:<name>] 1"
      -- is true while w.channeling == <name> (the 2026-10-31 in-game probe measured exactly that).
      local attrs, env = {}, setmetatable({ newtable = function(...) return { ... } end, tonumber = tonumber,
        SecureCmdOptionParse = function(c)
          local n = c:match("^%[channeling:(.-)%] 1$")
          if n and w.channeling == n then return "1" end
          -- Re-equip (2026-11-12): "[equipped:<subclass>] 1" is true while the main hand holds that subclass.
          local e = c:match("^%[equipped:(.-)%] 1$")
          if e and w.hands and w.hands[16] and w.items[w.hands[16]] and w.items[w.hands[16]].sub == e then return "1" end
          -- Long-buff cap (2026-11-12): "[combat] 1" while in combat.
          if c == "[combat] 1" and _G.__inCombat then return "1" end
        end }, { __index = _G })
      f._attrs, f._env = attrs, env
      f.SetAttribute = function(_, k, v) attrs[k] = v end
      f.GetAttribute = function(_, k) return attrs[k] end
      f.Execute = function(_, code) assert(load(code, "Execute", "t", env))() end
      f.WrapScript = function(_, _, script, body) f._wrap = { script = script, body = body } end
      w.rotBtn = f
    end
    return f
  end

  -- ── hands and items (Reequip.lua): [itemID] = { name, classID, subclassID, sub = subclass name } ──
  w.hands = opts.hands or {}
  w.items = {
    [6256] = { name = "Fishing Pole", class = 2, subclass = 20, sub = "Fishing Poles" },
    [2131] = { name = "Shortsword", class = 2, subclass = 7, sub = "One-Handed Swords" },
    [2129] = { name = "Large Round Shield", class = 4, subclass = 6, sub = "Shields" },
    [1411] = { name = "Withered Staff", class = 2, subclass = 10, sub = "Staves" },
  }
  _G.GetInventoryItemID = function(_, slot) return w.hands[slot] end
  _G.C_Item = _G.C_Item or {}
  _G.C_Item.GetItemInfoInstant = function(id) local i = w.items[id]
    if i then return id, nil, nil, nil, nil, i.class, i.subclass end end
  _G.C_Item.GetItemInfo = function(id) local i = w.items[id]; return i and i.name end
  _G.C_Item.GetItemSubClassInfo = function(c, s)
    for _, i in pairs(w.items) do if i.class == c and i.subclass == s then return i.sub end end end

  _G.PriorityRotationDUIDB = opts.db
  -- Skip a buff you already have (2026-11-12): w.auras[name] = { expirationTime = n } (0 = no end); w.now = clock.
  w.auras, w.now = opts.auras or {}, 1000
  _G.GetTime = function() return w.now end
  _G.C_UnitAuras = { GetAuraDataBySpellName = function(unit, name, filter)
    if unit == "player" and filter == "HELPFUL" then return w.auras[name] end end }
  w.PR = {}
  for _, file in ipairs({ "Plugin", "Lib", "Widgets", "Core", "Reequip", "Profiles", "SpellbookOpener", "Editor",
                             "Settings", "ErrorText", "Sounds", "AutoEquip", "Options" }) do
    local chunk = assert(loadfile("PriorityRotationDUI/" .. file .. ".lua"))
    chunk("PriorityRotationDUI", w.PR)
  end
  local function fire(ev, ...)
    for _, f in ipairs(_G.__evframes[ev] or {}) do if f._OnEvent then f._OnEvent(f, ev, ...) end end
  end
  w.fire = fire
  fire("ADDON_LOADED", "PriorityRotationDUI")
  if _G.__afterAddonLoaded then _G.__afterAddonLoaded() end   -- a suite's look at the state before any login
  -- DaylightUI turns its modules on in its own PLAYER_LOGIN, before the plugin's.
  local mod = _G.__duiModules.PriorityRotationDUI
  if mod and mod.OnEnable then mod.OnEnable(mod) end
  if opts.profile then
    w.PR.db.profiles[w.PR:GetProfileKey()] = opts.profile
  end
  fire("PLAYER_LOGIN")
  fire("PLAYER_ENTERING_WORLD")
  w.runTimers()

  function w.said(p) for _, l in ipairs(w.log) do if l:find(p, 1, true) then return l end end end
  function w.slash(msg) _G.SlashCmdList["PRDUI"](msg) ; w.runTimers() end
  -- One physical press through the WrapScript pre-body: down then up.
  function w.press()
    local body = w.rotBtn._wrap.body
    local fn = assert(load("local self, button, down = ...\n" .. body, "wrap", "t", w.rotBtn._env))
    fn(w.rotBtn, "LeftButton", true)
    fn(w.rotBtn, "LeftButton", false)
    return w.rotBtn._attrs.macrotext
  end
  function w.keyDownWrites()
    local n = 0
    for _, c in ipairs(w.cvarWrites) do if c[1] == "ActionButtonUseKeyDown" then n = n + 1 end end
    return n
  end
  return w
end

local STUB = "#showtooltip\n/click PRAttackButton"
local function prof(spells, extra)
  local p = { name = "T", spells = spells, reacquire = false }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
local A = function(t) local e = { spellID = 1, spellName = "Alpha", icon = 101, freq = 1 }; for k, v in pairs(t or {}) do e[k] = v end; return e end
local B = function(t) local e = { spellID = 2, spellName = "Bravo", icon = 102, freq = 1 }; for k, v in pairs(t or {}) do e[k] = v end; return e end
local C = function(t) local e = { spellID = 3, spellName = "Charlie", icon = 103, freq = 1 }; for k, v in pairs(t or {}) do e[k] = v end; return e end

----------------------------------------------------------------------------------------------
out("P1) the Attack macro is never created or overwritten behind the player's back")
do
  local w = boot({ db = { enabled = true, profiles = {} } })
  check("no macro created at login", w.created == 0, w.created)
  w.slash("macro")
  check("/pr macro creates it on request", w.created == 1 and w.macros[1] and w.macros[1].body == STUB)
end
do
  local w = boot({ db = { enabled = true, profiles = {} },
                   macros = { { "Attack", 7, "/cast Charge" } },
                   actions = { [5] = "Attack" }, bindings = { ACTIONBUTTON5 = "5" } })
  check("a different macro named Attack is left untouched at login",
        w.macros[1].body == "/cast Charge" and w.macros[1].icon == 7, w.macros[1].body)
  check("the rotation does not take over that macro's key", next(w.overrides) == nil)
  check("chat says the name is taken", w.said("already") ~= nil)
  w.slash("macro")
  check("/pr macro refuses to overwrite it", w.macros[1].body == "/cast Charge")
  w.slash("scan")
  check("/pr scan does not bind it", next(w.overrides) == nil)
end
do
  local w = boot({ db = { enabled = true, profiles = {} }, profile = prof({ B() }),
                   macros = { { "Attack", 1, STUB } },
                   actions = { [5] = "Attack" }, bindings = { ACTIONBUTTON5 = "5" } })
  check("our own macro's icon is refreshed at login", w.macros[1].icon == 102, w.macros[1].icon)
  check("and its key is bound to the rotation", w.overrides["5"] == "PRAttackButton")
end
do
  local w = boot({ db = { enabled = true, profiles = {} }, settings = { rotationOn = false }, macros = { { "Attack", 1, STUB } } })
  check("disabled: macro not touched at login", w.edited == 0 and w.created == 0)
end

----------------------------------------------------------------------------------------------
-- The plugin never writes WoW's account-wide ActionButtonUseKeyDown: VeritasUI's one-time restore of it (for a
-- value it had itself overwritten until v1.17.9) is not carried over. DISCRIMINATION: with
-- RestoreKeyDownSettingOnce back in Core.lua, the CVar checks fail.
out("P2) WoW's account-wide 'cast on key down' setting is not ours to change")
do
  local w = boot({ db = { enabled = true, profiles = {} }, keyDown = "0" })
  check("rotation button casts on release by itself", w.rotBtn._attrs.useOnKeyDown == false,
        tostring(w.rotBtn._attrs.useOnKeyDown))
  check("the player's setting is never written", w.keyDownWrites() == 0 and w.cvars.ActionButtonUseKeyDown == "0",
        w.keyDownWrites())
  SetOption("rotationOn", false); SetOption("rotationOn", true)
  check("turning it off and on writes nothing either", w.keyDownWrites() == 0, w.keyDownWrites())
end
do
  local w = boot({ db = { enabled = true, profiles = {} }, keyDown = "0", combat = true })
  _G.__inCombat = false
  w.fire("PLAYER_REGEN_ENABLED")
  check("nor after combat", w.keyDownWrites() == 0)
end

----------------------------------------------------------------------------------------------
-- 2026-11-25: the on/off switch is on the plugin's DaylightUI options page (Options.lua). DISCRIMINATION: with
-- Options.lua's OnEnable or SettingChanged handler removed, P2b fails.
out("P2b) the switch on the DaylightUI options page")
do
  local w = boot({ db = { enabled = true, profiles = {} }, settings = { rotationOn = false } })
  check("switched off there: the rotation is off at login", w.PR:IsEnabled() == false)
  SetOption("rotationOn", true)
  check("switched on there: on now", w.PR:IsEnabled() == true and w.said("Enabled.") ~= nil)
  SetOption("rotationOn", false)
  check("and off again", w.PR:IsEnabled() == false and w.said("Disabled.") ~= nil)
  local mod = _G.__duiModules.PriorityRotationDUI
  check("one options page with the switch and an open button", mod and mod.options.pages[1]
        and mod.options.pages[1].groups[1].items[1].key == "rotationOn"
        and mod.options.pages[1].groups[1].items[2].type == "button")
  check("registered as a plugin that states the API version it needs",
        _G.__duiPlugins.PriorityRotationDUI and _G.__duiPlugins.PriorityRotationDUI.needs[1] == 1)
end
----------------------------------------------------------------------------------------------
out("P3) bar slots map to the real bars")
do
  local w = boot({ db = { enabled = true, profiles = {} }, macros = { { "Attack", 1, STUB } },
                   actions = { [145] = "Attack" }, bindings = { MULTIACTIONBAR5BUTTON1 = "F" } })
  check("Action Bar 6 (slot 145) is found and bound", w.overrides["F"] == "PRAttackButton")
end
do
  local w = boot({ db = { enabled = true, profiles = {} }, macros = { { "Attack", 1, STUB } },
                   actions = { [180] = "Attack" }, bindings = { MULTIACTIONBAR7BUTTON12 = "G" } })
  check("Action Bar 8 (slot 180) is found and bound", w.overrides["G"] == "PRAttackButton")
end
do
  local w = boot({ db = { enabled = true, profiles = {} }, macros = { { "Attack", 1, STUB } },
                   actions = { [73] = "Attack" },
                   bindings = { MULTIACTIONBAR5BUTTON1 = "F", ACTIONBUTTON1 = "1" } })
  check("form/stealth page (slot 73) does not take over Bar 6's key", w.overrides["F"] == nil)
  check("nor any other key", next(w.overrides) == nil)
  w.slash("scan")
  check("/pr scan says the page can't be bound", w.said("can't be bound") ~= nil)
end
do
  local w = boot({ db = { enabled = true, profiles = {} }, macros = { { "Attack", 1, STUB } },
                   actions = { [73] = "Attack", [145] = "Attack" },
                   bindings = { MULTIACTIONBAR5BUTTON1 = "F" } })
  check("a bindable copy (Bar 6) wins over an earlier form-page copy", w.overrides["F"] == "PRAttackButton")
end

----------------------------------------------------------------------------------------------
out("P4) the editor redraws once the new sequence is built")
do
  local w = boot({ db = { enabled = true, profiles = {} }, profile = prof({ A(), B() }) })
  local seen
  w.PR.Editor = { Refresh = function() seen = #w.PR.compiledSequence end }
  w.PR:CurrentProfile().spells[3] = C()
  w.PR:SaveCurrentProfile()
  w.runTimers()
  check("preview redrawn with the new sequence", seen == 3, tostring(seen))
end

----------------------------------------------------------------------------------------------
out("P5) the rotation builder and the key-press stepping (pins current behaviour)")
do
  local w = boot({ db = { enabled = true, profiles = {} }, profile = prof({ A({ freq = 3 }), B() }) })
  local seq = w.PR.compiledSequence
  check("freq 3 + freq 1 -> two steps after duplicate collapse", #seq == 2, #seq)
  check("step 1 is Alpha", seq[1] and seq[1]:find("/cast %[nochanneling%] Alpha") ~= nil, seq[1])
  check("step 2 is Bravo", seq[2] and seq[2]:find("Bravo", 1, true) ~= nil, seq[2])
  check("first press casts step 1", w.press() == seq[1])
  check("second press casts step 2", w.press() == seq[2])
  check("third press wraps to step 1", w.press() == seq[1])
  -- key-down alone must not advance
  local body = w.rotBtn._wrap.body
  local fn = assert(load("local self, button, down = ...\n" .. body, "wrap", "t", w.rotBtn._env))
  local before = w.rotBtn._attrs.step
  fn(w.rotBtn, "LeftButton", true)
  check("key-down does not advance the step", w.rotBtn._attrs.step == before)
end
do
  -- "After" (v1.36.0): a link waits for its target's CHANNEL, seen by the press snippet.
  local function count(w, n, pat)
    local c = 0
    for _ = 1, n do if (w.press() or ""):find(pat, 1, true) then c = c + 1 end end
    return c
  end
  local function channelStart(w, id) w.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", id); w.runTimers() end

  -- Not yet seen channelling: the link is inert and the follower plays normally.
  local w = boot({ db = { enabled = true, profiles = {} },
                   profile = prof({ A({ freq = 2 }), B({ freq = 2 }), C({ follows = "spell:1", followOnly = true }) }) })
  check("After: no link while the target has not been seen channelling", #w.PR.compiledLinks == 0)
  check("After: and the follower stays in the sequence",
        table.concat(w.PR.compiledSequence, "|"):find("Charlie", 1, true) ~= nil)

  -- Seen channelling (the event the game fires): Alpha becomes a target; Only After holds Charlie.
  channelStart(w, 1)
  check("After: the channel event marks the target", w.PR:CurrentProfile().spells[1].channel == true)
  check("After: one link compiled", #w.PR.compiledLinks == 1, #w.PR.compiledLinks)
  check("Only After: Charlie is not in the sequence",
        table.concat(w.PR.compiledSequence, "|"):find("Charlie", 1, true) == nil,
        table.concat(w.PR.compiledSequence, " | "))
  check("Only After: 60 presses with no channel never cast Charlie", count(w, 60, "Charlie") == 0)
  w.channeling = "Alpha"
  check("Only After: presses during the channel do not cast Charlie", count(w, 5, "Charlie") == 0)
  w.channeling = nil
  -- After the channel: Charlie on every other press for AFTER_PRESSES tries, the rotation between
  -- (2026-10-31: back-to-back tries left the character idle ~1.5 s when Charlie was on cooldown).
  local N = w.PR.AFTER_PRESSES
  local pat, normal = {}, 0
  for k = 1, 2 * N do
    local t = w.press() or ""
    local isC = t:find("Charlie", 1, true) ~= nil
    pat[k] = isC and "C" or "r"
    if not isC and t ~= "" then normal = normal + 1 end
  end
  check("Only After: Charlie, rotation, Charlie, rotation ... for AFTER_PRESSES tries",
        table.concat(pat) == string.rep("Cr", N), table.concat(pat))
  check("Only After: every press between the tries is a real rotation step", normal == N, normal)
  check("Only After: then the rotation resumes", count(w, 30, "Charlie") == 0)
  w.channeling = "Bravo"
  local ok = count(w, 3, "Charlie") == 0
  w.channeling = nil
  check("Only After: another spell's channel does not release it", ok and count(w, 3, "Charlie") == 0)

  -- Also After: the follower keeps its normal place AND is cast after the channel.
  w.PR:CurrentProfile().spells[3].followOnly = nil
  w.PR:SaveCurrentProfile(); w.runTimers()
  check("Also After: Charlie is back in the sequence",
        table.concat(w.PR.compiledSequence, "|"):find("Charlie", 1, true) ~= nil)
  w.channeling = "Alpha"; w.press(); w.channeling = nil
  check("Also After: and is cast right after the channel", (w.press() or ""):find("Charlie", 1, true) ~= nil)

  -- Two followers on one channel go in profile order, alternating, then the rotation resumes.
  local w2 = boot({ db = { enabled = true, profiles = {} },
                    profile = prof({ A({ channel = true }), B({ follows = "spell:1", followOnly = true }),
                                     C({ follows = "spell:1", followOnly = true }) }) })
  w2.channeling = "Alpha"; w2.press(); w2.channeling = nil
  -- They take turns for 2 x AFTER_PRESSES presses (the 2026-10-31 log: a window inside one GCD
  -- let the first cast starve the other), then the rotation resumes.
  local got, want, f = {}, {}, 0
  for k = 1, 4 * w2.PR.AFTER_PRESSES do
    if k % 2 == 1 then f = f + 1; want[k] = (f % 2 == 1) and "Bravo" or "Charlie" else want[k] = "Alpha" end
  end
  want[#want + 1] = "Alpha"
  for k = 1, #want do got[k] = (w2.press() or ""):match("(%a+)$") end
  check("two followers take turns, the rotation between, then Alpha",
        table.concat(got, ",") == table.concat(want, ","), table.concat(got, ","))
  check("the tries span more than one global cooldown at ~9 presses/s", 4 * w2.PR.AFTER_PRESSES / 9 > 1.2)

  -- In the window, the rotation's own steps skip the target (on cooldown after its channel) and the
  -- followers (already being tried): the third 2026-10-31 run stood ~1 s on exactly those.
  local w7 = boot({ db = { enabled = true, profiles = {} },
                    profile = prof({ A({ channel = true, freq = 3 }), B({ follows = "spell:1", freq = 3 }), C() }) })
  w7.channeling = "Alpha"; w7.press(); w7.channeling = nil
  local evens, ok7 = {}, true
  for k = 1, 2 * w7.PR.AFTER_PRESSES do
    local t = (w7.press() or ""):match("(%a+)$")
    if k % 2 == 0 then evens[#evens + 1] = t; if t ~= "Charlie" then ok7 = false end end
  end
  check("window: every rotation press skips the target and the follower", ok7, table.concat(evens, ","))
  local after = {}
  for k = 1, 6 do after[k] = (w7.press() or ""):match("(%a+)$") end
  check("after the window the target and follower are back in the rotation",
        table.concat(after, ","):find("Alpha", 1, true) and table.concat(after, ","):find("Bravo", 1, true),
        table.concat(after, ","))

  -- Only After goes first even when an Also After follower sits above it in the list.
  local w6 = boot({ db = { enabled = true, profiles = {} },
                    profile = prof({ A({ channel = true }), B({ follows = "spell:1" }),
                                     C({ follows = "spell:1", followOnly = true }) }) })
  w6.channeling = "Alpha"; w6.press(); w6.channeling = nil
  check("Only After gets the first press after the channel", (w6.press() or ""):find("Charlie", 1, true) ~= nil)
  w2.channeling = "Alpha"; w2.press(); w2.channeling = nil
  w2.press()                                   -- Bravo; then a new channel starts at once
  w2.channeling = "Alpha"; w2.press(); w2.channeling = nil
  check("a new channel starts again from the first follower",
        (w2.press() or ""):find("Bravo", 1, true) ~= nil)

  -- English tooltip: a spell whose cast-time row says "Channeled" is a target at once, no cast needed.
  local w5 = boot({ db = { enabled = true, profiles = {} }, tipChannel = { [1] = true },
                    profile = prof({ A(), B(), C({ follows = "spell:1", followOnly = true }) }) })
  check("tooltip 'Channeled' marks the target without a cast", w5.PR:CurrentProfile().spells[1].channel == true)
  check("an 'Instant' tooltip does not", w5.PR:CurrentProfile().spells[2].channel == nil)
  check("and the link is live at login", #w5.PR.compiledLinks == 1, #w5.PR.compiledLinks)

  -- Audit P1 (2026-11-01): another language's word, via Blizzard's SPELL_CAST_CHANNELED.
  -- DISCRIMINATION: v1.46.2 compares to the English literal only, so the first check fails there.
  _G.SPELL_CAST_CHANNELED = "Kanalisiert"
  local w7 = boot({ db = { enabled = true, profiles = {} }, tipChannel = { [1] = true }, tipWord = "Kanalisiert",
                    profile = prof({ A(), B(), C({ follows = "spell:1", followOnly = true }) }) })
  check("a translated 'Channeled' (SPELL_CAST_CHANNELED) marks the target", w7.PR:CurrentProfile().spells[1].channel == true)
  check("and the translated word on an Instant spell still does not", w7.PR:CurrentProfile().spells[2].channel == nil)
  _G.SPELL_CAST_CHANNELED = nil

  -- A secret spell ID (restricted content) teaches nothing.
  _G.issecretvalue = function(v) return v == "SECRET" end
  local w3 = boot({ db = { enabled = true, profiles = {} }, profile = prof({ A(), C({ follows = "spell:1" }) }) })
  channelStart(w3, "SECRET")
  check("a secret channel spell ID is ignored", w3.PR:CurrentProfile().spells[1].channel == nil)
  _G.issecretvalue = nil

  -- A link to a macro or trinket can never be a channel: cleared once at login, with a chat line.
  local w4 = boot({ db = { enabled = true, profiles = { other = prof({ C({ follows = "macro:Burst", followOnly = true }) }) } },
                    profile = prof({ A(), C({ follows = "item:5" }) }) })
  local cleared = true
  for _, p in pairs(w4.PR.db.profiles) do
    for _, e in ipairs(p.spells) do if e.follows and not e.follows:find("^spell") then cleared = false end end
  end
  check("macro/trinket After links cleared in every profile", cleared)
  check("and the chat line says so", w4.said("link(s) to a macro or trinket") ~= nil)
end
do
  local w = boot({ db = { enabled = true, profiles = {} },
                   profile = prof({ A({ combatOnly = true }), B() }, { reacquire = true }) })
  local seq = w.PR.compiledSequence
  check("combat-only entry compiled with [combat, nochanneling]",
        seq[1]:find("/cast [combat, nochanneling] Alpha", 1, true) ~= nil, seq[1])
  check("reacquire prefix on spell steps",
        seq[1]:find("^/cleartarget %[dead%]\n/targetenemy %[noexists%]\n") ~= nil, seq[1])
end
do
  local w = boot({ db = { enabled = true, profiles = {} },
                   profile = prof({ { spellID = 999, spellName = "Gone", freq = 1 }, B() }) })
  check("stale spell skipped", #w.PR.compiledSequence == 1)
  check("stale spell warned", w.said("Stale spell") ~= nil)
end

_G.print = out
-- 2026-11-25 (owner: the window "doesn't quite fit in with the rest of DaylightUI"): the window is built from
-- DaylightUI's public look calls and laid out like its trainer window (Widgets.lua). DISCRIMINATION: the
-- 8f0ca40 window (Blizzard's ButtonFrameTemplate skinned afterwards) fails 6a, 6b, 6c and 6h.
out("P6) the window: DaylightUI's window look, laid out like its trainer window")
do
  local w = boot({ db = nil })
  local win = w.PR.MainWindow
  check("6a) window built without error, in DaylightUI's window shell", win and not w.said("Editor error")
        and win._skin and win._skin.window == true, w.said("Editor error"))
  check("6b) the trainer window's size, 440 x 540", win and win._w == 440 and win._h == 540,
        win and (tostring(win._w) .. "x" .. tostring(win._h)))
  local BLIZZ = { ButtonFrameTemplate = true, PortraitFrameTemplate = true, PanelTabButtonTemplate = true,
                  LargeSideTabButtonTemplate = true, UICheckButtonTemplate = true, MagicButtonTemplate = true,
                  WowStyle1DropdownTemplate = true }
  local used
  for _, f in ipairs(w.frames) do if f._tmpl and BLIZZ[f._tmpl] then used = f._tmpl end end
  check("6c) no Blizzard window templates", used == nil, used)
  local tabs = win and win.tabs or {}
  check("6d) two header tabs, Rotation then Settings", #tabs == 2 and tabs[1].id == "editor" and tabs[2].id == "settings")
  local p = tabs[2] and tabs[2]._points and tabs[2]._points[#tabs[2]._points] or {}
  check("6e) the last tab sits 14 left of the X", p[1] == "RIGHT" and p[2] == win.close and p[3] == "LEFT" and p[4] == -14)
  local cp = win and win.close._points and win.close._points[1] or {}
  check("6f) the X at TOPRIGHT -9, -15", cp[1] == "TOPRIGHT" and cp[4] == -9 and cp[5] == -15)
  check("6g) Rotation starts picked", tabs[1] and tabs[1].picked == true and not tabs[2].picked
        and win.pages.editor and win.pages.settings)
  local ed = w.PR.Editor
  local tips = ed and ed.headerTips or {}
  local n = 0
  for _, k in ipairs({ "Rotation", "Frequency", "After", "Combat" }) do
    if type(tips[k]) == "string" and #tips[k] > 20 then n = n + 1 end
  end
  check("6h) every column is named over its controls, each with a tooltip", n == 4 and ed.captions
        and ed.captions.Frequency and ed.captions.After and ed.captions.Combat, n)
  local main
  for _, b in ipairs(ed and ed.foot.buttons or {}) do if b._main then main = b.text and b.text._t end end
  local function label(b) for _, t in ipairs(w.texts) do if t == "Scan & Bind" then return t end end end
  check("6i) Scan & Bind is the Rotation page's main button", ed and ed.foot.buttons[1]._main == true and label())
  local shown = 0
  for _, row in ipairs(ed and ed.rows or {}) do if row._shown ~= false then shown = shown + 1 end end
  check("6j) an empty rotation shows one line to add to", shown == 1, shown)
end
out("P7) drag a slot to reorder (v1.35.11, replaced the up/down arrows)")
do
  local w = boot({ db = nil })
  local spells = { A(), B(), C({ follows = "spell:1" }) }
  w.PR:CurrentProfile().spells = spells
  local ed = w.PR.Editor
  check("editor exposes its reorder", ed and type(ed.StartReorder) == "function" and type(ed.FinishReorder) == "function")
  if ed and rawget(ed, "rows") then
  -- Lay the ten lines out on screen: 38 px apart, top line at y=1000.
  for k, row in ipairs(ed.rows) do
    local top = 1000 - (k - 1) * 42
    row.GetTop, row.GetBottom = function() return top end, function() return top - 38 end
    row.GetEffectiveScale = function() return 1 end
  end
  local cursorY
  _G.GetCursorPosition = function() return 0, cursorY end
  local function names()
    local t = {}
    for _, e in ipairs(w.PR:CurrentProfile().spells) do t[#t + 1] = e.spellName end
    return table.concat(t, ",")
  end
  cursorY = 1000 - 2 * 42 - 10          -- over row 3
  ed:StartReorder(1); ed:FinishReorder()
  check("slot 1 dropped on slot 3 lands third", names() == "Bravo,Charlie,Alpha", names())
  cursorY = 1100                        -- above the first row
  ed:StartReorder(3); ed:FinishReorder()
  check("dropped above the list lands first", names() == "Alpha,Bravo,Charlie", names())
  cursorY = 1000 - 8 * 42 - 10          -- over empty row 9
  ed:StartReorder(1); ed:FinishReorder()
  check("dropped on an empty slot lands last", names() == "Bravo,Charlie,Alpha", names())
  local charlie
  for _, e in ipairs(w.PR:CurrentProfile().spells) do if e.spellName == "Charlie" then charlie = e end end
  check("an After link survives the move", charlie and charlie.follows == "spell:1")
  cursorY = 1000 - 0 * 42 - 10          -- back over its own row
  ed:StartReorder(1); ed:FinishReorder()
  check("dropped where it started: nothing moves", names() == "Bravo,Charlie,Alpha", names())
  ed:StartReorder(5); ed:FinishReorder()
  check("an empty slot cannot be dragged", names() == "Bravo,Charlie,Alpha", names())
  local enabled = {}
  local row1 = ed.rows[1]
  row1.decBtn.SetEnabled = function(_, v) enabled.dec = v end
  row1.incBtn.SetEnabled = function(_, v) enabled.inc = v end
  w.PR:CurrentProfile().spells[1].freq = 1
  ed:Refresh()
  check("at 1, the down arrow is disabled", enabled.dec == false and enabled.inc == true)
  w.PR:CurrentProfile().spells[1].freq = 5
  ed:Refresh()
  check("at 5, the up arrow is disabled", enabled.inc == false and enabled.dec == true)
  end
end

-- WoW Forever has no Single-Button Assistant, so a new profile starts empty, even if the game named one; the
-- hand-picked starter lists are gone. DISCRIMINATION: VeritasUI v1.65.0 added the assistant whenever the game
-- named it.
out("P8) a new profile starts empty")
do
  local w = boot({ db = { enabled = true, profiles = {} }, sba = "available" })
  check("a new profile starts empty", #w.PR:CurrentProfile().spells == 0, #w.PR:CurrentProfile().spells)
  w.PR:CurrentProfile().spells[1] = { spellID = 1, spellName = "Alpha", icon = 101, freq = 1 }
  w.slash("reset")
  check("/pr reset empties it", #w.PR:CurrentProfile().spells == 0)
  local w3 = boot({ db = { enabled = true, profiles = {} }, sba = "available", profile = prof({ A(), B() }) })
  check("an existing profile is left as it is", #w3.PR:CurrentProfile().spells == 2)
  check("no starter lists left", w3.PR.STARTER_LISTS == nil)
end

-- v1.67.4 (owner, 2026-11-05): WoW Forever's one spec per class is named after the class, so the window read
-- "Hunter Hunter". DISCRIMINATION: v1.67.3 returns "Hunter Hunter" and "Unknown Spec" for 9b/9c.
out("P9) the window title: spec and class, or the class alone")
do
  local w = boot({ db = { enabled = true, profiles = {} } })
  _G.UnitClass = function() return "Hunter", "HUNTER" end
  _G.C_SpecializationInfo.GetSpecializationInfo = function() return 253, "Beast Mastery" end
  check("9a) a chosen spec: spec then class", w.PR:GetCurrentSpecLabel() == "Beast Mastery Hunter", w.PR:GetCurrentSpecLabel())
  _G.C_SpecializationInfo.GetSpecializationInfo = function() return 1485, "Hunter" end
  check("9b) a spec named like the class: the class once", w.PR:GetCurrentSpecLabel() == "Hunter", w.PR:GetCurrentSpecLabel())
  _G.C_SpecializationInfo.GetSpecialization = function() return nil end
  check("9c) no spec at all: the class", w.PR:GetCurrentSpecLabel() == "Hunter", w.PR:GetCurrentSpecLabel())
end

-- The header tabs switch pages; the Settings page keeps the Spellbook and Macros buttons and has no Reset to Spec
-- Defaults (a new profile starts empty) and no spec switcher (Forever has one specialization per class).
-- DISCRIMINATION: with ActivateTab not showing the picked page, 10b fails.
out("P10) header tabs and the Settings page")
do
  local w = boot({ db = nil, specs = 3 })
  local win = w.PR.MainWindow
  local tabs = win and win.tabs or {}
  if tabs[2] and tabs[2]._OnClick then tabs[2]._OnClick(tabs[2]) end
  check("10a) a click on Settings picks it", tabs[2] and tabs[2].picked == true and not tabs[1].picked)
  check("10b) and shows its page instead of Rotation's", win.pages.settings._shown == true
        and win.pages.editor._shown == false)
  local function has(t) for _, s in ipairs(w.texts) do if s == t then return true end end end
  check("10c) Create Macro, Spellbook and Macros on its footer", has("Create Macro") and has("Spellbook") and has("Macros"))
  check("10d) no Reset to Spec Defaults, no spec switcher", not has("Reset to Spec Defaults")
        and not has("Switch Specialization"))
  check("10e) the auto-target switch follows the spec's profile", win.reacqSwitch and win.reacqSwitch._on == false)
  local entry = _G.UIPanelWindows and _G.UIPanelWindows.PriorityRotMainWindow
  check("10f) pushable 2: sorted after Professions (1), before Character Info (3)", entry and entry.pushable == 2,
        entry and tostring(entry.pushable))
end

out("P12) a rotation press puts your weapons back after fishing (WoW Forever pole in the main hand)")
do
  local db = function() return { enabled = true, profiles = {} } end
  local function equip(w, mh, oh)
    w.hands[16], w.hands[17] = mh, oh
    w.fire("PLAYER_EQUIPMENT_CHANGED", 16); w.fire("PLAYER_EQUIPMENT_CHANGED", 17); w.runTimers()
  end
  local base = boot({ db = db(), profile = prof({ A(), B() }), hands = { [16] = 2131, [17] = 2129 } })
  local step1, step2 = base.press(), base.press()

  local w = boot({ db = db(), profile = prof({ A(), B() }), hands = { [16] = 2131, [17] = 2129 } })
  check("12a) no pole: the rotation is unchanged", w.press() == step1)
  w = boot({ db = db(), profile = prof({ A(), B() }), hands = { [16] = 2131, [17] = 2129 } })
  equip(w, 6256, nil)
  local first = w.press()
  check("12b) pole in hand: the press puts weapon and shield back",
        first == "/equipslot 16 Shortsword\n/equipslot 17 Large Round Shield", first)
  check("12c) …on every press until they are on", w.press() == first)
  equip(w, 2131, 2129)
  check("12d) weapons back: the rotation resumes at its first step (re-equip presses did not advance it)",
        w.press() == step1 and w.press() == step2)

  w = boot({ db = db(), profile = prof({ A() }), hands = { [16] = 1411 } })
  equip(w, 6256, nil)
  check("12e) a two-handed weapon: only the main hand is equipped", w.press() == "/equipslot 16 Withered Staff")

  w = boot({ db = db(), profile = prof({ A(), B() }), hands = { [16] = 6256 } })
  check("12f) pole already on at login (weapons unknown): the rotation runs as normal", w.press() == step1)

  -- DISCRIMINATION: SetSnippet without the combat check -> the Execute runs in combat; with no queue drain -> 12h fails.
  w = boot({ db = db(), profile = prof({ A(), B() }), hands = { [16] = 2131, [17] = 2129 } })
  _G.__inCombat = true
  local before = w.rotBtn._env.reequipText
  equip(w, 6256, nil)
  check("12g) a pole put on in combat is not armed until combat ends", before == nil and w.rotBtn._env.reequipText == nil)
  _G.__inCombat = false
  w.fire("PLAYER_REGEN_ENABLED"); w.runTimers()
  check("12h) …then it is", w.rotBtn._env.reequipText == "/equipslot 16 Shortsword\n/equipslot 17 Large Round Shield",
        w.rotBtn._env.reequipText)
end

-- Owner, 2026-11-12: a Warrior's shouts recast over and over, wasting rage. A spell whose buff is on you with more
-- than 30 s left is left out of the rotation, decided out of combat. DISCRIMINATION: without the BuffUp check in the
-- compile, 13b, 13c, 13g, 13i fail; without the combat queue in OnPlayerAura, 13g fails (never re-decided).
out("P13) a buff you already have is left out of the rotation")
do
  local db = function() return { enabled = true, profiles = {} } end
  local function has(w, name)
    for _, t in ipairs(w.PR.compiledSequence) do if t:find(name, 1, true) then return true end end
    return false
  end
  local function aura(w) w.fire("UNIT_AURA", "player"); w.runTimers() end
  local w = boot({ db = db(), profile = prof({ A(), B() }) })
  check("13a) no buff: the spell is in the rotation", has(w, "Alpha") and has(w, "Bravo"))
  w.auras.Alpha = { expirationTime = 0 }
  aura(w)
  check("13b) its buff on you (no end): left out", not has(w, "Alpha") and has(w, "Bravo"))
  w.auras.Alpha = { expirationTime = w.now + 100 }
  aura(w)
  check("13c) 100 s left: still left out", not has(w, "Alpha"))
  w.auras.Alpha = { expirationTime = w.now + 20 }
  aura(w)
  check("13d) 30 s or less left: back in, so a fight can refresh it", has(w, "Alpha"))
  w.auras.Alpha = nil
  aura(w)
  check("13e) buff gone: in", has(w, "Alpha"))
  w.auras.Alpha = { expirationTime = 0 }
  _G.__inCombat = true
  aura(w)
  check("13f) in combat: the rotation is not changed", has(w, "Alpha"))
  _G.__inCombat = false
  w.fire("PLAYER_REGEN_ENABLED"); w.runTimers()
  check("13g) combat ends: decided then", not has(w, "Alpha"))
  w.auras.Alpha = { expirationTime = w.now + 100 }
  aura(w)
  w.now = w.now + 75   -- 25 s left: the timer set at the 30 s mark fires
  w.runLater()
  check("13h) the 30 s mark brings it back without any aura change", has(w, "Alpha"))
  local m = boot({ db = db(), profile = prof({ A(), B() }), auras = { Alpha = { expirationTime = 0 } } })
  check("13i) buff already on at login: left out from the first compile", not has(m, "Alpha") and has(m, "Bravo"))
end

-- Owner, 2026-11-12 (experiment he chose): a fight that starts without the shout recast it at every turn with rage.
-- In combat a LONG buff's step gets PR.BUFF_FIGHT_TURNS turns per fight. DISCRIMINATION: without the cap loop in the
-- snippet 14b fails; without the reset after the fight 14d fails; capping short buffs too fails 14e.
out("P14) in combat, a long buff gets a few turns per fight")
do
  local db = function() return { enabled = true, profiles = {} } end
  local w = boot({ db = db(), profile = prof({ A(), B() }) })
  local function aura() w.fire("UNIT_AURA", "player"); w.runTimers() end
  w.auras.Alpha = { expirationTime = w.now + 120, duration = 120 }   -- seen once out of combat: a long buff
  aura()
  w.auras.Alpha = nil                                                -- then it fades: back in the rotation
  aura()
  local N = w.PR.BUFF_FIGHT_TURNS
  local function fight(presses)
    _G.__inCombat = true
    w.fire("PLAYER_REGEN_DISABLED")
    local alpha, bravo = 0, 0
    for _ = 1, presses do
      local t = w.press()
      if t:find("Alpha", 1, true) then alpha = alpha + 1 elseif t:find("Bravo", 1, true) then bravo = bravo + 1 end
    end
    return alpha, bravo
  end
  local outA = 0
  for _ = 1, 10 do if w.press():find("Alpha", 1, true) then outA = outA + 1 end end
  check("14a) out of combat the buff's turns are not counted or capped", outA == 5, outA)
  local alpha, bravo = fight(20)
  check("14b) in a fight: exactly " .. N .. " turns for the long buff", alpha == N, alpha)
  check("14c) …and every other press goes to the rest of the rotation", bravo == 20 - N, bravo)
  _G.__inCombat = false
  w.fire("PLAYER_REGEN_ENABLED"); w.runTimers()
  alpha = fight(20)
  check("14d) the next fight gets its " .. N .. " turns again", alpha == N, alpha)
  _G.__inCombat = false
  w.fire("PLAYER_REGEN_ENABLED"); w.runTimers()

  local s = boot({ db = db(), profile = prof({ A(), B() }) })
  s.cooldowns = { Alpha = 60 }                                       -- its spell is on cooldown while it lasts
  s.auras.Alpha = { expirationTime = s.now + 20, duration = 20 }     -- a short self-buff (a cooldown)
  s.fire("UNIT_AURA", "player"); s.runTimers()
  s.auras.Alpha = nil
  s.fire("UNIT_AURA", "player"); s.runTimers()
  _G.__inCombat = true
  s.fire("PLAYER_REGEN_DISABLED")
  local sa = 0
  for _ = 1, 20 do if s.press():find("Alpha", 1, true) then sa = sa + 1 end end
  check("14e) a short buff is never capped", sa == 10, sa)
  _G.__inCombat = false
  s.fire("PLAYER_REGEN_ENABLED"); s.runTimers()
end

----------------------------------------------------------------------------------------------
out("P15) the rotation's key follows the bar: a key rebound or the macro moved frees the old key (freshness)")
-- DISCRIMINATION: v1.88.2 scans only at compile/login/spec change -> 15a-15c fail. Mutations (expect red): drop the
-- two events (15a, 15b); drop the clear when the macro is off every bar (15c); drop the same-answer no-op (15d);
-- drop the after-combat queue (15f).
do
  local w = boot({ db = { enabled = true, profiles = {} }, profile = prof({ B() }),
                   macros = { { "Attack", 1, STUB } },
                   actions = { [5] = "Attack" }, bindings = { ACTIONBUTTON5 = "5" } })
  check("15-0 bound at login", w.overrides["5"] == "PRAttackButton")
  w.bindings.ACTIONBUTTON5 = "Q"                       -- the player rebinds the slot
  w.fire("UPDATE_BINDINGS"); w.runTimers()
  check("15a rebound: the new key is the rotation's, the old one is free", w.overrides["Q"] == "PRAttackButton"
        and w.overrides["5"] == nil)
  w.actions = { [6] = "Attack" }; w.bindings.ACTIONBUTTON6 = "6"   -- the macro moved to slot 6
  w.fire("ACTIONBAR_SLOT_CHANGED", 5); w.runTimers()
  check("15b moved: its new slot's key", w.overrides["6"] == "PRAttackButton" and w.overrides["Q"] == nil)
  w.actions = {}
  w.fire("ACTIONBAR_SLOT_CHANGED", 6); w.runTimers()
  check("15c off every bar: no key is the rotation's", next(w.overrides) == nil)
  w.actions = { [6] = "Attack" }
  w.fire("ACTIONBAR_SLOT_CHANGED", 6); w.runTimers()
  local sets = 0
  local real = _G.SetOverrideBindingClick
  _G.SetOverrideBindingClick = function(...) sets = sets + 1; return real(...) end
  w.fire("UPDATE_BINDINGS"); w.runTimers()             -- e.g. our own binding's event
  check("15d nothing changed: the binding is not set again (no event loop)", sets == 0, sets)
  _G.SetOverrideBindingClick = real
  _G.__inCombat = true
  w.bindings.ACTIONBUTTON6 = "R"
  w.fire("UPDATE_BINDINGS"); w.runTimers()
  check("15e in combat: nothing is changed", w.overrides["6"] == "PRAttackButton")
  _G.__inCombat = false
  w.fire("PLAYER_REGEN_ENABLED"); w.runTimers()
  check("15f after combat: the change is picked up", w.overrides["R"] == "PRAttackButton")
end

-- Owner, 2026-11-17 (Forever Paladin): Seal of Righteousness lasts 30 s, so it was never "more than 30 s left" and
-- never 60 s long -- recast at every turn like the shouts before v1.88.0. A short buff whose spell is ready while it
-- is on you is kept up by recasting: left out while up, back in at a third of its length, capped per fight.
-- DISCRIMINATION (v1.89.2): 16a, 16b, 16e fail (BUFF_SKIP_LEFT 30 only, BUFF_LONG 60 only). Mutation: drop the
-- secret check in ReadyWhileUp -> 16f fails.
out("P16) a seal (30 s, no cooldown) is treated like a shout")
do
  local db = function() return { enabled = true, profiles = {} } end
  local function has(w, name)
    for _, t in ipairs(w.PR.compiledSequence) do if t:find(name, 1, true) then return true end end
    return false
  end
  local w = boot({ db = db(), profile = prof({ A(), B() }) })
  local function aura() w.fire("UNIT_AURA", "player"); w.runTimers() end
  w.auras.Alpha = { expirationTime = w.now + 30, duration = 30 }    -- just cast
  aura()
  check("16a) seal just cast (30 s left): left out", not has(w, "Alpha") and has(w, "Bravo"))
  w.now = w.now + 15
  aura()
  check("16b) 15 s left: still left out", not has(w, "Alpha"))
  w.now = w.now + 6   -- 9 s left: the timer set at the 10 s mark fires
  w.runLater()
  check("16c) the 10 s mark brings it back without any aura change", has(w, "Alpha"))
  w.auras.Alpha = nil
  aura()
  check("16d) seal gone: in", has(w, "Alpha"))
  local N = w.PR.BUFF_FIGHT_TURNS
  _G.__inCombat = true
  w.fire("PLAYER_REGEN_DISABLED")
  local alpha = 0
  for _ = 1, 20 do if w.press():find("Alpha", 1, true) then alpha = alpha + 1 end end
  check("16e) in a fight it gets " .. N .. " turns, not every turn", alpha == N, alpha)
  _G.__inCombat = false
  w.fire("PLAYER_REGEN_ENABLED"); w.runTimers()

  local u = boot({ db = db(), profile = prof({ A(), B() }) })
  u.auras.Alpha = { expirationTime = u.now + 30, duration = 30, }
  local real = _G.issecretvalue
  _G.issecretvalue = function(v) return v == 0 end            -- the cooldown read is secret
  u.fire("UNIT_AURA", "player"); u.runTimers()
  _G.issecretvalue = real
  check("16f) an unreadable cooldown is not taken as ready", u.PR:CurrentProfile().spells[1].long ~= true)
end

-- Owner, 2026-11-17: Blizzard's Attack is a toggle, so /cast Attack at every turn switched auto-attack off again.
-- DISCRIMINATION (v1.89.2): 17a-17d fail (the entry compiles to /cast [nochanneling] Attack).
out("P17) the Attack spell only ever starts auto-attack")
do
  local db = function() return { enabled = true, profiles = {} } end
  local ATK = function(t) local e = { spellID = 6603, spellName = "Attack", icon = 105, freq = 1 }
    for k, v in pairs(t or {}) do e[k] = v end; return e end
  local w = boot({ db = db(), profile = prof({ ATK(), B() }) })
  local seq = table.concat(w.PR.compiledSequence, "\n")
  check("17a) Attack compiles to /startattack on a live enemy", seq:find("/startattack [nochanneling, harm, nodead]", 1, true) ~= nil, seq)
  check("17b) …and never to /cast Attack", not seq:find("/cast [nochanneling] Attack", 1, true), seq)
  w = boot({ db = db(), profile = prof({ ATK({ combatOnly = true }), B() }) })
  seq = table.concat(w.PR.compiledSequence, "\n")
  check("17c) Combat ticked: /startattack [combat, nochanneling, harm, nodead]",
        seq:find("/startattack [combat, nochanneling, harm, nodead]", 1, true) ~= nil, seq)
  w = boot({ db = db(), profile = prof({ ATK(), B() }) })
  w.PR:CurrentProfile().spells[1].spellID = nil
  w.PR:CompileSequence()
  seq = table.concat(w.PR.compiledSequence, "\n")
  check("17d) an entry saved by name only is recognised too", seq:find("/startattack", 1, true) ~= nil, seq)
  w = boot({ db = db(), profile = prof({ A(), B() }) })
  seq = table.concat(w.PR.compiledSequence, "\n")
  check("17e) other spells are unchanged", seq:find("/cast [nochanneling] Alpha", 1, true) ~= nil
        and not seq:find("/startattack", 1, true), seq)
end

-- 2026-11-25: Hide Error Text (ErrorText.lua). The chosen groups' types go on Blizzard's hidden list at this addon's
-- ADDON_LOADED, before DaylightUI claims every type at its PLAYER_LOGIN; the choices are copied from the options
-- page into the saved variables. DISCRIMINATION: with the ADDON_LOADED write moved to PLAYER_LOGIN, 18a fails;
-- with SaveErrorChoices dropped from the SettingChanged handler, 18d fails.
out("P18) Hide Error Text")
do
  local ERRS = { SPELL_FAILED_S = 57, SPELL_FAILED_SHAPESHIFT_FORM_S = 279, MAIL_DATABASE_ERROR = 460,
                 OUT_OF_RAGE = 359, INV_FULL = 3 }
  local calls, order = {}, {}
  local function setup()
    for k, v in pairs(ERRS) do _G["LE_GAME_ERR_" .. k] = v end
    calls, order = {}, {}
    _G.UIErrorsFrame = { SetMessageTypeEnabled = function(_, t, en) calls[t] = en; order[#order + 1] = t end }
  end
  setup()
  local atLoad = {}
  _G.__afterAddonLoaded = function() for t, v in pairs(calls) do atLoad[t] = v end end
  local w = boot({ db = { enabled = true, profiles = {}, hiddenErrors = { spells = true } } })
  _G.__afterAddonLoaded = nil
  check("18a) chosen at the last session: its types hidden at load, before any login", atLoad[57] == false
        and atLoad[279] == false and atLoad[359] == false)
  check("18b) groups not chosen are left alone", calls[460] == nil and calls[3] == nil)
  local onlyFalse = true
  for _, v in pairs(calls) do if v ~= false then onlyFalse = false end end
  check("18c) only ever writes hide", onlyFalse)
  SetOption("hideErrors_mail", true)
  check("18d) a change on the options page is kept for the next load", w.PR.db.hiddenErrors.mail == true
        and w.PR.db.hiddenErrors.spells == nil)
  local mod = _G.__duiModules.PriorityRotationDUI
  local page
  for _, p in ipairs(mod and mod.options.pages or {}) do if p.id == "errors" then page = p end end
  local rows = page and page.groups[1].items or {}
  local allReload = #rows == 6
  for _, r in ipairs(rows) do if r.type ~= "toggle" or not r.reload or mod.defaults[r.key] ~= false then allReload = false end end
  check("18e) an Error Messages page: six switches, off to start, each saying it takes a /reload", allReload, #rows)
  setup()
  boot({ db = { enabled = true, profiles = {} } })
  check("18f) nothing chosen: nothing written", next(calls) == nil)
  _G.UIErrorsFrame = nil
end

-- 2026-11-25: Mute Sounds (Sounds.lua). Chosen groups are muted at login and at once on a change; a group is only
-- unmuted after this addon muted it. DISCRIMINATION: with ApplySoundMutes dropped from OnEnable, 19a fails; from
-- the SettingChanged handler, 19c fails; with the `muted[g.id]` check dropped from the unmute branch, 19b fails.
out("P19) Mute Sounds")
do
  local muted, unmuted = {}, {}
  _G.MuteSoundFile = function(id) muted[id] = (muted[id] or 0) + 1 end
  _G.UnmuteSoundFile = function(id) unmuted[id] = (unmuted[id] or 0) + 1 end
  local w = boot({ db = { enabled = true, profiles = {} }, settings = { muteSound_fizzle = true } })
  check("19a) chosen groups muted at login", muted[569772] == 1 and muted[569776] == 1 and muted[562388] == nil)
  check("19b) nothing unmuted that this addon never muted", next(unmuted) == nil)
  SetOption("muteSound_yawns", true)
  check("19c) switched on: muted at once", muted[562388] == 1)
  SetOption("muteSound_fizzle", false)
  check("19d) switched off: unmuted at once, its own mutes only", unmuted[569772] == 1 and unmuted[562388] == nil)
  SetOption("muteSound_yawns", true)
  check("19e) switched on again while on: not muted twice", muted[562388] == 1)
  local mod = _G.__duiModules.PriorityRotationDUI
  local page
  for _, p in ipairs(mod and mod.options.pages or {}) do if p.id == "sounds" then page = p end end
  check("19f) a Sounds page: nine switches, off to start", page and #page.groups[1].items == 9
        and mod.defaults.muteSound_chimes == false)
  _G.MuteSoundFile, _G.UnmuteSoundFile = nil, nil
  local _ = w
end

-- 2026-11-25: Auto Equip on the Gear page (its decisions: autoequip_test). DISCRIMINATION: with the qualities'
-- `disabled` dropped, 20b fails; with the equipcheck branch gone from /pr, 20d fails.
out("P20) Auto Equip on the Gear page")
do
  local w = boot({ db = { enabled = true, profiles = {} } })
  local mod = _G.__duiModules.PriorityRotationDUI
  local page
  for _, p in ipairs(mod and mod.options.pages or {}) do if p.id == "gear" then page = p end end
  local rows = page and page.groups[1].items or {}
  check("20a) the switch, then a row per quality; off, with Poor and Common chosen", #rows == 7
        and rows[1].key == "autoEquip" and mod.defaults.autoEquip == false and mod.defaults.autoEquipPoor == true
        and mod.defaults.autoEquipCommon == true and mod.defaults.autoEquipUncommon == false, #rows)
  local get = function(k) return _G.__duiSettings[k] end
  check("20b) the qualities are greyed while it is off", rows[2] and rows[2].disabled and rows[2].disabled(get) == true)
  _G.__duiSettings.autoEquip = true
  check("20c) and usable once it is on", rows[2] and rows[2].disabled(get) == false)
  local ran = false
  w.PR.EquipCheck = function() ran = true end
  w.slash("equipcheck")
  check("20d) /pr equipcheck runs the check", ran)
end

out(("=== %d passed, %d failed ==="):format(pass, fail))
