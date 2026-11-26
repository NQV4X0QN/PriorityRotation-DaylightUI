-- .luacheckrc -- Priority Rotation (DaylightUI Plugin). Run from the repo root: luacheck DaylightPriorityRotation tests
-- WoW runs a Lua 5.1 base; the game's API is layered on as read_globals. The list is VeritasUI's (this code came
-- from there) plus DaylightUI.

std = "lua51"
max_line_length = false

-- Globals this addon must define: its saved variables, slash command names, the AddOn compartment callback, the
-- secure button and window names Blizzard looks up by name, and Blizzard tables it adds KEYS to.
globals = {
    "DaylightPriorityRotationDB",
    "SLASH_DAYLIGHTPR1", "SLASH_DAYLIGHTPR2", "SlashCmdList",
    "DaylightPriorityRotation_OnAddonCompartmentClick",
    "UIPanelWindows",
}

read_globals = {
    "DaylightUI", "VeritasUI_PriorityRotationDB",
    "StaticPopupDialogs", "UISpecialFrames", "xpcall", "UnitClass", "print",
    -- Blizzard globals the suite reads, or writes only the KEYS of. Listing them
    -- here is what makes assigning the global itself a warning (see the note in
    -- `globals` above). UISpecialFrames qualifies because table.insert APPENDS to
    -- it and never assigns it.
    "StaticPopupDialogs", "UISpecialFrames",
    -- Core frame / system
    "CreateFrame", "UIParent", "C_Timer", "hooksecurefunc", "InCombatLockdown",
    "issecretvalue", "debugprofilestop", "GetTime", "time", "date",
    "ReloadUI", "C_AddOns", "IsAddOnLoaded", "GetBuildInfo", "geterrorhandler",
    "StaticPopup_Show", "ACCEPT", "CANCEL", "CHAT_CONFIGURATION", "CHAT_DEFAULTS",
    "HUD_EDIT_MODE_PET_ACTION_BAR_LABEL", "HUD_EDIT_MODE_STANCE_BAR_LABEL",   -- Edit Mode bar names (v1.75.0)
    -- Strings / math helpers WoW exposes globally
    "strtrim", "strsplit", "strjoin", "strlower", "strfind", "format",
    "CreateColor", "CreateVector2D", "C_ClassColor",
    -- Settings / options framework
    "Settings", "SettingsPanel", "InterfaceOptions_AddCategory", "MinimalSliderWithSteppersMixin", "CreateSettingsListSectionHeaderInitializer",
    "CreateSettingsCheckboxSliderInitializer", "FormatPercentage",
    "EventRegistry", "SETTINGS_DEFAULTS", "RELOADUI",
    "SELL_PRICE", "ContainerFrameUtil_GetItemButtonAndContainer",
    -- QualityOfLife (audit Q2, Q5)
    "MAP_PIN_INVALID_MAP", "GameTime_GetLocalTime", "LEVEL", "STAT_AVERAGE_ITEM_LEVEL",
    -- AdvancedOptions (audit O1)
    "COLORBLIND_OPTION_NONE", "COLORBLIND_OPTION_PROTANOPIA", "COLORBLIND_OPTION_DEUTERANOPIA",
    "COLORBLIND_OPTION_TRITANOPIA", "OPTION_TOOLTIP_USE_COLORBLIND_MODE",
    "Mixin", "SHOW_FACTION_ON_MAINSCREEN", "WatchedFactionToggleFrameMixin", "Minimap", "wipe",
    "UISpecialFrames", "ShowUIPanel", "HideUIPanel",
    "PanelTemplates_SetTab", "PanelTemplates_SetNumTabs",
    "PanelTemplates_TabResize", "PanelTemplates_GetSelectedTab",
    -- Scroll / data-provider system
    "CreateScrollBoxListLinearView", "CreateDataProvider", "ScrollUtil",
    "Menu", "MenuResponse", "MenuUtil",
    "IsInInstance", "GetInstanceInfo", "CreateFromMixins", "MapCanvasPinMixin",
    "MapCanvasDataProviderMixin", "GameTooltip_SetTitle", "GameTooltip_AddColoredLine", "EventUtil",
    "UIErrorsFrame", "MAP_PIN_INVALID_MAP", "RED_FONT_COLOR", "PlaySound", "StopSound", "C_UnitAuras", "StaticPopup_FindVisible", "DELETE_ITEM_CONFIRM_STRING", "CinematicFrame", "StopCinematic", "MovieFrame", "C_GossipInfo", "GetNumActiveQuests", "GetActiveTitle", "SelectActiveQuest", "GetNumAvailableQuests", "GetAvailableQuestInfo", "SelectAvailableQuest", "QuestFlagsPVP", "QuestGetAutoAccept", "AcknowledgeAutoAcceptQuest", "AcceptQuest", "IsQuestCompletable", "CompleteQuest", "GetNumQuestChoices", "GetQuestMoneyToGet", "GetQuestReward", "IsLoggedIn", "GetPetActionSlotUsable", "WillAcceptInviteRemoveQueues", "DeclineGroup", "CancelDuel", "GetNextPendingInviteConfirmation", "GetInviteConfirmationInfo", "LE_INVITE_CONFIRMATION_REQUEST", "RespondToInviteConfirmation", "BNGetNumFriendInvites", "BNDeclineFriendInvite", "DeclineQuest", "BNGetNumFriends", "GetNumGuildMembers", "GetGuildRosterInfo", "IsAnyBagOpen", "OpenAllBags", "CloseBag", "CloseBackpack", "NUM_TOTAL_BAG_FRAMES", "Menu", "RETRIEVING_ITEM_INFO", "BIND_TRADE_TIME_REMAINING", "GetNumQuestCurrencies", "GetNumQuestItems", "GetQuestItemInfo", "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "C_Trainer", "IsTradeskillTrainer", "GetTrainerServiceSkillLine", "GetTrainerServiceNumAbilityReq", "GetTrainerServiceAbilityReq", "GetTrainerServiceTypeFilter", "TRAINER_REQ_LEVEL", "TRAINER_REQ_LEVEL_RED", "TRAINER_REQ_ABILITY", "TRAINER_REQ_ABILITY_RED", "REQUIRES_LABEL", "PLAYER_LIST_DELIMITER", "MoneyFrame_SetType", "GRAY_FONT_COLOR_CODE", "FONT_COLOR_CODE_CLOSE", "PARENS_TEMPLATE", "MoneyFrame_Update", "SetMoneyFrameColorByFrame", "ScrollBoxConstants", "TRAINER", "NameUtil", "ClassTrainerFrame", "ClassTrainerTrainButton", "BuyTrainerService", "ClassTrainerFrame_Update", "UnitIsUnit", "UnitIsPlayer", "TARGET", "MOUNT", "C_MountJournal", "UnitTokenFromGUID", "ChatFrameUtil", "GetCursorPosition", "HasNewMail", "TIMESTAMP_FORMAT_NONE", "TimeUtil", "ENCHANTED_TOOLTIP_LINE", "GetInventoryItemDurability", "GetInventoryAlertStatus", "INVENTORY_ALERT_COLORS", "CharacterStatsPane", "C_ChallengeMode", "PaperDollItemSlotButton_Update", "PaperDollFrame_UpdateStats", "SOUNDKIT", "UiMapPoint",
    "IsShiftKeyDown", "GameTooltip_AddErrorLine", "GameTooltip_AddInstructionLine", "GREAT_VAULT_REWARDS", "ERR_NOT_IN_COMBAT", "WEEKLY_REWARDS_CLICK_TO_PREVIEW_INSTRUCTIONS",
    -- Tooltips
    "GameTooltip", "ItemRefTooltip", "TooltipDataProcessor", "TooltipUtil",
    "C_TooltipInfo", "ITEM_LEVEL",
    -- v1.72.0 guild and friends (Automation.lua, Social.lua)
    "IsGuildMember", "AcceptGroup", "C_ChatInfo", "C_PartyInfo", "C_GuildInfo", "Ambiguate", "GUILD",
    "C_BattleNet", "C_CreatureInfo", "C_FriendList",
    -- Trainer.lua's pet-trainer title fallback (GlobalStrings PET)
    "PET",
    "BattlePetTooltip", "FloatingBattlePetTooltip", "BattlePetToolTip_Show",
    "FloatingBattlePet_Toggle",
    -- Item / container / inventory
    "C_Item", "C_Container", "ItemLocation", "Item", "GetInventoryItemLink", "GetInventoryItemQuality", "REPUTATION_STATUS_BAR_LABEL_ACCOUNT_WIDE",
    "GetItemInfoInstant", "GetDetailedItemLevelInfo", "GetInventoryItemID",
    "ITEM_QUALITY_COLORS", "BAG_ITEM_QUALITY_COLORS", "ColorManager", "NUM_BAG_SLOTS",
    "C_TradeSkillUI", "C_Texture",
    -- Map / navigation / quests
    "C_Map", "C_Navigation", "C_SuperTrack", "C_QuestLog", "GetQuestID", "GetTitleText", "GetAvailableTitle",
    -- Delves (QualityOfLife: Nemesis groups-remaining count on the Delve plaque)
    "C_DelvesUI",
    -- Blizzard font colour objects (QoL: Delve count colouring). Confirmed present
    -- in Blizzard_UIWidgetTemplateBase.lua's spellBorderColorFromTintValue table.
    "RED_FONT_COLOR", "ORANGE_FONT_COLOR", "YELLOW_FONT_COLOR", "GREEN_FONT_COLOR",
    "UiMapPoint", "GetRealZoneText", "GetZoneText", "GetSubZoneText",
    "Enum",
    -- Action bars / macros / spells / specs (PriorityRotation)
    "C_Spell", "C_SpecializationInfo", "GetSpecialization",
    "GetSpecializationInfo", "GetNumSpecializations", "SetSpecialization",
    "GetActionInfo", "GetMacroInfo", "GetMacroBody", "GetMacroIndexByName",
    "GetNumMacros", "CreateMacro", "EditMacro", "MAX_ACCOUNT_MACROS",
    "GetCursorInfo", "ClearCursor", "GetBindingKey", "SetOverrideBindingClick", "SetOverrideBinding",
    "ClearOverrideBindings", "C_CVar", "C_ActionBar", "C_Secrets",
    "C_RestrictedActions", "PlayerSpellsFrame", "PlayerSpellsUtil",
    "ToggleSpellBook", "BOOKTYPE_SPELL", "MacroFrame", "ShowMacroFrame",
    "IsShiftKeyDown", "EditModeManagerFrame",
    -- Money / merchant / repair (QualityOfLife)
    "GetCoinTextureString", "C_CurrencyInfo", "GetMerchantItemLink",
    "GetMerchantNumItems", "MerchantFrame", "MERCHANT_ITEMS_PER_PAGE",
    "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems",
    "CanGuildBankRepair", "IsInGuild", "GetGuildInfoText", "GetMoney",
    "GetGuildBankWithdrawMoney",
    "SetItemButtonQuality",
    -- Player / unit / AFK
    "UnitName", "UnitClass", "UnitLevel", "UnitIsAFK", "IsFalling", "UnitExists", "GetAverageItemLevel",
    "UnitAffectingCombat", "AcceptResurrect", "GetCorpseRecoveryDelay", "C_ToyBoxInfo", "C_PetJournal",
    "C_MountJournal", "C_PlayerInteractionManager", "ITEM_OPENABLE", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
    "GetServerExpansionLevel", "C_PlayerInfo", "GetMaxLevelForPlayerExpansion", "UnitGUID",
    "CreateSettingsButtonInitializer", "ButtonFrameTemplate_HidePortrait", "IsMacClient", "GameTooltip_AddNormalLine", "GameTooltip_Hide",
    "IsInRaid", "GetNumGroupMembers", "MuteSoundFile", "UnmuteSoundFile", "ChatFrameConstants",
    "GetSpellCritChance", "GetRangedCritChance", "GetCritChance", "BreakUpLargeNumbers", "GetCombatRating",
    "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "YELLOW_FONT_COLOR", "RED_FONT_COLOR", "GREEN_FONT_COLOR",
    "GRAY_FONT_COLOR", "DISABLED_FONT_COLOR", "ORANGE_FONT_COLOR", "LIGHTBLUE_FONT_COLOR", "BRIGHTBLUE_FONT_COLOR",
    "LIGHTGRAY_FONT_COLOR",
    "GetRealmName", "UnitFullName", "GetPhysicalScreenSize",
    "MoveViewRightStart", "MoveViewRightStop", "MinimapCluster",
    "NumberFontNormal", "NumberFontNormalRight",
    -- Auction House
    "C_AuctionHouse", "AuctionHouseFrame", "AuctionHouseFrameDisplayMode",
    -- Chat / UI elements (Interface)
    "NUM_CHAT_WINDOWS", "FCF_SetWindowAlpha", "FCF_SetWindowColor",
    "FCF_FadeInChatFrame", "FCF_FadeOutChatFrame", "CHAT_FRAME_FADE_TIME", "CHAT_FRAME_FADE_OUT_TIME",
    "CHAT_TAB_HIDE_DELAY", "QuickJoinToastButton", "MicroMenu", "PlayerFrame",
    "VoiceChatTalkerContainer", "ChatFrame1EditBox", "UIErrorsFrame",
    "BagsBar", "BagBar", "MouseIsOver", "GetMouseFocus", "GetMouseFoci",
    "WorldMapFrame", "DEFAULTS",
    -- Console (AdvancedOptions enumeration fallbacks)
    "C_Console", "ConsoleGetAllCommands",
    -- Templates referenced by name in CreateFrame (string args, but listed for clarity)
}

ignore = {
    "212",   -- unused argument (event handlers often ignore some payload args)
    "213",   -- unused loop variable (the `for _, x in` convention)
    "432",   -- shadowing upvalue 'self': outer self = PR, inner self = the widget in a SetScript handler
    "131",   -- unused implicitly-defined global: SLASH_* and the compartment callback are read by the client
}

exclude_files = { ".git/**", "**/*.zip", ".release/**" }

files["tests/"] = { globals = { "_G", "arg", "os" }, allow_defined_top = true, max_line_length = false,
                   ignore = { "231", "411", "542" } }  -- the suites came from VeritasUI's harness as they were
