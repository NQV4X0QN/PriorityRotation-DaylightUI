-- Priority Rotation (DaylightUI Plugin) / Settings.lua
-- The window: DaylightUI's window look (Widgets.lua), laid out like its trainer window, with two header tabs:
-- Rotation (Editor.lua) and Settings (below). Its options page is in DaylightUI's options window (Options.lua).

local _, PR = ...
local VUI = PR.VUI
if not VUI then return end

local UI, API = PR.UI, PR.API

-- Blizzard's UI panel manager places the window, as before (registered at file load, before the window exists).
-- pushable 2 (owner, 2026-11-07): Blizzard sorts pushable windows left to right by this value, lowest first
-- (UIParentPanelManager.lua:54-58), so Professions (1) takes the far left, then ours, then Character Info (3).
VUI.RegisterManagedPanel("PriorityRotMainWindow", {
    area     = "left",
    pushable = 2,
})

-- ── The Settings page ────────────────────────────────────────────
local function BuildSettingsPage(page, win)
    local list = UI.List(page, 10, UI.FOOT)
    local W, child = list.width, list.child
    local y = 0
    local function Section(label, first)
        if not first then y = y + UI.SECTION_GAP end
        local s = UI.Section(child)
        s:SetWidth(W)
        s:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        s.Set(label)
        y = y + UI.SECTION_H + 6
        return s
    end
    local function Body(text)
        local fs = API.Text(child, "small", "LEFT")
        fs:SetWidth(W)
        fs:SetWordWrap(true)
        if fs.SetSpacing then fs:SetSpacing(3) end
        fs:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        fs:SetText(text)
        UI.Ink(fs, "TEXT")
        local h = fs:GetStringHeight()
        y = y + ((type(h) == "number" and h > 0) and math.ceil(h) or 14)
        return fs
    end
    local KEY = UI.Hex("VALUE")

    Section("How it works", true)
    Body("Press your rotation key again and again to step through your rotation. The game's own cooldown and "
        .. "resource checks skip whatever isn't ready.")

    -- Targeting: per spec. Writes CurrentProfile().reacquire and recompiles, so the reacquire prefix is baked into
    -- (or out of) the spell steps at once. Shown again for the current spec in win:RefreshBadge.
    Section("Targeting")
    local line = UI.Line(child)
    line:SetWidth(W)
    line:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    line.edge:Hide(); line.well:Hide()
    local sw = API.Switch(line)
    sw:SetPoint("RIGHT", line, "RIGHT", -8, 0)
    line.right = sw
    line.Set({ text = "Auto-target the next enemy", sub = "When your target dies. Set for each specialization." })
    line.block:ClearAllPoints()
    line.block:SetPoint("LEFT", line, "LEFT", 4, 0)
    line.block:SetPoint("RIGHT", sw, "LEFT", -10, 0)
    local function Toggle()
        local p = PR:CurrentProfile()
        p.reacquire = not p.reacquire
        if sw.SetOn then sw.SetOn(p.reacquire == true) end
        PR:CompileSequence()
        VUI.Print("Priority Rotation", p.reacquire
            and "Auto-target on death " .. VUI.COL.GREEN .. "enabled|r for this spec."
            or  "Auto-target on death " .. VUI.COL.RED .. "disabled|r for this spec.")
    end
    sw:SetScript("OnClick", Toggle)
    line:SetScript("OnClick", Toggle)
    win.reacqSwitch = sw
    y = y + UI.LINE + 4
    Body("When your target dies, holding the rotation key switches to the nearest enemy. Only a target's death or "
        .. "your own tab or click ever changes targets: a live target you picked is never overridden.")

    Section("Setup")
    Body("1.  Click " .. KEY .. "Create Macro|r below\n"
        .. "2.  Drag " .. KEY .. "Attack|r from /macro onto any action bar\n"
        .. "3.  Bind a key to that bar slot\n"
        .. "4.  Click " .. KEY .. "Scan & Bind|r on the Rotation page")
    list:SetHeight(y + 8)

    -- ⛔ Priority Rotation does NOT open the spellbook itself (v1.22.1: doing so tainted it, and a spell clicked in
    -- it was refused). The Spellbook button's click is taken by SpellbookOpener.lua's secure overlay and forwarded
    -- to Blizzard's menu-bar spellbook button; PR.ToggleSpellBookPanel only explains when the overlay is absent.
    local foot = UI.Footer(page)
    foot.Set({
        { text = "Create Macro", primary = true, onClick = function() SlashCmdList["DAYLIGHTPR"]("macro") end },
        { text = "Spellbook", onClick = function() PR.ToggleSpellBookPanel() end },
        { text = "Macros", onClick = function() PR.ToggleMacroPanel() end },
    })
    if PR.SpellbookOpener and foot.buttons[2] then PR.SpellbookOpener.AddTarget(foot.buttons[2]) end
    page.foot = foot
end

-- ── The window ───────────────────────────────────────────────────
local function BuildMainWindow()
    local win = UI.Window({ name = "PriorityRotMainWindow", title = "Priority Rotation",
        onClose = function(w) VUI.CloseManagedPanel(w) end })

    local pages = {}
    for _, id in ipairs({ "editor", "settings" }) do
        local p = CreateFrame("Frame", nil, win.host)
        p:SetAllPoints(win.host)
        p:Hide()
        pages[id] = p
    end
    win.pages = pages

    local function ActivateTab(which)
        win:PickTab(which)
        for id, p in pairs(pages) do p:SetShown(id == which) end
    end
    win:SetHeaderTabs({ { id = "editor", text = "Rotation" }, { id = "settings", text = "Settings" } }, ActivateTab)
    ActivateTab("editor")

    -- The spec under the title, both in your class colour (its character window colours the name so).
    function win:RefreshBadge()
        self.sub:SetText(PR:GetCurrentSpecLabel())
        local _, classFile = UnitClass("player")
        local r, g, b
        if classFile and API.ClassColor then r, g, b = API.ClassColor(classFile) end
        if type(r) == "number" then
            self.title:SetTextColor(r, g, b)
            self.sub:SetTextColor(r, g, b)
        end
        if self.reacqSwitch and self.reacqSwitch.SetOn then
            self.reacqSwitch.SetOn(PR:CurrentProfile().reacquire == true)
        end
        self:Repaint()
    end

    function win:ShowTab(which)
        VUI.OpenManagedPanel(self)
        ActivateTab(which)
        self:RefreshBadge()
        if PR.Editor then PR.Editor:Refresh() end
    end

    PR:BuildEditor(pages.editor)
    BuildSettingsPage(pages.settings, win)

    win:SetScript("OnShow", function()
        win:RefreshBadge()
        if PR.Editor then PR.Editor:Refresh() end
    end)
    -- The Spellbook's sound (Blizzard_PlayerSpellsFrame.lua): this is a window of your spells (after SetScript).
    if VUI.AddWindowSounds and SOUNDKIT then
        VUI.AddWindowSounds(win, SOUNDKIT.UI_CLASS_TALENT_OPEN_WINDOW, SOUNDKIT.UI_CLASS_TALENT_CLOSE_WINDOW)
    end

    PR.MainWindow = win
    win:RefreshBadge()
end

-- ── On / off ─────────────────────────────────────────────────────
-- The switch is on the plugin's DaylightUI options page (Options.lua), which calls this.
function PR:SetEnabled(value, quiet)
    value = value and true or false
    if not self.db or self.db.enabled == value then return end
    self.db.enabled = value
    if value then
        self:CompileSequence()
        self:ScheduleScan(0.5)
        if not quiet then VUI.Print("Priority Rotation", VUI.COL.GREEN .. "Enabled.|r") end
    else
        self:ClearOverride()
        if not quiet then VUI.Print("Priority Rotation", VUI.COL.RED .. "Disabled.|r") end
    end
end

-- ── Startup ───────────────────────────────────────────────────────
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    local ok, err = pcall(BuildMainWindow)
    if not ok then
        VUI.Print("Priority Rotation", VUI.COL.RED .. "Editor error:|r " .. tostring(err))
    end
    initFrame:UnregisterAllEvents()
end)
