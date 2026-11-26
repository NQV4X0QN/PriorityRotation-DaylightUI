-- core_test -- Core.lua registers with DaylightUI through its public API only.
-- DISCRIMINATION: with no RegisterPlugin call, or one without `needs`, 1 and 2 fail; with the major
-- guard removed, 4 fails.

local out = print
local pass, fail = 0, 0
local function check(name, ok, detail)
  if ok then pass = pass + 1; out("  PASS  " .. name)
  else fail = fail + 1; out("  FAIL  " .. name .. (detail and ("  -> " .. tostring(detail)) or "")) end
end

local ROOT = arg and arg[1] or "PriorityRotationDUI"

local function boot(major)
  local plugins, modules = {}, {}
  _G.DaylightUI = {
    API = { major = major, minor = 16, For = function(name) return { name = name } end },
    RegisterPlugin = function(_, name, opts) plugins[#plugins + 1] = { name = name, opts = opts } end,
    RegisterModule = function(_, name, def) modules[#modules + 1] = { name = name, def = def } end,
  }
  local ns = {}
  local chunk = assert(loadfile(ROOT .. "/Core.lua"))
  chunk("PriorityRotationDUI", ns)
  return plugins, modules, ns
end

out("1) registration")
do
  local plugins, modules = boot(1)
  check("1 one plugin, named after the folder", #plugins == 1 and plugins[1].name == "PriorityRotationDUI")
  check("2 it states the API version it needs", type(plugins[1] and plugins[1].opts.needs) == "table"
    and plugins[1].opts.needs[1] == 1)
  local m = modules[1]
  check("3 one module, tied to the plugin, with an options page",
    #modules == 1 and m.def.plugin == "PriorityRotationDUI" and type(m.def.options.pages[1]) == "table")
end
do
  local plugins, modules = boot(2)
  check("4 another API major: nothing registered", #plugins == 0 and #modules == 0)
end

out(("=== %d passed, %d failed ==="):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
