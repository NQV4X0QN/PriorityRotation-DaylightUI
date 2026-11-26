-- Priority Rotation (DaylightUI Plugin) / ErrorText.lua
-- Hide Error Text: chosen groups of the game's red error messages stay off the screen, voice line included,
-- beside DaylightUI's own error settings (all three can stay on). Carried over from VeritasUI's Interface module.
--
-- How: Blizzard keeps a per-type hidden list, BLACK_LISTED_MESSAGE_TYPES, written through
-- UIErrorsFrame:SetMessageTypeEnabled (Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua:103-105, Forever), checked
-- before a message shows AND before its voice line plays. DaylightUI's "Error text in Daylight UI style" claims
-- every type at its PLAYER_LOGIN and draws them itself, except a type already on that list, which it leaves to
-- the game (DaylightUI/Core.lua:541-544). So the types are written at this addon's ADDON_LOADED, before any
-- PLAYER_LOGIN (measured in VeritasUI, owner, 2026-11-25: too close, wrong stance and the mail error hidden with
-- all three of DaylightUI's error settings on).
--
-- The choices are DaylightUI options (this plugin's Error Messages page), but DaylightUI hands a plugin's settings
-- out only from its own PLAYER_LOGIN on, which is too late; so they are copied into this addon's saved variables
-- (db.hiddenErrors) whenever they change, and read from there at ADDON_LOADED. A change shows after /reload: only
-- `true` is ever written into Blizzard's list, and a /reload rebuilds it from Blizzard's own file.
--
-- ⚠ The list is shared with the yellow UI_INFO_MESSAGE path, so these are hand-picked failure messages and there is
-- no "everything else" group. Names, not numbers: the numbers are the client's, resolved through _G at load, so a
-- type Blizzard removes is skipped. Measured in Forever (owner's Warrior, 2026-11-25): "Target too close" arrives
-- as SPELL_FAILED_S and "Must be in Defensive Stance" as SPELL_FAILED_SHAPESHIFT_FORM_S, both in the Spells group.

local ADDON, PR = ...
local VUI = PR.VUI
if not VUI then return end

local ERROR_TYPE_GROUPS = {
    { id = "combat", label = "Combat: Range, Facing & Targets",
      tip = "'You are too far away!', 'You are facing the wrong way!', no target, and similar.",
      types = {
        "BADATTACKPOS", "BADATTACKFACING", "OUT_OF_RANGE", "SPELL_OUT_OF_RANGE",
        "PET_SPELL_OUT_OF_RANGE", "NO_ATTACK_TARGET", "GENERIC_NO_TARGET",
        "GENERIC_NO_VALID_TARGETS", "INVALID_ATTACK_TARGET", "COMMAND_NEEDS_TARGET",
        "UNIT_NOT_FOUND", "ATTACK_CHANNEL", "ATTACK_CHARMED", "ATTACK_CONFUSED",
        "ATTACK_DEAD", "ATTACK_FLEEING", "ATTACK_MOUNTED", "ATTACK_NO_ACTIONS",
        "ATTACK_PACIFIED", "ATTACK_PREVENTED_BY_MECHANIC_S",
        "ATTACK_PVP_TARGET_WHILE_UNFLAGGED", "ATTACK_STUNNED", "PET_SPELL_NOT_BEHIND",
        "PET_SPELL_TARGETS_DEAD", "PET_SPELL_DEAD", "PET_SPELL_ROOTED", "PET_SPELL_NOPATH",
        "PET_SPELL_AFFECTING_COMBAT", "TARGET_STUNNED", "CANT_TARGET_UNFRIENDLY_IN_OVERWORLD",
      } },
    { id = "spells", label = "Spells & Cooldowns",
      tip = "Not ready yet, not enough mana, energy or rage, can't do that while moving, and similar.",
      types = {
        "ABILITY_COOLDOWN", "SPELL_COOLDOWN", "ITEM_COOLDOWN", "POTION_COOLDOWN",
        "FOOD_COOLDOWN", "SPELL_FAILED_ALREADY_AT_FULL_HEALTH",
        "SPELL_FAILED_ALREADY_AT_FULL_MANA", "SPELL_FAILED_ALREADY_AT_FULL_POWER_S",
        "SPELL_FAILED_ANOTHER_IN_PROGRESS", "SPELL_FAILED_CANT_FLY_HERE",
        "SPELL_FAILED_EQUIPPED_ITEM", "SPELL_FAILED_EQUIPPED_ITEM_CLASS_S",
        "SPELL_FAILED_EQUIPPED_SPECIFIC_ITEM", "SPELL_FAILED_LEVEL_REQUIREMENT",
        "SPELL_FAILED_NOTUNSHEATHED", "SPELL_FAILED_OPTIONAL_REAGENTS",
        "SPELL_FAILED_REAGENTS", "SPELL_FAILED_REAGENTS_GENERIC", "SPELL_FAILED_S",
        "SPELL_FAILED_SHAPESHIFT_FORM_S", "SPELL_FAILED_TOTEMS",
        "OUT_OF_ALTERNATE_ENCOUNTER", "OUT_OF_ALTERNATE_MOUNT", "OUT_OF_ALTERNATE_QUEST",
        "OUT_OF_ARCANE_CHARGES", "OUT_OF_BALANCE", "OUT_OF_CHI", "OUT_OF_COMBO_POINTS",
        "OUT_OF_ENERGY", "OUT_OF_ESSENCE", "OUT_OF_FOCUS", "OUT_OF_FURY",
        "OUT_OF_HAPPINESS", "OUT_OF_HEALTH", "OUT_OF_HOLY_POWER", "OUT_OF_INSANITY",
        "OUT_OF_LUNAR_POWER", "OUT_OF_MAELSTROM", "OUT_OF_MANA", "OUT_OF_PAIN",
        "OUT_OF_POWER_DISPLAY", "OUT_OF_RAGE", "OUT_OF_RUNES", "OUT_OF_RUNE_BLOOD",
        "OUT_OF_RUNE_CHROMATIC", "OUT_OF_RUNE_FROST", "OUT_OF_RUNE_UNHOLY",
        "OUT_OF_RUNIC_POWER", "OUT_OF_SHADOW_ORBS", "OUT_OF_SOUL_SHARDS",
        "NOT_WHILE_DISARMED", "NOT_WHILE_FALLING", "NOT_WHILE_FATIGUED",
        "NOT_WHILE_MOUNTED", "NOT_WHILE_MOVING", "NOT_WHILE_SHAPESHIFTED",
        "NOT_IN_COMBAT", "AFFECTING_COMBAT", "GENERIC_STUNNED", "CANT_USE_DISARMED",
        "CANT_DO_THAT_RIGHT_NOW", "PASSIVE_ABILITY", "NOAMMO_S",
      } },
    { id = "items", label = "Items & Bags", tip = "Bags full, can't equip or use an item, and similar.",
      types = {
        "INV_FULL", "BAG_FULL", "CANT_USE_ITEM", "CANT_USE_ITEM_IN_ARENA",
        "CANT_USE_ITEM_IN_RATED_BATTLEGROUND", "CANT_EQUIP_EVER", "CANT_EQUIP_LEVEL_I",
        "CANT_EQUIP_NEED_TALENT", "CANT_EQUIP_RANK", "CANT_EQUIP_RATING",
        "CANT_EQUIP_REPUTATION", "CANT_EQUIP_SKILL", "CANT_STACK", "CANT_SWAP",
        "WRONG_SLOT", "WRONG_BAG_TYPE", "WRONG_BAG_TYPE_SUBCLASS", "NOT_EQUIPPABLE",
        "ITEM_LOCKED", "ITEM_MAX_COUNT", "ITEM_MAX_COUNT_EQUIPPED_SOCKETED",
        "ITEM_MAX_COUNT_SOCKETED", "ITEM_MAX_LIMIT_CATEGORY_COUNT_EXCEEDED_IS",
        "ITEM_MAX_LIMIT_CATEGORY_EQUIPPED_EXCEEDED_IS",
        "ITEM_MAX_LIMIT_CATEGORY_SOCKETED_EXCEEDED_IS", "ITEM_UNIQUE_EQUIPPABLE",
        "ITEM_UNIQUE_EQUIPPABLE_SOCKETED", "ITEM_CANT_BE_DESTROYED", "2HANDED_EQUIPPED",
        "2HSKILLNOTFOUND", "SPLIT_FAILED", "TOO_FEW_TO_SPLIT", "DESTROY_NONEMPTY_BAG",
        "BAG_IN_BAG", "NOT_A_BAG", "SLOT_EMPTY", "MUST_EQUIP_ITEM",
        "EQUIPMENT_MANAGER_BAGS_FULL", "INTERNAL_BAG_ERROR", "NO_SLOT_AVAILABLE",
        "REAGENTBAG_ITEM_TYPE", "REAGENTBAG_WRONG_SLOT", "SLOT_ONLY_REAGENTBAG",
        "NO_ITEMS_WHILE_SHAPESHIFTED", "SHAPESHIFT_FORM_CANNOT_EQUIP",
        "TOO_MANY_SPECIAL_BAGS", "ONLY_ONE_AMMO", "ONLY_ONE_BOLT", "ONLY_ONE_QUIVER",
        "AMMO_ONLY",
      } },
    -- ITEM_NOT_FOUND sits here, not under Items: Open All at a mailbox raises it alongside
    -- MAIL_DATABASE_ERROR (reported in game 2026-10-26). Its exact in-game wording is not yet
    -- matched to this type -- if "Item is not found" still shows with this group on, it is a
    -- different type.
    { id = "mail", label = "Mail, Vendors & Bank",
      tip = "Mailbox, vendor and bank errors, such as 'Internal mail database error.'",
      types = {
        "MAIL_DATABASE_ERROR", "ITEM_NOT_FOUND", "MAIL_ATTACHMENT_EXPIRED", "MAIL_BAG",
        "MAIL_BOUND_ITEM", "MAIL_CANT_SEND_REALM", "MAIL_CONJURED_ITEM",
        "MAIL_DELETE_ITEM_ERROR", "MAIL_INVALID_ATTACHMENT", "MAIL_INVALID_ATTACHMENT_SLOT",
        "MAIL_LIMITED_DURATION_ITEM", "MAIL_QUEST_ITEM", "MAIL_REACHED_CAP",
        "MAIL_RECEPIENT_CANT_RECEIVE_MAIL", "MAIL_RECEPIENT_IS_SELF_FOUND_CANNOT_RECEIVE_MAIL",
        "MAIL_TARGET_CANNOT_RECEIVE_MAIL", "MAIL_TARGET_IS_TRIAL", "MAIL_TARGET_NOT_FOUND",
        "MAIL_TEMP_RETURN_OUTAGE", "MAIL_TOO_MANY_ATTACHMENTS", "MAIL_TO_SELF",
        "MAIL_WRAPPED_COD", "VENDOR_DOESNT_BUY", "VENDOR_HATES_YOU", "VENDOR_MISSING_TURNINS",
        "VENDOR_NOT_INTERESTED", "VENDOR_REFUSE_SCRAPPABLE_AZERITE", "VENDOR_SOLD_OUT",
        "VENDOR_TOO_FAR", "NOT_ENOUGH_MONEY", "CANT_BUY_QUANTITY",
        "CANT_BULK_SELL_ITEM_WITH_REFUND", "NO_BANK_HERE", "NO_ACCOUNT_BANK_HERE",
        "BANK_FULL", "BANK_NOT_ACCESSIBLE", "REAGENT_BANK_FULL", "AUCTION_DATABASE_ERROR",
      } },
    { id = "loot", label = "Looting & Objects", tip = "Loot and object errors, such as being too far away to loot.",
      types = {
        "LOOT_BAD_FACING", "LOOT_CANT_LOOT_THAT", "LOOT_CANT_LOOT_THAT_NOW",
        "LOOT_DIDNT_KILL", "LOOT_GONE", "LOOT_LOCKED", "LOOT_NOTSTANDING", "LOOT_NO_UI",
        "LOOT_STUNNED", "LOOT_TOO_FAR", "LOOT_WHILE_INVULNERABLE", "NO_LOOT",
        "ALREADY_PICKPOCKETED", "USE_BAD_ANGLE", "USE_CANT_IMMUNE", "USE_CANT_OPEN",
        "USE_DESTROYED", "USE_LOCKED", "USE_LOCKED_WITH_ITEM_S",
        "USE_LOCKED_WITH_SPELL_KNOWN_SI", "USE_LOCKED_WITH_SPELL_S", "USE_OBJECT_MOVING",
        "USE_PREVENTED_BY_MECHANIC_S", "USE_SPELL_FOCUS", "USE_TOO_FAR",
        "TOO_FAR_TO_INTERACT", "OBJECT_IS_BUSY", "CHEST_IN_USE", "DOOR_LOCKED",
        "CANT_INTERACT_SHAPESHIFTED", "FISH_ESCAPED", "FISH_NOT_HOOKED",
      } },
    { id = "travel", label = "Mounts & Flight Paths", tip = "Mount and flight path errors.",
      types = {
        "MOUNT_ALREADYMOUNTED", "MOUNT_INVALIDMOUNTEE", "MOUNT_LOOTING",
        "MOUNT_NOTMOUNTABLE", "MOUNT_NOTYOURPET", "MOUNT_NO_FAVORITES", "MOUNT_NO_MOUNTS",
        "MOUNT_OTHER", "MOUNT_RACECANTMOUNT", "MOUNT_SHAPESHIFTED", "MOUNT_TOOFARAWAY",
        "DISMOUNT_NOPET", "DISMOUNT_NOTMOUNTED", "DISMOUNT_NOTYOURPET", "TAXIINCOMBAT",
        "TAXINOPATHS", "TAXINOSUCHPATH", "TAXINOTELIGIBLE", "TAXINOTENOUGHMONEY",
        "TAXINOTSTANDING", "TAXINOTVISITED", "TAXINOVENDORNEARBY",
        "TAXIPLAYERALREADYMOUNTED", "TAXIPLAYERBUSY", "TAXIPLAYERMOVING",
        "TAXIPLAYERSHAPESHIFTED", "TAXISAMENODE", "TAXITOOFARAWAY",
        "TAXIUNSPECIFIEDSERVERERROR",
      } },
}
PR.ERROR_GROUPS = ERROR_TYPE_GROUPS

-- The option key of a group: "hideErrors_combat" and so on.
function PR.ErrorKey(g) return "hideErrors_" .. g.id end

-- Writes the chosen groups' types into Blizzard's hidden list. `chosen` = { [groupId] = true }. Returns how many
-- types were written.
function PR.HideErrorTypes(chosen)
    local f = _G.UIErrorsFrame
    if not (f and f.SetMessageTypeEnabled) or type(chosen) ~= "table" then return 0 end
    local n = 0
    for _, g in ipairs(ERROR_TYPE_GROUPS) do
        if chosen[g.id] then
            for _, name in ipairs(g.types) do
                local t = _G["LE_GAME_ERR_" .. name]
                if type(t) == "number" then f:SetMessageTypeEnabled(t, false); n = n + 1 end
            end
        end
    end
    return n
end

-- The options page's values, copied into db.hiddenErrors (Options.lua calls this on login and on every change).
function PR.SaveErrorChoices(get)
    if not PR.db then return end
    local chosen = {}
    for _, g in ipairs(ERROR_TYPE_GROUPS) do
        if get(PR.ErrorKey(g)) == true then chosen[g.id] = true end
    end
    PR.db.hiddenErrors = chosen
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterAllEvents()
    local db = _G.PriorityRotationDUIDB
    PR.HideErrorTypes(type(db) == "table" and db.hiddenErrors or nil)
end)
