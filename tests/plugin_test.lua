-- plugin_test -- Plugin.lua: registers with DaylightUI through its public API only, and stays off beside
-- VeritasUI's own Priority Rotation after copying its spell lists over once.
-- DISCRIMINATION: with no RegisterPlugin call, or one without `needs`, 1-2 fail; with the major guard removed, 3
-- fails; with the VeritasUI check removed, 4 fails; with HasLists(_G.DaylightPriorityRotationDB) dropped from
-- ImportFromVeritasUI, 7 fails.

local out = print
local pass, fail = 0, 0
local function check(name, ok, detail)
  if ok then pass = pass + 1; out("  PASS  " .. name)
  else fail = fail + 1; out("  FAIL  " .. name .. (detail and ("  -> " .. tostring(detail)) or "")) end
end

local ROOT = arg and arg[1] or "DaylightPriorityRotation"

local function boot(major, veritasLoaded)
  local plugins, events, said = {}, {}, {}
  _G.DaylightUI = {
    API = { major = major, minor = 16, For = function(name) return { name = name } end },
    RegisterPlugin = function(_, name, opts) plugins[#plugins + 1] = { name = name, opts = opts } end,
  }
  _G.C_AddOns = { IsAddOnLoaded = function(n) return veritasLoaded and n == "VeritasUI_PriorityRotation" end }
  _G.CreateFrame = function()
    return { RegisterEvent = function(_, e) events[e] = true end, UnregisterAllEvents = function() end,
             SetScript = function(self, _, fn) self.fn = fn; events.frame = self end }
  end
  _G.print = function(s) said[#said + 1] = tostring(s) end
  local ns = {}
  assert(loadfile(ROOT .. "/Plugin.lua"))("DaylightPriorityRotation", ns)
  _G.print = out
  return plugins, ns, events, said
end

out("1) registration")
do
  local plugins, ns = boot(1, false)
  check("1 one plugin, named after the folder", #plugins == 1 and plugins[1].name == "DaylightPriorityRotation")
  check("2 it states the API version it needs and hands the API on", type(plugins[1] and plugins[1].opts.needs) == "table"
    and plugins[1].opts.needs[1] == 1 and ns.API == _G.DaylightUI.API)
end
do
  local plugins, ns = boot(2, false)
  check("3 another API major: nothing registered, the other files stop", #plugins == 0 and ns.API == nil)
end

out("2) beside VeritasUI's Priority Rotation")
do
  local lists = { profiles = { ["R-N-1"] = { spells = { { spellID = 1, spellName = "Alpha" } } } }, enabled = true }
  _G.VeritasUI_PriorityRotationDB = lists
  _G.DaylightPriorityRotationDB = nil
  local plugins, ns, events, said = boot(1, true)
  check("4 stays off: no plugin registered, the other files stop", #plugins == 0 and ns.API == nil)
  _G.print = function(s) said[#said + 1] = tostring(s) end
  events.frame.fn(events.frame, "ADDON_LOADED", "DaylightPriorityRotation")
  _G.print = out
  local copied = _G.DaylightPriorityRotationDB
  check("5 its spell lists are copied over", copied and copied.profiles["R-N-1"].spells[1].spellName == "Alpha"
    and copied ~= lists and copied.profiles ~= lists.profiles)
  check("6 and chat says so, and what to turn off", said[1] and said[1]:find("copied over", 1, true)
    and said[1]:find("Turn off VeritasUI", 1, true), said[1])
  _G.DaylightPriorityRotationDB = { profiles = { ["R-N-1"] = { spells = { { spellID = 2, spellName = "Bravo" } } } } }
  local _, _, events2 = boot(1, true)
  events2.frame.fn(events2.frame, "ADDON_LOADED", "DaylightPriorityRotation")
  check("7 lists of its own are never replaced", _G.DaylightPriorityRotationDB.profiles["R-N-1"].spells[1].spellName == "Bravo")
  _G.VeritasUI_PriorityRotationDB, _G.DaylightPriorityRotationDB = nil, nil
end

out(("=== %d passed, %d failed ==="):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
