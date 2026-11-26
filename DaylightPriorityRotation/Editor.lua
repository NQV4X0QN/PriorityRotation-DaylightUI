-- Priority Rotation (DaylightUI Plugin) / Editor.lua
-- The Rotation page: the ability list (drop, drag to reorder, Frequency, After, Combat) and the compiled sequence.
local _, PR = ...
local VUI = PR.VUI
if not VUI then return end

-- Spellbook / Macro toggles, shared by empty rotation slots and the Settings-tab buttons.
--
-- ⛔ PRIORITY ROTATION NEVER OPENS THE SPELLBOOK ITSELF (v1.22.1). Opening it from this code made
-- the spellbook set itself up as addon code, so a spell clicked in it was refused
-- (CastSpellBookItem, ADDON_ACTION_FORBIDDEN). The click is now forwarded to Blizzard's menu-bar
-- button by SpellbookOpener.lua's secure overlay, which sits on top of the slot or button and gets
-- the click before this runs. This function is only reached when the overlay is not there -- in
-- combat (it is hidden then) or if the menu-bar button is missing -- and it only explains.
local function ToggleSpellBookPanel()
    if InCombatLockdown() then
        VUI.Print("Priority Rotation", VUI.COL.RED .. "Can't toggle Spellbook in combat.|r")
        return
    end
    VUI.Print("Priority Rotation", "Open your spellbook from the menu bar or its key binding.")
end

local function ToggleMacroPanel()
    if InCombatLockdown() then
        VUI.Print("Priority Rotation", VUI.COL.RED .. "Can't toggle Macros in combat.|r")
        return
    end
    if MacroFrame and MacroFrame:IsShown() then
        pcall(HideUIPanel, MacroFrame)
        return
    end
    if ShowMacroFrame then pcall(ShowMacroFrame) end
end

-- Expose on PR so Settings.lua can call them without duplicating the logic.
PR.ToggleSpellBookPanel = ToggleSpellBookPanel
PR.ToggleMacroPanel     = ToggleMacroPanel

-- ── Drop helpers ─────────────────────────────────────────────
-- HandleDrop appends if slotIndex is beyond the current list
-- to prevent sparse array holes.

-- Extract the primary spell name from a macro body.
-- Tries #showtooltip first, then /cast or /use lines.
-- Strips macro conditionals like [@player, combat, nochanneling].
local function ExtractSpellFromMacro(macroName)
    local body = GetMacroBody(macroName)
    if not body or body == "" then return nil end

    -- Try #showtooltip <SpellName> first
    local showtt = body:match("#showtooltip%s+([^\n]+)")
    if showtt then
        showtt = strtrim(showtt)
        if showtt ~= "" then
            local info = C_Spell.GetSpellInfo(showtt)
            if info and info.spellID then return info.spellID end
        end
    end

    -- Try /cast or /use lines, stripping conditionals
    for line in body:gmatch("[^\n]+") do
        local spellName = line:match("^/[Cc]ast%s+(.+)") or line:match("^/[Uu]se%s+(.+)")
        if spellName then
            -- Strip conditionals: remove [...] blocks
            spellName = spellName:gsub("%b[]%s*", "")
            spellName = strtrim(spellName)
            -- Strip trailing ;fallback spells — take the first one
            spellName = spellName:match("^([^;]+)") or spellName
            spellName = strtrim(spellName)
            if spellName ~= "" then
                local info = C_Spell.GetSpellInfo(spellName)
                if info and info.spellID then return info.spellID end
            end
        end
    end
    return nil
end

-- BuildEntry creates a profile entry from the current cursor.
-- Returns (entry, errorMsg) — entry is nil on failure.
local function BuildEntryFromCursor()
    local cursorType, cursorData, _, cursorSpellID = GetCursorInfo()
    if not cursorType then return nil end

    if cursorType == "spell" then
        local spellID = cursorSpellID or cursorData
        local info = C_Spell.GetSpellInfo(spellID)
        if not (info and info.name) then
            return nil, "Could not resolve spell ID " .. tostring(spellID)
        end
        return {
            spellID   = spellID,
            spellName = info.name,
            icon      = info.iconID,
            freq      = 1,
        }
    elseif cursorType == "macro" then
        local rawIndex = cursorData
        local MAX_ACCT = MAX_ACCOUNT_MACROS or 120

        -- GetCursorInfo may return a tab-relative index when the user
        -- drags from the character-specific macro tab.  Character macros
        -- live at slots (MAX_ACCOUNT_MACROS+1) .. (MAX_ACCOUNT_MACROS+30),
        -- so we must detect and apply the offset.
        local mName, mIcon, mBody = GetMacroInfo(rawIndex)
        local cName, cIcon, cBody
        if rawIndex <= MAX_ACCT then
            cName, cIcon, cBody = GetMacroInfo(rawIndex + MAX_ACCT)
        end

        -- Decide which interpretation is correct:
        if cName and cName ~= "" then
            -- If the MacroFrame is open on the character tab, prefer that
            if MacroFrame and MacroFrame:IsShown() then
                local selTab = PanelTemplates_GetSelectedTab
                    and PanelTemplates_GetSelectedTab(MacroFrame)
                if selTab == 2 then
                    mName, mIcon, mBody = cName, cIcon, cBody
                end
            elseif not mName or mName == "" then
                -- MacroFrame not open but raw index failed; use char slot
                mName, mIcon, mBody = cName, cIcon, cBody
            end
        end

        if not mName or mName == "" or not mBody or mBody == "" then
            return nil, "Could not read macro (index " .. tostring(rawIndex) .. ")."
        end
        return {
            macroName = mName,
            icon      = mIcon,
            freq      = 1,
        }
    elseif cursorType == "item" then
        -- Items dragged from a bag, character pane trinket slot, or
        -- merchant. cursorData holds the itemID; cursorSpellID is unused.
        local itemID = cursorData
        -- C_Item.GetItemInfo return values may be Secret Values in raid
        -- encounters; guard the call and the equipLoc comparison.
        -- Mirrors IsEquippableGear in QualityOfLife.lua.
        local ok, name, _, quality, _, _, _, _, _, equipLoc, icon =
            pcall(C_Item.GetItemInfo, itemID)
        if not ok or not name then
            -- Item info isn't in the client cache yet (or returned a
            -- Secret Value). Rare for items the player owns (which are
            -- always cached), but possible for ephemeral cursor states.
            -- Ask the user to retry once cached.
            return nil, "Item info not loaded yet — try again in a moment."
        end
        local okEq, isTrinket = pcall(function()
            return equipLoc == "INVTYPE_TRINKET"
        end)
        if not okEq or not isTrinket then
            return nil, "Only trinkets can be added to the rotation right now."
        end
        return {
            itemID    = itemID,
            itemName  = name,
            itemQuality = quality,
            icon      = icon,
            freq      = 1,
        }
    end

    return nil, "Drag a spell, macro, or trinket onto this slot."
end

-- Resolve a follows-key (see PR.EntryKey) back to the profile entry it
-- names, or nil if that entry is no longer in the list (stale link —
-- kept in the data so re-adding the same ability reactivates it).
-- `spells` is OPTIONAL: pass it when the caller already holds the list, so a
-- full editor repaint resolves the profile once instead of once per row. The
-- followBtn tooltip caller has no such local in scope, hence the fallback.
local function FindEntryByKey(key, spells)
    if not key then return nil end
    for _, o in ipairs(spells or PR:CurrentProfile().spells) do
        if PR.EntryKey(o) == key then return o end
    end
end

local function EntryDisplayName(e)
    return e and (e.spellName or e.macroName or e.itemName) or "?"
end

-- "After Eye Beam: Essence Break (only), Blade Dance" lines under the compiled sequence: held
-- followers are not in the sequence at all, so without this they would vanish from the preview.
local function AfterLinksText()
    local byTarget, order = {}, {}
    for _, l in ipairs(PR.compiledLinks or {}) do
        if not byTarget[l.target] then byTarget[l.target] = {}; order[#order + 1] = l.target end
        local n = l.name:match("^%[MACRO:(.-)%]$") and ("[M:" .. l.name:match("^%[MACRO:(.-)%]$") .. "]")
            or l.name:match("^%[ITEM:(.-)%]$") and ("[T:" .. l.name:match("^%[ITEM:(.-)%]$") .. "]")
            or l.name
        local t = byTarget[l.target]
        t[#t + 1] = l.only and (n .. " (only)") or n
    end
    local out = {}
    for _, target in ipairs(order) do
        out[#out + 1] = VUI.COL.NORMAL .. "After " .. target .. ":|r " .. table.concat(byTarget[target], ", ")
    end
    return #out > 0 and ("\n\n" .. table.concat(out, "\n")) or ""
end

local function HandleDrop(slotIndex)
    local entry, errMsg = BuildEntryFromCursor()
    if not entry then
        if errMsg then VUI.Print("Priority Rotation", errMsg) end
        return
    end

    local spells = PR:CurrentProfile().spells
    if slotIndex <= #spells then
        spells[slotIndex] = entry       -- overwrite existing slot
    else
        spells[#spells + 1] = entry     -- append (no sparse gaps)
    end

    ClearCursor()
    PR:SaveCurrentProfile()
    if PR.Editor then PR.Editor:Refresh() end
end
-- ── Build the editor ─────────────────────────────────────────
-- The Rotation page, laid out like DaylightUI's trainer page (Widgets.lua has the measurements): a ROTATION
-- section, one line per ability and one empty line to drop the next one on, a COMPILED SEQUENCE section, and the
-- footer. Each line keeps the three controls the rotation needs at its right: Frequency (the arrows and the
-- number), After (the box of the channelled spell it waits for) and Combat (a switch).
local UI = PR.UI
local API = PR.API

local CTRL = { switchW = 30, switchH = 16, afterW = 24, freqW = 52, arrow = 16, gap = 14, right = 8 }

-- Its chevron (DaylightUI Media ui-chevron.png, pointing down) turned to point left or right, as its tree rows
-- turn it (Parts.lua paintChevron: a quarter turn).
local function Arrow(parent, facingRight)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CTRL.arrow, CTRL.arrow)
    local t = b:CreateTexture(nil, "ARTWORK")
    if API.Media then t:SetTexture(API.Media("ui-chevron.png")) end
    t:SetSize(10, 10)
    t:SetPoint("CENTER")
    t:SetRotation(facingRight and (math.pi / 2) or (-math.pi / 2))
    b.art = t
    function b.Paint(over)
        UI.Ink(t, b:IsEnabled() and (over and "VALUE" or "LABEL") or "OFF")
    end
    b:SetScript("OnEnter", function() b.Paint(true) end)
    b:SetScript("OnLeave", function() b.Paint(false) end)
    hooksecurefunc(b, "SetEnabled", function() b.Paint(b:IsMouseOver() == true) end)
    b.Paint(false)
    return b
end

-- The After box: a small icon slot, an edge like the line's icon, the LFG lock for Only After.
local function AfterBox(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CTRL.afterW, CTRL.afterW)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.edge = UI.Tex(b, "ARTWORK", UI.ICON_EDGE)
    b.edge:SetAllPoints(b)
    b.well = UI.Tex(b, "ARTWORK", { 0.063, 0.063, 0.071, 1 }, 1)
    b.well:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.well:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.tex = b:CreateTexture(nil, "OVERLAY")
    b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    UI.CropIcon(b.tex)
    b.tex:Hide()
    b.lock = b:CreateTexture(nil, "OVERLAY", nil, 7)
    b.lock:SetAtlas("LFG-lock")
    b.lock:SetSize(9, 11)
    b.lock:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    b.lock:Hide()
    local hl = UI.Tex(b, "HIGHLIGHT", { 1, 1, 1, 0.12 })
    hl:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    return b
end

-- What the line's sub text says about an entry: what kind of thing it is, what it waits for, when it casts.
local function SubText(e, spells)
    local bits = {}
    if e.macroName then bits[#bits + 1] = "Macro"
    elseif e.itemID then bits[#bits + 1] = "Trinket" end
    if e.channel then bits[#bits + 1] = "Channelled" end
    local target = FindEntryByKey(e.follows, spells)
    if target then
        local word = e.followOnly and "Only after " or "After "
        bits[#bits + 1] = word .. EntryDisplayName(target) .. (target.channel and "" or " (not seen channelling yet)")
    end
    if e.combatOnly and not e.macroName then bits[#bits + 1] = "In combat only" end
    return table.concat(bits, " · ")
end

function PR:BuildEditor(page)
    local editor = {}
    local list = UI.List(page, 10, UI.FOOT)
    local W = list.width
    local child = list.child

    local HEADER_TIPS = {
        Rotation    = "Your rotation, in order. Drag an ability up or down to move it. Drag a spell from your "
                      .."spellbook, a macro from /macro or a trinket from your character pane onto the empty line "
                      .."below it, and right-click an ability to remove it.",
        Frequency   = "How often an ability is attempted relative to the others, spread as evenly as "
                      .."the numbers allow. 5 = attempted almost constantly (short cooldowns, spenders); "
                      .."1 = attempted rarely. It sets the spacing, not a literal count: back-to-back "
                      .."presses of the same ability are collapsed, so a high frequency buys shorter gaps "
                      .."rather than more steps. A not-ready attempt is skipped harmlessly, so err on the "
                      .."high side for important abilities.",
        After       = "Casts an ability on the next press after a channelled spell finishes, such as "
                      .."Essence Break after Eye Beam. Click the box to pick the spell. Right-click "
                      .."for Only After (the lock): the ability is then held for it and never cast on "
                      .."its own.",
        Combat      = "Only cast in combat. Leave your opener off so a key press can start the "
                      .."fight. Macros have no switch: what they do is up to the macro.",
    }
    editor.headerTips = HEADER_TIPS
    local function Tip(owner, title, text)
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        GameTooltip:SetText(title, HIGHLIGHT_FONT_COLOR:GetRGB())
        GameTooltip:AddLine(text, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        GameTooltip:Show()
    end

    -- Where the three controls sit, from the line's right edge in.
    local switchR = CTRL.right
    local afterR  = switchR + CTRL.switchW + CTRL.gap
    local freqR   = afterR + CTRL.afterW + CTRL.gap

    -- ── The ROTATION section, with the three control columns named over their controls ──
    local sec = UI.Section(child)
    sec:SetWidth(W)
    local function Caption(text, rightOff, width)
        local fs = API.Text(sec, "small", "CENTER")
        fs:SetPoint("BOTTOM", sec, "BOTTOMRIGHT", -(rightOff + width / 2), 4)
        fs:SetText(text)
        UI.Ink(fs, "LABEL")
        local hit = CreateFrame("Frame", nil, sec)
        hit:SetPoint("TOPLEFT", fs, "TOPLEFT", -4, 3)
        hit:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 4, -3)
        hit:EnableMouse(true)
        hit:SetScript("OnEnter", function(self) UI.Ink(fs, "VALUE"); Tip(self, text, HEADER_TIPS[text]) end)
        hit:SetScript("OnLeave", function() UI.Ink(fs, "LABEL"); GameTooltip:Hide() end)
        return fs
    end
    editor.captions = {
        Frequency = Caption("Frequency", freqR, CTRL.freqW),
        After     = Caption("After", afterR, CTRL.afterW),
        Combat    = Caption("Combat", switchR, CTRL.switchW),
    }
    local secHit = CreateFrame("Frame", nil, sec)
    secHit:SetPoint("TOPLEFT", sec.text, "TOPLEFT", -4, 3)
    secHit:SetPoint("BOTTOMRIGHT", sec.text, "BOTTOMRIGHT", 4, -3)
    secHit:EnableMouse(true)
    secHit:SetScript("OnEnter", function(self) Tip(self, "Rotation", HEADER_TIPS.Rotation) end)
    secHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── The lines ──────────────────────────────────────────────
    local rows = {}
    editor.rows = rows
    local function Remove(i)
        local spells = PR:CurrentProfile().spells
        if spells[i] then
            table.remove(spells, i)
            PR:SaveCurrentProfile()
            editor:Refresh()
        end
    end
    local function Click(i, btn)
        if btn == "RightButton" then return Remove(i) end
        local ct = GetCursorInfo()
        if ct == "spell" or ct == "macro" or ct == "item" then
            HandleDrop(i)
        elseif not PR:CurrentProfile().spells[i] then
            if IsShiftKeyDown() then ToggleMacroPanel() else ToggleSpellBookPanel() end
        end
    end
    local function LineTip(self, i)
        local e = PR:CurrentProfile().spells[i]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local hint = true
        if e and e.spellID then
            GameTooltip:SetSpellByID(e.spellID)
        elseif e and e.itemID then
            GameTooltip:SetItemByID(e.itemID)
        elseif e and e.macroName then
            local resolved = ExtractSpellFromMacro(e.macroName)
            if resolved then
                GameTooltip:SetSpellByID(resolved)
                GameTooltip:AddLine(VUI.COL.LIGHTBLUE .. "Macro: " .. e.macroName .. "|r")
            else
                GameTooltip:AddLine("Macro: " .. e.macroName, HIGHLIGHT_FONT_COLOR:GetRGB())
                local body = GetMacroBody(e.macroName)
                if body and body ~= "" then
                    GameTooltip:AddLine(body, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
                end
            end
        else
            hint = false
            GameTooltip:AddLine("Empty slot", HIGHLIGHT_FONT_COLOR:GetRGB())
            GameTooltip:AddLine("Click to toggle Spellbook · Shift-click to toggle Macros",
                LIGHTBLUE_FONT_COLOR:GetRGB())
            GameTooltip:AddLine("Drag a spell, macro, or trinket here to add it.", NORMAL_FONT_COLOR:GetRGB())
        end
        if hint then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Drag to move", HIGHLIGHT_FONT_COLOR:GetRGB())
            GameTooltip:AddLine(VUI.COL.LIGHTBLUE .. "Right-click to remove|r")
        end
        GameTooltip:Show()
    end

    for i = 1, PR.MAX_SLOTS do
        local row = UI.Line(child)
        row:SetWidth(W)
        row.slot = i
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnClick", function(_, btn) Click(i, btn) end)
        row:SetScript("OnReceiveDrag", function() HandleDrop(i) end)
        row:SetScript("OnDragStart", function() editor:StartReorder(i) end)
        row:SetScript("OnDragStop", function() editor:FinishReorder() end)
        row:HookScript("OnEnter", function(self) LineTip(self, i) end)
        row:HookScript("OnLeave", function() GameTooltip:Hide() end)
        if PR.SpellbookOpener then
            PR.SpellbookOpener.AddTarget(row, {
                isActive = function() return row:IsShown() and not PR:CurrentProfile().spells[i] end,
                onDrop   = function() HandleDrop(i) end,
                onShift  = function() ToggleMacroPanel() end,
            })
        end

        -- Frequency: the number between two arrows.
        local freq = CreateFrame("Frame", nil, row)
        freq:SetSize(CTRL.freqW, UI.LINE)
        freq:SetPoint("RIGHT", row, "RIGHT", -freqR, 0)
        local dec = Arrow(freq, false)
        dec:SetPoint("LEFT", freq, "LEFT", 0, 0)
        local inc = Arrow(freq, true)
        inc:SetPoint("RIGHT", freq, "RIGHT", 0, 0)
        local num = API.Text(freq, "body", "CENTER")
        num:SetPoint("CENTER", freq, "CENTER", 0, 0)
        UI.Ink(num, "VALUE")
        dec:SetScript("OnClick", function()
            local e = PR:CurrentProfile().spells[i]
            if not e then return end
            e.freq = math.max(1, (e.freq or 1) - 1)
            PR:SaveCurrentProfile(); editor:Refresh()
        end)
        inc:SetScript("OnClick", function()
            local e = PR:CurrentProfile().spells[i]
            if not e then return end
            e.freq = math.min(5, (e.freq or 1) + 1)
            PR:SaveCurrentProfile(); editor:Refresh()
        end)
        row.freqFrame, row.freqLbl, row.decBtn, row.incBtn = freq, num, dec, inc
        row.right = freq

        -- After: the box of the channelled spell this one waits for (v1.36.0; the press snippet in Core.lua does
        -- the waiting). Left-click cycles through the other entries seen channelling, then back to none;
        -- right-click switches between Also After and Only After.
        local follow = AfterBox(row)
        follow:SetPoint("RIGHT", row, "RIGHT", -afterR, 0)
        follow:SetScript("OnClick", function(_, btn)
            local spells = PR:CurrentProfile().spells
            local e = spells[i]
            if not e then return end
            if btn == "RightButton" then
                if not e.follows then return end
                e.followOnly = (not e.followOnly) or nil
            else
                -- Candidates: every OTHER channelled spell, by key, in profile order, each key once (e.follows
                -- stores a KEY, so two slots holding the same ability are one candidate).
                local selfKey = PR.EntryKey(e)
                local cands, seen = {}, {}
                for j, o in ipairs(spells) do
                    local k = PR.EntryKey(o)
                    if j ~= i and k and k ~= selfKey and not seen[k] and o.channel
                            and not o.macroName and not o.itemID then
                        seen[k] = true
                        cands[#cands + 1] = k
                    end
                end
                if #cands == 0 and not e.follows then
                    VUI.Print("Priority Rotation",
                        VUI.COL.YELLOW .. "After|r waits for a channelled spell in this rotation, such as Eye Beam."
                        .. " Add one to the rotation first.")
                    return
                end
                local cur
                for idx, k in ipairs(cands) do
                    if k == e.follows then cur = idx; break end
                end
                -- none -> first candidate -> ... -> last -> none; a link to a non-candidate steps to the first.
                if cur then e.follows = cands[cur + 1] else e.follows = cands[1] end
                if not e.follows then e.followOnly = nil end
            end
            PR:SaveCurrentProfile(); editor:Refresh()
        end)
        follow:SetScript("OnEnter", function(self)
            local e = PR:CurrentProfile().spells[i]
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local target = FindEntryByKey(e.follows)
            local me = EntryDisplayName(e)
            if target and target.channel then
                GameTooltip:SetText(e.followOnly and "Only After" or "Also After", HIGHLIGHT_FONT_COLOR:GetRGB())
                GameTooltip:AddLine(format(e.followOnly
                    and VUI.COL.HIGHLIGHT .. "%s|r is held until " .. VUI.COL.BRIGHTBLUE
                        .. "%s|r finishes channelling, then cast on the next press. It is never cast on its own."
                    or  VUI.COL.HIGHLIGHT .. "%s|r is cast on the next press after " .. VUI.COL.BRIGHTBLUE
                        .. "%s|r finishes channelling, and also at its normal frequency.",
                    me, EntryDisplayName(target)), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
            elseif target then
                GameTooltip:SetText("After", HIGHLIGHT_FONT_COLOR:GetRGB())
                GameTooltip:AddLine(format("Not active: " .. VUI.COL.BRIGHTBLUE .. "%s|r is not a channelled spell,"
                    .. " and only a channel can be waited for. If it is one, cast it once and the"
                    .. " link turns on.", EntryDisplayName(target)),
                        RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
            else
                GameTooltip:SetText("After", HIGHLIGHT_FONT_COLOR:GetRGB())
                GameTooltip:AddLine("Not linked. Pick a channelled spell (such as Eye Beam) and this"
                    .. " ability is cast right after it finishes.",
                        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(e.follows and "Click to change · Right-click: Also / Only After"
                or "Click to pick", LIGHTBLUE_FONT_COLOR:GetRGB())
            GameTooltip:Show()
        end)
        follow:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.followBtn = follow

        -- Combat: compiles [combat] into this entry's conditional (spells and trinkets only; a macro's body is the
        -- player's own, so it has no switch). The entry left off is the opener.
        local combat = API.Switch(row)
        combat:SetPoint("RIGHT", row, "RIGHT", -switchR, 0)
        combat:SetScript("OnClick", function(self)
            local e = PR:CurrentProfile().spells[i]
            if not e then return end
            e.combatOnly = (not e.combatOnly) or nil
            if self.SetOn then self.SetOn(e.combatOnly == true) end
            PR:SaveCurrentProfile(); editor:Refresh()
        end)
        combat:SetScript("OnEnter", function(self)
            Tip(self, "Combat only", "On: compiled with " .. VUI.COL.HIGHLIGHT .. "[combat]|r -- this ability only"
                .. " casts while in combat. Leave your opener off so a key press out of combat can start the fight.")
        end)
        combat:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.combatChk = combat

        rows[i] = row
    end

    -- ── COMPILED SEQUENCE ──────────────────────────────────────
    local seqSec = UI.Section(child)
    seqSec:SetWidth(W)
    seqSec.Set("Compiled sequence")
    local seqText = API.Text(child, "small", "LEFT")
    seqText:SetWidth(W)
    seqText:SetWordWrap(true)
    if seqText.SetSpacing then seqText:SetSpacing(3) end
    UI.Ink(seqText, "TEXT")
    editor.seqText = seqText

    local foot = UI.Footer(page)
    editor.foot = foot
    foot.Set({
        { text = "Scan & Bind", primary = true, onClick = function() SlashCmdList["DAYLIGHTPR"]("scan") end },
        { text = "Clear All Spells", onClick = function()
            PR:CurrentProfile().spells = {}
            PR:CompileSequence()
            PR:RefreshUI()
        end },
    })

    -- ── Drag to reorder ──────────────────────────────────────
    -- The line under the cursor; above the first counts as 1, below the last filled line as the last.
    local function SlotUnderCursor(numSpells)
        if numSpells < 1 then return nil end
        local _, cy = GetCursorPosition()
        local scale = rows[1]:GetEffectiveScale()
        if not cy or not scale or scale == 0 then return nil end
        cy = cy / scale
        local top1, bottomN = rows[1]:GetTop(), rows[numSpells]:GetBottom()
        if top1 and cy > top1 then return 1 end
        for k = 1, numSpells do
            local t, b = rows[k]:GetTop(), rows[k]:GetBottom()
            if t and b and cy <= t + UI.LINE_SPACE and cy >= b then return k end
        end
        if bottomN and cy < bottomN then return numSpells end
        return nil
    end

    local dragDriver = CreateFrame("Frame", nil, page)
    dragDriver:Hide()
    local dragFrom, dragTo
    local function ShowMark(slot)
        for k = 1, PR.MAX_SLOTS do rows[k].Mark(k == slot) end
    end
    dragDriver:SetScript("OnUpdate", function()
        dragTo = SlotUnderCursor(#PR:CurrentProfile().spells) or dragTo
        ShowMark(dragTo)
    end)

    function editor:StartReorder(from)
        local spells = PR:CurrentProfile().spells
        if not spells[from] or #spells < 2 then return end
        dragFrom, dragTo = from, from
        GameTooltip:Hide()
        rows[from]:SetAlpha(0.5)
        ShowMark(from)
        dragDriver:Show()
    end

    function editor:FinishReorder()
        if not dragFrom then return end
        dragDriver:Hide()
        local from = dragFrom
        dragFrom = nil
        rows[from]:SetAlpha(1)
        ShowMark(nil)
        local spells = PR:CurrentProfile().spells
        local to = SlotUnderCursor(#spells) or dragTo
        if to and to ~= from and spells[from] then
            -- "After" links store the target's KEY, not its slot, so they survive the move.
            local entry = table.remove(spells, from)
            table.insert(spells, math.max(1, math.min(to, #spells + 1)), entry)
            PR:SaveCurrentProfile()
        end
        editor:Refresh()
    end

    -- A drag cut short by the window closing ends without moving anything.
    page:HookScript("OnHide", function()
        if dragFrom then
            dragDriver:Hide()
            rows[dragFrom]:SetAlpha(1)
            dragFrom = nil
            ShowMark(nil)
        end
    end)

    local function SequenceText()
        if #PR.compiledSequence == 0 then
            local links = AfterLinksText()
            return links ~= "" and links:gsub("^\n\n", "") or (UI.Hex("OFF") .. "Empty: add abilities above.|r")
        end
        local names = {}
        for idx, cast in ipairs(PR.compiledSequence) do
            local n = PR.compiledNames and PR.compiledNames[idx]
            if n then
                local mTag, iTag = n:match("^%[MACRO:(.-)%]$"), n:match("^%[ITEM:(.-)%]$")
                names[#names + 1] = mTag and ("[M:" .. mTag .. "]") or iTag and ("[T:" .. iTag .. "]") or n
            else
                names[#names + 1] = cast:gsub("^/cast ", ""):gsub("^/use ", "")
            end
        end
        return table.concat(names, " > ") .. AfterLinksText()
    end

    -- ── Refresh: fill the lines and lay the page out ──────────
    function editor:Refresh()
        local spells = PR:CurrentProfile().spells
        local n = #spells
        sec:ClearAllPoints()
        sec:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        sec.Set("Rotation", nil)
        local y = UI.SECTION_H
        for i = 1, PR.MAX_SLOTS do
            local row, e = rows[i], spells[i]
            local shown = i <= n + 1
            row:SetShown(shown)
            if shown then
                y = y + UI.LINE_SPACE
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                y = y + UI.LINE
            end
            if shown and e and (e.spellID or e.macroName or e.itemID) then
                -- A macro's icon is read again (it may have changed), and a trinket's (an upgrade).
                local icon = e.icon
                if e.macroName then
                    local _, fresh = GetMacroInfo(e.macroName)
                    if fresh then icon = fresh; e.icon = fresh end
                elseif e.itemID then
                    local ok, _, _, _, _, _, _, _, _, _, fresh = pcall(C_Item.GetItemInfo, e.itemID)
                    if ok and fresh then icon = fresh; e.icon = fresh end
                end
                row.right = row.freqFrame   -- the text stops short of the controls
                row.Set({ icon = icon, text = e.spellName or e.macroName or e.itemName, sub = SubText(e, spells) })
                row.freqLbl:SetText("x" .. (e.freq or 1))
                row.decBtn:SetEnabled((e.freq or 1) > 1)
                row.incBtn:SetEnabled((e.freq or 1) < 5)
                row.freqFrame:Show()
                -- After: the target's icon when the link resolves, grey while it has not been seen channelling.
                local target = FindEntryByKey(e.follows, spells)
                if target and target.icon then
                    row.followBtn.tex:SetTexture(target.icon)
                    row.followBtn.tex:SetDesaturated(not target.channel)
                    row.followBtn.tex:Show()
                else
                    row.followBtn.tex:Hide()
                end
                row.followBtn.lock:SetShown(target and e.followOnly and true or false)
                row.followBtn:Show()
                if e.macroName then
                    row.combatChk:Hide()
                else
                    if row.combatChk.SetOn then row.combatChk.SetOn(e.combatOnly == true) end
                    row.combatChk:Show()
                end
            elseif shown then
                -- No controls on the empty line, so its text runs the line's full width (owner, 2026-11-25: it was
                -- cut short at the Frequency column and read "or...").
                row.right = false
                row.Set({ text = "Add an ability", sub = "Drag a spell, macro or trinket here, or click for your spellbook",
                    dim = true })
                row.freqFrame:Hide()
                row.followBtn:Hide()
                row.combatChk:Hide()
            end
        end
        y = y + UI.SECTION_GAP
        seqSec:ClearAllPoints()
        seqSec:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        y = y + UI.SECTION_H + 6
        seqText:ClearAllPoints()
        seqText:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        seqText:SetText(SequenceText())
        local h = seqText:GetStringHeight()
        y = y + ((type(h) == "number" and h > 0) and math.ceil(h) or 14) + 8
        list:SetHeight(y)
    end

    PR.Editor = editor
    editor:Refresh()   -- laid out before the window first shows
    return editor
end
