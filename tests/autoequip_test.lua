-- autoequip_test -- Auto Equip Upgrades decision, VeritasUI's qol_autoequip_test carried over (owner's request
-- 2026-11-04). This plugin is WoW Forever only, so the class decides the main stat throughout (a Hunter: Agility).
-- Loads the REAL AutoEquip.lua with stubbed bags, items, tooltips and worn gear, runs the probe and reads its lines.
--  1. Grey leather chest over worn cloth chest of lower item level: would equip (the owner's Forever case).
--  2. A red tooltip line (can't use) is skipped and the line is quoted -- right side (armor type, v1.67.3) and left.
--  3. Lighter armor than what is worn is skipped.
--  4. Green quality is skipped by default; ticking Uncommon allows it.
--  5. A Bind on Equip item not yet bound is skipped.
--  6. An Intellect item for an Agility spec is skipped; an item with no main stat passes.
--  7. Empty slot: anything usable goes in. Trinkets are left alone. Weapons only like for like.
--  8. Nothing is equipped by the probe.
--  10. Equipping: one per pass, combat wait, 5 s retry guard; named in chat only once the slot holds it (v1.67.3).
--  11. Profession tools (v1.67.1).
--  12. Equal item level: better quality, then more armor (stats, else tooltip) (v1.67.3).

dofile("tests/stub.lua")
local out = print
local pass, fail = 0, 0
local function ok(name, cond, extra)
  if cond then pass = pass + 1; out("  PASS  " .. name)
  else fail = fail + 1; out("  FAIL  " .. name .. (extra and ("  -> " .. tostring(extra)) or "")) end
end

-- items: link -> { equipLoc, classID, subclassID, ilvl, stats, bind, red }
local ITEMS = {
  greyLeatherChest = { "INVTYPE_CHEST", 4, 2, 5 },
  clothChestWorn   = { "INVTYPE_CHEST", 4, 1, 2 },
  mailLegs         = { "INVTYPE_LEGS", 4, 3, 9, redRight = { "Mail" } },   -- v1.67.3: armor type is on the right
  lvlCloak         = { "INVTYPE_CLOAK", 4, 1, 9, red = { "Requires Level 10" } },
  clothLegs        = { "INVTYPE_LEGS", 4, 1, 9 },
  leatherLegsWorn  = { "INVTYPE_LEGS", 4, 2, 3 },
  greenBoots       = { "INVTYPE_FEET", 4, 2, 8 },
  boeGloves        = { "INVTYPE_HAND", 4, 2, 8, bind = 2 },
  intBracers       = { "INVTYPE_WRIST", 4, 2, 8, stats = { ITEM_MOD_INTELLECT_SHORT = 3 } },
  agiBracersWorn   = { "INVTYPE_WRIST", 4, 2, 4, stats = { ITEM_MOD_AGILITY_SHORT = 1 } },   -- 8 is under the 9 needed
  agiBelt          = { "INVTYPE_WAIST", 4, 2, 8, stats = { ITEM_MOD_AGILITY_SHORT = 3 } },
  trinket          = { "INVTYPE_TRINKET", 4, 0, 30 },
  bow              = { "INVTYPE_RANGED", 2, 2, 10 },
  bowWorn          = { "INVTYPE_RANGED", 2, 2, 4 },
  sword2h          = { "INVTYPE_2HWEAPON", 2, 8, 12 },
  -- v1.67.1 (owner): WoW Forever's tools are Miscellaneous weapons (subclass 14), the Fishing Pole subclass 20.
  skinningKnife    = { "INVTYPE_WEAPON", 2, 14, 5 },
  shortsword       = { "INVTYPE_WEAPON", 2, 7, 4 },
  fishingPole      = { "INVTYPE_2HWEAPON", 2, 20, 9 },
  potion           = { nil },
}
local BAG = {
  { link = "greyLeatherChest", quality = 0 }, { link = "mailLegs", quality = 0 }, { link = "clothLegs", quality = 1 },
  { link = "greenBoots", quality = 2 }, { link = "boeGloves", quality = 1 }, { link = "intBracers", quality = 1 },
  { link = "agiBelt", quality = 1 }, { link = "trinket", quality = 1 }, { link = "bow", quality = 1 },
  { link = "sword2h", quality = 1 }, { link = "potion", quality = 1 }, { link = "lvlCloak", quality = 1 },
}
local WORN = { [5] = "clothChestWorn", [7] = "leatherLegsWorn", [16] = "bowWorn", [9] = "agiBracersWorn" }
local equipped = 0

_G.C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and #BAG or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local b = bag == 0 and BAG[slot]; if not b then return nil end
    return { hyperlink = b.link, quality = b.quality, isBound = false }
  end,
}
_G.C_Item = {
  IsEquippableItem = function(link) return ITEMS[link] and ITEMS[link][1] ~= nil end,
  GetItemInfoInstant = function(link) local i = ITEMS[link]; return 1, nil, nil, i[1], nil, i[2], i[3] end,
  GetDetailedItemLevelInfo = function(link) return ITEMS[link] and ITEMS[link][4] end,
  GetItemStats = function(link) return ITEMS[link] and ITEMS[link].stats or {} end,
  GetItemInfo = function(link)
    local i = ITEMS[link]; return link, link, 1, 1, 1, "", "", 1, i[1], 0, 0, i[2], i[3], i.bind or 0
  end,
  EquipItemByName = function() equipped = equipped + 1 end,
}
local function tipLines(link)
  local i = ITEMS[link]; local lines = { { leftText = link, leftColor = { r = 1, g = 1, b = 1 } } }
  for _, t in ipairs(i.red or {}) do lines[#lines + 1] = { leftText = t, leftColor = { r = 1, g = 0.125, b = 0.125 } } end
  for _, t in ipairs(i.redRight or {}) do
    lines[#lines + 1] = { leftText = "Legs", leftColor = { r = 1, g = 1, b = 1 },
                          rightText = t, rightColor = { r = 1, g = 0.125, b = 0.125 } }
  end
  if i.tipArmor then lines[#lines + 1] = { leftText = i.tipArmor .. " Armor", leftColor = { r = 1, g = 1, b = 1 } } end
  return { lines = lines }
end
_G.ARMOR_TEMPLATE = "%s Armor"
_G.C_TooltipInfo = {
  GetBagItem = function(bag, slot) return tipLines(BAG[slot].link) end,
  GetInventoryItem = function(_, slot) return WORN[slot] and tipLines(WORN[slot]) end,
}
local WORN_Q = {}
_G.GetInventoryItemQuality = function(_, slot) return WORN_Q[slot] end
_G.C_SpecializationInfo = { GetSpecialization = function() return 1 end,
  GetSpecializationInfo = function() return 253, "Beast Mastery", "", 1, "DAMAGER", 2 end }   -- Agility
_G.GetInventoryItemLink = function(_, slot) return WORN[slot] end
_G.GetTime = function() return _G.__now or 100 end
_G.EquipItemByName, _G.PickupContainerItem, _G.EquipCursorItem = _G.C_Item.EquipItemByName, nil, nil

local lines = {}
local PR = { VUI = { IS_FOREVER = true, Print = function(_, msg) lines[#lines + 1] = msg end } }
PR.GetOption = function(k) return _G.__aedb and _G.__aedb[k] end
_G.UnitClass = function() return "Hunter", "HUNTER" end
assert(loadfile("PriorityRotationDUI/AutoEquip.lua"))("PriorityRotationDUI", PR)
local function run() lines = {}; PR.EquipCheck() end
local function line(name) for _, l in ipairs(lines) do if l:find(name, 1, true) then return l end end end

_G.__aedb = { autoEquip = false, autoEquipPoor = true, autoEquipCommon = true }
local db = _G.__aedb
run()
ok("1) grey leather chest over cloth: would equip in the chest slot", (line("greyLeatherChest") or ""):find("WOULD EQUIP in slot 5", 1, true), line("greyLeatherChest"))
ok("2) a red RIGHT-side line (armor type) is skipped and quoted", (line("mailLegs") or ""):find("can't use: Mail", 1, true), line("mailLegs"))
ok("2b) a red left-side line (level) is skipped and quoted", (line("lvlCloak") or ""):find("can't use: Requires Level 10", 1, true), line("lvlCloak"))
ok("3) lighter armor than worn is skipped", (line("clothLegs") or ""):find("lighter armor", 1, true), line("clothLegs"))
ok("4) green skipped by default", (line("greenBoots") or ""):find("not chosen", 1, true), line("greenBoots"))
ok("5) Bind on Equip skipped", (line("boeGloves") or ""):find("binds when equipped", 1, true), line("boeGloves"))
ok("6) wrong main stat skipped when what you wear has yours", (line("intBracers") or ""):find("what you wear has yours", 1, true), line("intBracers"))
ok("6b) the spec's main stat into an empty slot", (line("agiBelt") or ""):find("WOULD EQUIP in slot 6", 1, true), line("agiBelt"))
ok("7) trinkets left alone", (line("trinket") or ""):find("left alone", 1, true), line("trinket"))
ok("7b) ranged replaces the worn ranged weapon", (line("bow") or ""):find("WOULD EQUIP in slot 16", 1, true), line("bow"))
ok("7c) no worn two-hander: the sword is not equipped", (line("sword2h") or ""):find("same kind", 1, true), line("sword2h"))
ok("7d) not gear: not listed", line("potion") == nil)
ok("8) the probe equips nothing", equipped == 0, equipped)
db.autoEquipUncommon = true
run()
ok("4b) Uncommon ticked: the green boots go in", (line("greenBoots") or ""):find("WOULD EQUIP in slot 8", 1, true), line("greenBoots"))
db.autoEquipUncommon = false

-- v1.67.0: WoW Forever reported Intellect as a Hunter's spec stat (owner's probe), so there the class decides.
-- DISCRIMINATION: with the spec's stat, the Agility belt is refused for a Forever Hunter.
_G.UnitClass = function() return "Hunter", "HUNTER" end
_G.C_SpecializationInfo.GetSpecializationInfo = function() return 1485, "Hunter", "", 1, "DAMAGER", 4 end
run()
ok("9) Forever Hunter: Agility from the class, not the spec's Intellect", (line("agiBelt") or ""):find("WOULD EQUIP", 1, true)
   and (line("intBracers") or ""):find("main stat", 1, true), line("agiBelt"))
_G.UnitClass = function() return "Druid", "DRUID" end
run()
ok("9b) Forever hybrid: no main-stat check", (line("intBracers") or ""):find("WOULD EQUIP", 1, true), line("intBracers"))
_G.UnitClass = function() return "Hunter", "HUNTER" end
_G.C_SpecializationInfo.GetSpecializationInfo = function() return 253, "Beast Mastery", "", 1, "DAMAGER", 2 end

out("10) equipping")
local ev
for _, f in ipairs(_G.__evframes["BAG_UPDATE_DELAYED"] or {}) do ev = f end
local calls = {}
_G.C_Item.EquipItemByName = function(link, slot) calls[#calls + 1] = { link, slot } end
local timers = {}
_G.C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local function flush() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
lines = {}
ev._OnEvent(ev, "BAG_UPDATE_DELAYED")
ok("off: nothing equipped", #calls == 0, #calls)
db.autoEquip = true
ev._OnEvent(ev, "BAG_UPDATE_DELAYED")
ok("on: one upgrade per pass, the first in the bags", #calls == 1 and calls[1][1] == "greyLeatherChest" and calls[1][2] == 5,
   calls[1] and calls[1][1])
ok("not named before the swap is seen", #lines == 0, lines[1])
WORN[5] = "greyLeatherChest"; table.remove(BAG, 1)                 -- the swap happened: the next pass moves on
flush()
ok("named in chat once the slot holds it", (lines[1] or ""):find("Equipped greyLeatherChest", 1, true), lines[1])
ev._OnEvent(ev, "BAG_UPDATE_DELAYED")
ok("the next bag update takes the next upgrade", #calls == 2 and calls[2][1] == "agiBelt" and calls[2][2] == 6,
   calls[2] and calls[2][1])
_G.__inCombat = true
ev._OnEvent(ev, "BAG_UPDATE_DELAYED")
ok("in combat: waits", #calls == 2, #calls)
_G.__inCombat = false
ev._OnEvent(ev, "PLAYER_REGEN_ENABLED")
ok("combat ends: the waiting pass runs", #calls == 3, #calls)
local n = #calls
ev._OnEvent(ev, "BAG_UPDATE_DELAYED")
ok("a swap the game did not make is not retried within 5 s", #calls == n, #calls)
-- v1.67.3 (owner, 2026-11-05): "Equipped [Flimsy Chain Pants]" printed while the game refused the pants.
-- DISCRIMINATION: v1.67.2 printed at the call, so lines is not empty here.
flush()
_G.__now = 200
lines = {}
ev._OnEvent(ev, "BAG_UPDATE_DELAYED")
ok("(a pass ran that the game will refuse)", #calls == n + 1, #calls)
flush()
ok("a swap the game refused is never named in chat", #lines == 0, lines[1])
_G.__now = nil

-- v1.67.1 (owner, 2026-11-04): a Skinning Knife replaced his Shortsword, and Raptor Strike needs a real weapon.
-- DISCRIMINATION: v1.67.0 equipped the knife (item level 5 over 4) and kept it over the sword, so 11 and 11c fail there.
out("11) profession tools")
for k in pairs(WORN) do WORN[k] = nil end
for i = #BAG, 1, -1 do BAG[i] = nil end
WORN[16] = "shortsword"
BAG[1] = { link = "skinningKnife", quality = 1 }
BAG[2] = { link = "fishingPole", quality = 1 }
run()
ok("11) a Skinning Knife never replaces a weapon", (line("skinningKnife") or ""):find("profession tool", 1, true),
   line("skinningKnife"))
ok("11b) nor does a Fishing Pole", (line("fishingPole") or ""):find("profession tool", 1, true), line("fishingPole"))
WORN[16] = "skinningKnife"
BAG[1] = { link = "shortsword", quality = 1 }
BAG[2] = nil
run()
ok("11c) a real weapon replaces a worn tool, whatever its item level",
   (line("shortsword") or ""):find("WOULD EQUIP in slot 16", 1, true), line("shortsword"))
-- 2026-11-12 (owner): a Fishing Pole is worn on purpose; Priority Rotation's key puts the weapons back. A two-handed
-- weapon (same kind as the pole) must not be swapped in while fishing. DISCRIMINATION: v1.86.1 says "replaces a
-- profession tool" -> 11d fails.
WORN[16] = "fishingPole"
BAG[1] = { link = "sword2h", quality = 1 }
run()
ok("11d) a worn Fishing Pole is never swapped out", (line("sword2h") or ""):find("you are fishing", 1, true),
   line("sword2h"))

-- v1.67.3 (owner, 2026-11-05): Thendal Ranger's Belt (white, 19 armor) stayed behind Ragged Leather Belt (grey, 18
-- armor), both item level 5. DISCRIMINATION: v1.67.2 says "item level 5 is not over 5" for 12, 12b and 12c.
out("12) equal item level")
for k in pairs(WORN) do WORN[k] = nil end
for i = #BAG, 1, -1 do BAG[i] = nil end
ITEMS.raggedBelt   = { "INVTYPE_WAIST", 4, 2, 5, stats = { RESISTANCE0_NAME = 18 } }
ITEMS.thendalBelt  = { "INVTYPE_WAIST", 4, 2, 5, stats = { RESISTANCE0_NAME = 19 } }
ITEMS.greyBelt19   = { "INVTYPE_WAIST", 4, 2, 5, stats = { RESISTANCE0_NAME = 19 } }
ITEMS.greyBelt18   = { "INVTYPE_WAIST", 4, 2, 5, stats = { RESISTANCE0_NAME = 18 } }
ITEMS.tipBoots     = { "INVTYPE_FEET", 4, 2, 3, tipArmor = 12 }
ITEMS.tipBootsWorn = { "INVTYPE_FEET", 4, 2, 3, tipArmor = 10 }
WORN[6], WORN_Q[6] = "raggedBelt", 0
BAG[1] = { link = "thendalBelt", quality = 1 }
run()
ok("12) better quality wins at equal item level", (line("thendalBelt") or ""):find("WOULD EQUIP in slot 6", 1, true),
   line("thendalBelt"))
BAG[1] = { link = "greyBelt19", quality = 0 }
run()
ok("12b) same quality: more armor wins (from stats)", (line("greyBelt19") or ""):find("WOULD EQUIP in slot 6", 1, true),
   line("greyBelt19"))
BAG[1] = { link = "greyBelt18", quality = 0 }
run()
ok("12d) same quality, same armor: left alone", (line("greyBelt18") or ""):find("skip", 1, true), line("greyBelt18"))
WORN[6], WORN_Q[6] = "thendalBelt", 1
BAG[1] = { link = "greyBelt19", quality = 0 }
run()
ok("12e) lower quality is left alone, even with equal armor", (line("greyBelt19") or ""):find("lower quality", 1, true),
   line("greyBelt19"))
WORN[8], WORN_Q[8] = "tipBootsWorn", 0
BAG[1] = { link = "tipBoots", quality = 0 }
run()
ok("12c) armor read from the tooltip when the stats lack it", (line("tipBoots") or ""):find("WOULD EQUIP in slot 8", 1, true)
   and (line("tipBoots") or ""):find("12 vs 10", 1, true), line("tipBoots"))

-- v1.69.2 (owner, 2026-11-05, WoW Forever): Hunter's Simple Cloak (item level 8, 8 Armor, +1 Stamina) kept being
-- swapped back to Handstitched Leather Cloak (item level 9, 8 Armor). Stats first: as much of every stat and more of
-- one wins either way round, whatever the item levels. DISCRIMINATION: v1.69.1 decides by item level -> 13 and 13b fail.
out("13) stats before item level")
for k in pairs(WORN) do WORN[k] = nil end
for k in pairs(WORN_Q) do WORN_Q[k] = nil end
for i = #BAG, 1, -1 do BAG[i] = nil end
ITEMS.simpleCloak  = { "INVTYPE_CLOAK", 4, 1, 8, stats = { RESISTANCE0_NAME = 8, ITEM_MOD_STAMINA_SHORT = 1 } }
ITEMS.stitchCloak  = { "INVTYPE_CLOAK", 4, 1, 9, stats = { RESISTANCE0_NAME = 8 } }
ITEMS.armorCloak   = { "INVTYPE_CLOAK", 4, 1, 10, stats = { RESISTANCE0_NAME = 12 } }
ITEMS.intCloak     = { "INVTYPE_CLOAK", 4, 1, 7, stats = { RESISTANCE0_NAME = 8, ITEM_MOD_INTELLECT_SHORT = 2 } }
WORN[15], WORN_Q[15] = "stitchCloak", 1
BAG[1] = { link = "simpleCloak", quality = 2 }
db.autoEquipUncommon = true
run()
ok("13) the owner's case: +1 Stamina at the same armor wins at a lower item level",
   (line("simpleCloak") or ""):find("WOULD EQUIP in slot 15", 1, true), line("simpleCloak"))
WORN[15], WORN_Q[15] = "simpleCloak", 2
BAG[1] = { link = "stitchCloak", quality = 1 }
run()
ok("13b) and the higher item level cloak with less never swaps it back",
   not (line("stitchCloak") or ""):find("WOULD EQUIP", 1, true) and (line("stitchCloak") or ""):find("less", 1, true),
   line("stitchCloak"))
BAG[1] = { link = "armorCloak", quality = 1 }
run()
ok("13c) a trade-off (more armor, no Stamina) falls back to item level", (line("armorCloak") or ""):find("item level 10 over 8", 1, true),
   line("armorCloak"))
WORN[15], WORN_Q[15] = "intCloak", 1
BAG[1] = { link = "stitchCloak", quality = 1 }
run()
ok("13d) a main stat that is not yours (Intellect on an Agility spec) does not count",
   (line("stitchCloak") or ""):find("item level 9 over 7", 1, true), line("stitchCloak"))
db.autoEquipUncommon = false

-- v1.77.2 (owner, 2026-11-07, WoW Forever Hunter): Empyrean Treads (green, item level 15, 48 Armor, +3 Intellect)
-- stayed in the bags behind Handstitched Leather Boots (white, item level 8, 31 Armor, no stat): "nothing but
-- upside". A wrong main stat only stops the swap when the worn item has YOUR main stat.
-- DISCRIMINATION: v1.77.1 says "main stat is not yours" for 14, 14c and 14e.
out("14) a main stat that is not yours")
for k in pairs(WORN) do WORN[k] = nil end
for k in pairs(WORN_Q) do WORN_Q[k] = nil end
for i = #BAG, 1, -1 do BAG[i] = nil end
db.autoEquipUncommon = true
ITEMS.empyrean   = { "INVTYPE_FEET", 4, 2, 15, stats = { RESISTANCE0_NAME = 48, ITEM_MOD_INTELLECT_SHORT = 3 } }
ITEMS.stitchBoot = { "INVTYPE_FEET", 4, 2, 8, stats = { RESISTANCE0_NAME = 31 } }
ITEMS.agiBoot    = { "INVTYPE_FEET", 4, 2, 12, stats = { RESISTANCE0_NAME = 40, ITEM_MOD_AGILITY_SHORT = 2 } }
ITEMS.strBoot    = { "INVTYPE_FEET", 4, 2, 9, stats = { RESISTANCE0_NAME = 30, ITEM_MOD_STRENGTH_SHORT = 2 } }
ITEMS.bigBoot    = { "INVTYPE_FEET", 4, 2, 9, stats = { RESISTANCE0_NAME = 60 } }
ITEMS.intBow     = { "INVTYPE_RANGED", 2, 2, 20, stats = { ITEM_MOD_INTELLECT_SHORT = 3 } }
ITEMS.agiBow     = { "INVTYPE_RANGED", 2, 2, 18, stats = { ITEM_MOD_AGILITY_SHORT = 1 } }   -- 20 is under the 23 needed
WORN[8], WORN_Q[8] = "stitchBoot", 1
BAG[1] = { link = "empyrean", quality = 2 }
run()
ok("14) the owner's case: off-stat boots with more armor replace boots with no stat",
   (line("empyrean") or ""):find("WOULD EQUIP in slot 8", 1, true), line("empyrean"))
WORN[8], WORN_Q[8] = "agiBoot", 1
run()
ok("14b) but never boots that carry your main stat",
   (line("empyrean") or ""):find("what you wear has yours", 1, true), line("empyrean"))
WORN[8], WORN_Q[8] = "strBoot", 1
run()
ok("14c) worn boots with another wrong stat count as having none of yours",
   (line("empyrean") or ""):find("WOULD EQUIP in slot 8", 1, true), line("empyrean"))
WORN[8], WORN_Q[8] = "bigBoot", 1
run()
ok("14d) the wrong stat buys nothing: more worn armor still keeps the worn boots",
   (line("empyrean") or ""):find("skip", 1, true) and (line("empyrean") or ""):find("less", 1, true), line("empyrean"))
WORN[8] = nil
run()
ok("14e) an empty slot takes off-stat gear", (line("empyrean") or ""):find("WOULD EQUIP in slot 8", 1, true), line("empyrean"))
BAG[1] = { link = "intBow", quality = 1 }
WORN[16] = "agiBow"
run()
ok("14f) weapons too: an off-stat weapon never replaces one with your main stat",
   (line("intBow") or ""):find("what you wear has yours", 1, true), line("intBow"))
db.autoEquipUncommon = false

-- v1.77.2 (owner, 2026-11-07): worn Agility boots (item level 15, 48 Armor, +3 Agility) vs Intellect boots (item level
-- 32, 115 Armor, +6 Intellect) -- +3 Agility should not win. Past 5 item levels or 25% above the worn item (whichever
-- is more) the comparison decides, with your Agility counted. DISCRIMINATION: without the gap, 15, 15c, 15e and 15g
-- say "what you wear has yours".
out("15) item-level gap over gear with your main stat")
for k in pairs(WORN) do WORN[k] = nil end
for k in pairs(WORN_Q) do WORN_Q[k] = nil end
for i = #BAG, 1, -1 do BAG[i] = nil end
db.autoEquipUncommon = true
ITEMS.agi15  = { "INVTYPE_FEET", 4, 2, 15, stats = { RESISTANCE0_NAME = 48, ITEM_MOD_AGILITY_SHORT = 3 } }
ITEMS.int32  = { "INVTYPE_FEET", 4, 2, 32, stats = { RESISTANCE0_NAME = 115, ITEM_MOD_INTELLECT_SHORT = 6 } }
ITEMS.int19  = { "INVTYPE_FEET", 4, 2, 19, stats = { RESISTANCE0_NAME = 115, ITEM_MOD_INTELLECT_SHORT = 6 } }
ITEMS.int20  = { "INVTYPE_FEET", 4, 2, 20, stats = { RESISTANCE0_NAME = 115, ITEM_MOD_INTELLECT_SHORT = 6 } }
ITEMS.int32w = { "INVTYPE_FEET", 4, 2, 32, stats = { RESISTANCE0_NAME = 40, ITEM_MOD_INTELLECT_SHORT = 6 } }
ITEMS.agi60  = { "INVTYPE_FEET", 4, 2, 60, stats = { RESISTANCE0_NAME = 200, ITEM_MOD_AGILITY_SHORT = 10 } }
ITEMS.int74  = { "INVTYPE_FEET", 4, 2, 74, stats = { RESISTANCE0_NAME = 300, ITEM_MOD_INTELLECT_SHORT = 12 } }
ITEMS.int75  = { "INVTYPE_FEET", 4, 2, 75, stats = { RESISTANCE0_NAME = 300, ITEM_MOD_INTELLECT_SHORT = 12 } }
ITEMS.agiGun = { "INVTYPE_RANGED", 2, 3, 18, stats = { ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 } }
ITEMS.intGun = { "INVTYPE_RANGED", 2, 3, 24, stats = { ITEM_MOD_INTELLECT_SHORT = 3, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 } }
local function check(bagLink, wornSlot, wornLink)
  for k in pairs(WORN) do WORN[k] = nil end
  WORN[wornSlot], WORN_Q[wornSlot] = wornLink, 2
  BAG[1] = { link = bagLink, quality = 2 }
  run()
  return line(bagLink) or ""
end
local l = check("int32", 8, "agi15")
ok("15) the owner's example: item level 32 Intellect boots replace item level 15 Agility boots",
   l:find("WOULD EQUIP in slot 8", 1, true) and l:find("item level 32 over 15", 1, true), l)
l = check("int19", 8, "agi15")
ok("15b) item level 19 is under the 20 needed: the Agility boots stay", l:find("item level 19 is under the 20 needed", 1, true), l)
l = check("int20", 8, "agi15")
ok("15c) item level 20 is enough", l:find("WOULD EQUIP in slot 8", 1, true), l)
l = check("int74", 8, "agi60")
ok("15d) at item level 60 the gap is 25%: 74 is under the 75 needed", l:find("under the 75 needed", 1, true), l)
l = check("int75", 8, "agi60")
ok("15e) and 75 is enough", l:find("WOULD EQUIP in slot 8", 1, true), l)
l = check("int32w", 8, "agi15")
ok("15f) past the gap it must still win: less armor and no Agility stays in the bags",
   l:find("skip", 1, true) and l:find("less", 1, true), l)
l = check("intGun", 16, "agiGun")
ok("15g) weapons too: past the gap, more damage per second wins on item level", l:find("WOULD EQUIP in slot 16", 1, true), l)
db.autoEquipUncommon = false

out(("=== %d passed, %d failed ==="):format(pass, fail))
