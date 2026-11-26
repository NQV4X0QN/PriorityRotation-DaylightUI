-- Priority Rotation (DaylightUI Plugin) / Look.lua
-- The rotation window in DaylightUI's look, through its public API (DaylightUI/API.md "Skin another addon's
-- window"): me.RegisterSkin(addon, fn) runs fn(Kit) once this addon has loaded and DaylightUI's Skins module is on;
-- Kit.Window(frame) gives a window its shell, title and close X, Kit.Auto(root) dresses every standard control in
-- it and is safe to run again. Carried over from VeritasUI's SuiteLook (v1.90.0, owner-confirmed 2026-11-25).
-- With DaylightUI's Skins module off, nothing here runs and the window keeps the game's look.
-- Frames are found through the keys the window and editor announce (Lib.lua VUI.AnnounceFrame). Each is dressed
-- once, out of combat; controls a tab builds later are dressed when the window shows again.

local ADDON, ns = ...
local VUI = ns.VUI
if not VUI then return end

local pcall, ipairs, pairs, type = pcall, ipairs, pairs, type

local kit                 -- DaylightUI's Kit, once its skin has run
local waiting = {}        -- frames announced before that: { frame, how }
local dressed = setmetatable({}, { __mode = "k" })

-- DaylightUI's public API while the window wears its look, else nil.
function VUI.SuiteAPI()
    if not kit then return nil end
    local a = ns.API
    if type(a) == "table" and type(a.Text) == "function" and type(a.Colors) == "function" then return a end
    return nil
end

local function IsSideTab(f)
    return type(f) == "table" and type(f.Icon) == "table" and type(f.SelectedTexture) == "table"
end
local function TabSelected(tab) return tab.SelectedTexture:IsShown() == true end

-- Its windows have no tabs on their edge: the pages are words along the header, right to left from the close X, the
-- picked one in the accent with a line under it (owner, 2026-11-25, its character window). DaylightUI 2.2.7
-- Windows/Frame.lua Win.Tabs :215-260 (gap 14, text size body), Character/Window.lua LayoutTabs :127-147 (each as wide
-- as its word plus 4, at least 30), Options/Widgets.lua W.Tab :1712 (24 high). The look is its public Kit.Tab
-- (Skins Kit.lua:1598), driven through Kit.TabOf(tab).Pick. Lib's VUI.CreateSideTabs keeps its tabs on
-- win._sideTabs; they stay, out of sight and out of reach, and each header tab follows its side tab's shown state.
local TAB_GAP, TAB_H, TAB_PAD, TAB_MIN = 14, 24, 4, 30
local function HeaderTabs(Kit, win)
    local st = win._sideTabs
    local api = VUI.SuiteAPI()
    if type(st) ~= "table" or st.header or not (api and api.Text) then return false end
    local close = win.CloseButton
    if type(close) ~= "table" then return false end
    local head = {}
    local clicked
    local function Layout()
        local right = close
        for i = #head, 1, -1 do
            local b, side = head[i], st.list[i]
            local on = side and side:IsShown() == true
            b:SetShown(on)
            if on then
                local w = b.Text:GetStringWidth()
                b:SetWidth(math.max(TAB_MIN, math.ceil(type(w) == "number" and w or 0) + TAB_PAD))
                b:ClearAllPoints()
                b:SetPoint("RIGHT", right, "LEFT", -TAB_GAP, 0)
                right = b
            end
        end
        if win.OnHeaderTabs then win.OnHeaderTabs(right ~= close and right or nil) end
    end
    for i, spec in ipairs(st.specs) do
        local b = CreateFrame("Button", nil, win)
        b:SetHeight(TAB_H)
        b.Text = api.Text(b, "body", "CENTER")
        b.Text:SetPoint("CENTER", b, "CENTER", 0, 1)
        b.Text:SetText(spec.label or spec.tooltip or "")
        b:SetScript("OnClick", function()
            if st.selected == i then return end
            clicked = i
            st.onSelect(i)
            clicked = nil
        end)
        Kit.Tab(b, function() return st.selected == i end)
        head[i] = b
        local side = st.list[i]
        if side then
            side:SetAlpha(0)
            if side.EnableMouse then side:EnableMouse(false) end
            side:HookScript("OnShow", Layout)
            side:HookScript("OnHide", Layout)
        end
    end
    st.header = head
    st.Pick = function(index)
        local TabOf = Kit.TabOf
        for i, b in ipairs(head) do
            local t = type(TabOf) == "function" and TabOf(b)
            if t and t.Pick then t.Pick(i == index, clicked == i) end
        end
    end
    if st.selected then st.Pick(st.selected) end
    local name = win.GetName and win:GetName()
    if name then
        VUI.HeaderTabWindows[name] = true
        VUI.SetManagedPanelExtraWidth(name, nil)
    end
    win:HookScript("OnShow", Layout)   -- a word's width is only right once its font has loaded
    Layout()
    return true
end
local function SideTabs(Kit, win)
    if HeaderTabs(Kit, win) then return end
    for _, child in ipairs({ win:GetChildren() }) do
        if IsSideTab(child) then Kit.SideTab(child, TabSelected) end
    end
end

-- Its header: the title at the edge (16) and 12 down, a sub line 4 under it in the small size, the X at
-- TOPRIGHT -9, -15 (DaylightUI 2.2.7 Windows/Frame.lua Win.Header :167-211, Win.TITLE_Y :27, Win.CloseY :26-31).
-- Kit.Window leaves the game's X where it was, so it is placed here; the tabs hang off it. Character/Window.lua
-- :161 colours the name in the class colour (public as API.ClassColor); win.suiteClassColor asks for that.
local function ClosePlace(win)
    local close = win.CloseButton
    if type(close) ~= "table" then return end
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -9, -15)
end
local function Header(Kit, win)
    ClosePlace(win)
    local tc = win.TitleContainer
    local title = (type(tc) == "table" and tc.TitleText) or win.TitleText
    if type(title) ~= "table" then return end
    local api = VUI.SuiteAPI()
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -12)
    title:SetJustifyH("LEFT")
    local sub = win.suiteSub
    if sub then
        if Kit.Font then Kit.Font(sub, 12) end
        sub:ClearAllPoints()
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        sub:SetJustifyH("LEFT")
    end
    if win.suiteClassColor and api and api.ClassColor and Kit.Light then
        local ok, _, classFile = pcall(UnitClass, "player")
        if ok and classFile then
            local r, g, b = api.ClassColor(classFile)
            if type(r) == "number" then
                Kit.Light(title, { r, g, b })
                if sub then Kit.Light(sub, { r, g, b }) end
            end
        end
    end
    -- The title stops short of the tabs.
    win.OnHeaderTabs = win.OnHeaderTabs or function(left)
        title:SetPoint("RIGHT", left or win, left and "LEFT" or "RIGHT", left and -14 or -40, 0)
    end
end

-- Colours and sizes of its bag slots, which its API does not hand out (DaylightUI_Bags/Items.lua 2.2.7):
-- Style.BORDER for the backing (DaylightUI/Style.lua:296); an empty slot's ring and the well inside it
-- (Items.lua:76-77), a common item's ring (:78); ring 1 px empty, 2 px filled, one black pixel outside it and one
-- between it and the icon or well (:23-26); the highlight, white at 12% (:559-560); the icon's inner shadow, black
-- at 55% (:69-70); a hovered ring eased to the accent (:130).
local SUITE_BORDER = { 0.024, 0.024, 0.027 }
local SLOT_RING_EMPTY, SLOT_WELL, SLOT_RING_FULL = { 0.165, 0.149, 0.125 }, { 0.063, 0.063, 0.071 }, { 0.6, 0.6, 0.6 }

local function Fill(tex, c) tex:SetColorTexture(c[1], c[2], c[3], 1) end
local function Inset(tex, btn, n)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", btn, "TOPLEFT", n, -n)
    tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -n, n)
end
-- n screen pixels in `frame`'s units, as its slots are measured in whole pixels.
local function Px(frame, n)
    local _, h = GetPhysicalScreenSize()
    local s = frame:GetEffectiveScale()
    if type(h) ~= "number" or h <= 0 or type(s) ~= "number" or s <= 0 then return n end
    return n * (768 / h) / s
end

-- An icon slot in its bags' look (owner, 2026-11-25). The ring is DaylightUI's own shell (API.Skin with the options
-- its bags use, API.lua:995-1002), recoloured through Kit.Paint. `btn.tex` is the icon; it says empty or filled by
-- being hidden or shown.
local function SuiteSlot(btn)
    local api = VUI.SuiteAPI()
    if not (api and type(api.Skin) == "function") or type(btn) ~= "table" or type(btn.tex) ~= "table"
        or btn.suiteSlot then return end
    local thin = not btn.tex:IsShown()
    local opts = { noBevel = true, noBackground = true, shadowPx = 0, shadowAlpha = 0 }
    opts.borderPx = function() return thin and 1 or 2 end
    local shell = api.Skin(btn, opts)
    if type(shell) ~= "table" or not shell.CreateTexture then return end
    if btn.border then btn.border:SetAlpha(0) end
    if btn.empty then btn.empty:SetAlpha(0) end
    local back = shell:CreateTexture(nil, "BACKGROUND", nil, -7)
    Fill(back, SUITE_BORDER)
    back:SetAllPoints(btn)
    local well = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
    Fill(well, SLOT_WELL)
    local shadeFile = api.Media and api.Media("inner-shadow.png")
    local shade = btn:CreateTexture(nil, "ARTWORK", nil, 3)
    if shadeFile then shade:SetTexture(shadeFile) end
    shade:SetVertexColor(0, 0, 0, 0.55)
    shade:SetAllPoints(btn.tex)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.12)
    btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hovered = false
    local function Paint()
        local c = thin and SLOT_RING_EMPTY or SLOT_RING_FULL
        if hovered then local r, g, b = api.Accent(); c = { r, g, b } end
        if kit and kit.Paint then pcall(kit.Paint, shell, c) end
    end
    local function Layout()
        local e = Px(btn, 1)
        shell:ClearAllPoints()
        shell:SetPoint("TOPLEFT", btn, "TOPLEFT", e, -e)
        shell:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -e, e)
        api.Skin(btn, opts)                       -- lays the shell out again at its new size and ring width
        local inner = Px(btn, 1 + (thin and 1 or 2) + 1)
        Inset(well, btn, inner)
        Inset(btn.tex, btn, inner)
        well:SetShown(thin)
        shade:SetShown(not thin)
        hl:ClearAllPoints()
        hl:SetAllPoints(thin and well or btn.tex)
        Paint()
    end
    local function Set(filled)
        thin = not filled
        Layout()
    end
    btn:HookScript("OnEnter", function() hovered = true; Paint() end)
    btn:HookScript("OnLeave", function() hovered = false; Paint() end)
    hooksecurefunc(btn.tex, "Show", function() Set(true) end)
    hooksecurefunc(btn.tex, "Hide", function() Set(false) end)
    Layout()
    btn.suiteSlot = Set
end

local HOW = {}
-- The whole window: its shell, then every control in it; its header as its own, its tabs into the header.
function HOW.window(Kit, win)
    Kit.Window(win)
    Kit.Auto(win)
    Header(Kit, win)
    SideTabs(Kit, win)
    win:HookScript("OnShow", function(self)
        if not InCombatLockdown() then pcall(Kit.Auto, self) end
    end)
end
-- A step row: no mount-list block behind it (row.cardArt, Editor.lua), its icon and After slots in the bags' look.
function HOW.prRow(Kit, row)
    for _, t in ipairs(row.cardArt or {}) do t:SetAlpha(0) end
    SuiteSlot(row.iconBtn)
    SuiteSlot(row.followBtn)
    Kit.Auto(row)
end
-- The Compiled Sequence card: no block either; the window's own background shows through.
function HOW.prCard(Kit, card)
    for _, t in ipairs(card.cardArt or {}) do t:SetAlpha(0) end
    Kit.Auto(card)
end

local function Dress(frame, how)
    if dressed[frame] or not kit then return end
    if InCombatLockdown() then
        VUI.CombatQueue.Add(function() Dress(frame, how) end)
        return
    end
    dressed[frame] = true
    local ok, err = pcall(HOW[how], kit, frame)
    if not ok and VUI.debug then VUI.Print("Priority Rotation", "Look: " .. tostring(err)) end
end

local function Want(frame, how)
    if type(frame) ~= "table" then return end
    if kit then Dress(frame, how) else waiting[#waiting + 1] = { frame, how } end
end

-- Repaints a side tab after VUI.CreateSideTabs moved the selection (the Kit repaints on a click itself).
function VUI.SuiteLookRepaint(tab)
    if kit and type(kit.RepaintRow) == "function" then pcall(kit.RepaintRow, tab) end
end

for key, how in pairs({
    ["PriorityRotation.Window"] = "window",
    ["PriorityRotation.EditorRow"] = "prRow",
    ["PriorityRotation.SequenceCard"] = "prCard",
}) do
    VUI.OnFrameBuilt(key, function(frame) Want(frame, how) end)
end

if type(ns.me) == "table" and type(ns.me.RegisterSkin) == "function" then
    pcall(ns.me.RegisterSkin, ADDON, function(Kit)
        if type(Kit) ~= "table" or type(Kit.Window) ~= "function" or type(Kit.Auto) ~= "function" then
            return true
        end
        kit = Kit
        local list = waiting
        waiting = {}
        for _, w in ipairs(list) do Dress(w[1], w[2]) end
        return true
    end)
end
