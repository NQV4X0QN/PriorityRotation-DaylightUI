-- Priority Rotation (DaylightUI Plugin) / Widgets.lua
-- The window's pieces in DaylightUI's look, built only from its public API (DaylightUI/API.md "Look like Daylight
-- UI": API.Skin, API.Text, API.Button, API.MainButton, API.Close, API.Switch, API.Colors, API.Accent, API.Media).
-- Its own windows' layout pieces (headers, header tabs, list sections and lines, the footer, the scroll pill) are
-- not in its API, so they are drawn here to its measurements, read from DaylightUI 2.3.0 (never copied):
--   Windows/Frame.lua  Win.New / Win.Header / Win.Lines / Win.Tabs: header 56 high, edge 16, round portrait 40
--                      at (16, -8) with a rim 3 px out tinted Style.BAND, title (title size, VALUE) at the
--                      portrait + 12 and 12 down, a sub line (small, LABEL) 4 under it, the X at TOPRIGHT -9, -15,
--                      header tabs right to left from the X 14 apart, a 2 px accent line 6 in and 2 down at 0.7,
--                      a faint 1 px rule (white 6%) under the header.
--   Options/Widgets.lua W.TabLook / W.Tab: 24 high, body size, tan (LABEL) at rest, VALUE on hover, the accent
--                      when picked with a 2 px accent line along its bottom; each as wide as its word plus 4, at
--                      least 30 (Character/Window.lua LayoutTabs). W.SCROLL: a 4 px pill 6 right of the list, track
--                      white 4%, thumb white 22% (38% hovered), at least 24 tall, 48 px a wheel notch.
--   Windows/Parts.lua  Stack: lists 16 in from the sides; Section 22 high (small size, upper case, in the accent,
--                      4 up from a 1 px white-6% line), 12 above a section; Line 36 high, 2 apart: a hover wash
--                      white 6%, a picked wash in the accent at 16%, a 30 px icon edge (0.23, 0.23, 0.26) 4 in, the
--                      icon 1 px inside it and cropped, name (body, VALUE; OFF when dim) and sub (small, LABEL) 3
--                      apart as one block 10 right of the icon, a value (body) 8 in from the right.
--   Windows/Parts.lua  Footer: 28 high, 12 up from the bottom, 16 in, a faint line 10 above it; the main action on
--                      the left, the rest packed right 8 apart, each its text + 32 wide and at least 110.
--   Npc/Train.lua, Npc/Window.lua: the trainer window is 440 wide and 540 high, its footer 52.

local _, PR = ...
local VUI = PR.VUI
if not VUI then return end

local API = PR.API
local UI = {}
PR.UI = UI

UI.W, UI.H = 440, 540
UI.EDGE, UI.HEADER, UI.PORTRAIT, UI.FOOT = 16, 56, 40, 52
UI.TITLE_Y, UI.CLOSE_X, UI.CLOSE_Y = -12, -9, -15
UI.TAB_H, UI.TAB_GAP, UI.TAB_PAD, UI.TAB_MIN = 24, 14, 4, 30
UI.SECTION_H, UI.SECTION_GAP = 22, 12
UI.LINE, UI.LINE_ICON, UI.LINE_GAP, UI.LINE_SPACE = 36, 28, 3, 2
UI.FOOT_H, UI.FOOT_GAP, UI.FOOT_FIT, UI.FOOT_PAD = 28, 8, 110, 32
UI.PILL_W, UI.PILL_GAP, UI.PILL_MIN, UI.WHEEL = 4, 6, 24, 48
UI.HI, UI.RULE = { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.06 }
UI.PICKED = 0.16
UI.ICON_EDGE = { 0.23, 0.23, 0.26 }
UI.BAND = { 0.10, 0.09, 0.065 }   -- Style.BAND (DaylightUI/Style.lua:297): the shell's warm band
UI.MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- A text colour by DaylightUI's name for it ("VALUE", "TEXT", "LABEL", "OFF", "GOOD", "WARN", "BAD"), or "pop" for
-- the accent. Read each time: the player can change the accent and DaylightUI its colours.
function UI.Color(name)
    if name == "pop" then return { API.Accent() } end
    local c = API.Colors()[name]
    return c or { 1, 1, 1 }
end
-- Text takes the colour as its text colour, art (a texture) as its tint.
function UI.Ink(fs, name, alpha)
    local c = UI.Color(name)
    if fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3], alpha or 1)
    else fs:SetVertexColor(c[1], c[2], c[3], alpha or 1) end
end
function UI.Hex(name)
    local c = UI.Color(name)
    local function h(v) return math.max(0, math.min(255, math.floor((v or 1) * 255 + 0.5))) end
    return string.format("|cff%02x%02x%02x", h(c[1]), h(c[2]), h(c[3]))
end

function UI.Tex(parent, layer, c, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(WHITE)
    if c then t:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
    return t
end
function UI.PaintAccent(tex, alpha)
    local r, g, b = API.Accent()
    tex:SetVertexColor(r or 1, g or 1, b or 1, alpha or 1)
end
function UI.Rule(parent)
    local t = UI.Tex(parent, "ARTWORK", UI.RULE)
    t:SetHeight(1)
    return t
end
function UI.CropIcon(t) t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

-- Its class art for the player's class (DaylightUI's Media\class set, as its unit frames use it), else nil.
local CLASS_ART = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true,
                    MAGE = true, WARLOCK = true, DRUID = true }
function UI.ClassArt()
    local _, classFile = UnitClass("player")
    if not (classFile and CLASS_ART[classFile] and API.Media) then return nil end
    return API.Media("class\\" .. string.lower(classFile) .. ".tga"), classFile
end

-- ── The window ────────────────────────────────────────────────────
-- spec: name, title. Returns the window with win.title, win.sub, win.close, win.host (the page area under the
-- header) and win:SetHeaderTabs(list, onPick) / win:PickTab(id).
function UI.Window(spec)
    local win = CreateFrame("Frame", spec.name, UIParent)
    win:SetSize(UI.W, UI.H)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:Hide()
    win.tabs, win.tab, win.reacqSwitch = {}, false, false
    API.Skin(win, { window = true })

    -- The portrait: its class art the size of the round opening, masked round, the whole picture shown, with the
    -- rim around it -- as its spellbook window's header shows the class (Book/Window.lua classIcon: the art at
    -- texcoords 0-1 in Win.Header's 40 px portrait, masked with TempPortraitAlphaMask, Windows/Frame.lua:173-180).
    -- Not its unit frames' 1.15 fill, which zoomed the picture in (owner, 2026-11-25).
    local E = UI.EDGE
    local hole = CreateFrame("Frame", nil, win)
    hole:SetSize(UI.PORTRAIT, UI.PORTRAIT)
    hole:SetPoint("TOPLEFT", win, "TOPLEFT", E, -8)
    local art = hole:CreateTexture(nil, "ARTWORK")
    art:SetSize(UI.PORTRAIT, UI.PORTRAIT)
    art:SetPoint("CENTER", hole, "CENTER", 0, 0)
    art:SetTexCoord(0, 1, 0, 1)
    local file = UI.ClassArt()
    if file then art:SetTexture(file) end
    local mask = hole.CreateMaskTexture and hole:CreateMaskTexture()
    if mask then
        mask:SetTexture(UI.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(art)
        art:AddMaskTexture(mask)
    end
    local rim = hole:CreateTexture(nil, "OVERLAY")
    if API.Media then rim:SetTexture(API.Media("portrait-rim.png")) end
    rim:SetPoint("TOPLEFT", hole, "TOPLEFT", -3, 3)
    rim:SetPoint("BOTTOMRIGHT", hole, "BOTTOMRIGHT", 3, -3)
    rim:SetVertexColor(UI.BAND[1], UI.BAND[2], UI.BAND[3], 1)
    win.portrait, win.portraitArt = hole, art

    local left = E + UI.PORTRAIT + 12
    win.title = API.Text(win, "title", "LEFT")
    win.title:SetPoint("TOPLEFT", win, "TOPLEFT", left, UI.TITLE_Y)
    win.title:SetPoint("RIGHT", win, "RIGHT", -40, 0)
    win.title:SetWordWrap(false)
    win.title:SetText(spec.title or "")
    UI.Ink(win.title, "VALUE")
    win.sub = API.Text(win, "small", "LEFT")
    win.sub:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -4)
    win.sub:SetPoint("RIGHT", win, "RIGHT", -40, 0)
    win.sub:SetWordWrap(false)
    UI.Ink(win.sub, "LABEL")

    win.close = API.Close(win, function() if spec.onClose then spec.onClose(win) else win:Hide() end end)
    win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", UI.CLOSE_X, UI.CLOSE_Y)

    local line = UI.Tex(win, "ARTWORK")
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", win, "TOPLEFT", 6, -2)
    line:SetPoint("TOPRIGHT", win, "TOPRIGHT", -6, -2)
    win.topLine = line
    local rule = UI.Rule(win)
    rule:SetPoint("TOPLEFT", win, "TOPLEFT", E, -UI.HEADER)
    rule:SetPoint("TOPRIGHT", win, "TOPRIGHT", -E, -UI.HEADER)

    win.host = CreateFrame("Frame", nil, win)
    win.host:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -UI.HEADER - 1)
    win.host:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)

    function win:Repaint()
        UI.PaintAccent(self.topLine, 0.7)
        for _, t in ipairs(self.tabs or {}) do t.Paint(t:IsMouseOver() == true) end
    end

    -- Header tabs, right to left from the X; the title and sub line stop short of them.
    function win:SetHeaderTabs(list, onPick)
        self.tabs, self.onTab = {}, onPick
        for i, t in ipairs(list) do
            local b = UI.Tab(self, t.text)
            b.id = t.id
            b:SetScript("OnClick", function()
                if self.tab == b.id then return end
                self:PickTab(b.id)
                if self.onTab then self.onTab(b.id) end
            end)
            self.tabs[i] = b
        end
        self:FitTabs()
        self:HookScript("OnShow", function(s) s:FitTabs(); s:Repaint() end)
    end
    function win:FitTabs()
        local right = self.close
        for i = #(self.tabs or {}), 1, -1 do
            local b = self.tabs[i]
            b.Fit()
            b:ClearAllPoints()
            b:SetPoint("RIGHT", right, "LEFT", -UI.TAB_GAP, 0)
            right = b
        end
        if right ~= self.close then
            self.title:SetPoint("RIGHT", right, "LEFT", -14, 0)
            self.sub:SetPoint("RIGHT", right, "LEFT", -14, 0)
        end
    end
    function win:PickTab(id)
        self.tab = id
        for _, b in ipairs(self.tabs or {}) do b.Pick(b.id == id) end
    end

    win:Repaint()
    return win
end

-- ── Header tab ────────────────────────────────────────────────────
function UI.Tab(parent, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(UI.TAB_H)
    b.text = API.Text(b, "body", "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.picked = false
    b.text:SetText(text or "")
    b.line = UI.Tex(b, "ARTWORK")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
    b.line:Hide()
    function b.Paint(over)
        if b.picked then UI.Ink(b.text, "pop") else UI.Ink(b.text, over and "VALUE" or "LABEL") end
        b.line:SetShown(b.picked == true)
        if b.picked then
            UI.PaintAccent(b.line, 1)
            b.line:SetWidth(math.max(0.01, b:GetWidth() or 0))
        end
    end
    function b.Pick(on)
        b.picked = on and true or false
        b.Paint(b:IsMouseOver() == true)
    end
    function b.Fit()
        local w = b.text:GetStringWidth()
        b:SetWidth(math.max(UI.TAB_MIN, math.ceil(type(w) == "number" and w or 0) + UI.TAB_PAD))
        b.Paint(b:IsMouseOver() == true)
    end
    b:SetScript("OnEnter", function() b.Paint(true) end)
    b:SetScript("OnLeave", function() b.Paint(false) end)
    b.Paint(false)
    return b
end

-- ── A scrolling list ──────────────────────────────────────────────
-- A ScrollFrame 16 in from the page's sides, `top` down and `bottom` up, with a child of the list's width and the
-- thin pill beside it. list.child holds the pieces; list:SetHeight(h) after laying them out.
function UI.List(page, top, bottom)
    local E = UI.EDGE
    local sf = CreateFrame("ScrollFrame", nil, page)
    sf:SetPoint("TOPLEFT", page, "TOPLEFT", E, -top)
    sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -E, bottom)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(UI.W - 2 * E, 1)
    sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    local list = { scroll = sf, child = child, width = UI.W - 2 * E }

    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", UI.PILL_GAP, 0)
    bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", UI.PILL_GAP, 0)
    bar:SetWidth(UI.PILL_W)
    bar:SetHitRectInsets(-6, -6, 0, 0)
    local pill = API.Media and API.Media("ui-pill.png")
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(bar)
    if pill then track:SetTexture(pill) else track:SetTexture(WHITE) end
    track:SetVertexColor(1, 1, 1, 0.04)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    if pill then thumb:SetTexture(pill) else thumb:SetTexture(WHITE) end
    thumb:SetWidth(UI.PILL_W)
    thumb:SetVertexColor(1, 1, 1, 0.22)
    bar:Hide()
    list.bar = bar

    local function range()
        local h, view = child:GetHeight() or 0, sf:GetHeight() or 0
        return math.max(0, h - view), view
    end
    function list:Update()
        local max, view = range()
        if max <= 0 or view <= 0 then
            sf:SetVerticalScroll(0)
            bar:Hide()
            return
        end
        bar:Show()
        local at = math.min(sf:GetVerticalScroll() or 0, max)
        local h = bar:GetHeight() or 0
        local th = math.min(h, math.max(UI.PILL_MIN, h * view / (max + view)))
        thumb:SetHeight(th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", bar, "TOP", 0, -(at / max) * (h - th))
    end
    function list:To(v)
        local max = range()
        sf:SetVerticalScroll(math.max(0, math.min(max, v)))
        self:Update()
    end
    function list:SetHeight(h)
        child:SetHeight(math.max(1, h))
        self:Update()
    end
    sf:SetScript("OnMouseWheel", function(_, delta) list:To((sf:GetVerticalScroll() or 0) - delta * UI.WHEEL) end)
    sf:HookScript("OnSizeChanged", function() list:Update() end)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function() thumb:SetVertexColor(1, 1, 1, 0.38) end)
    bar:SetScript("OnLeave", function() thumb:SetVertexColor(1, 1, 1, 0.22) end)
    bar:SetScript("OnMouseDown", function(self)
        self:SetScript("OnUpdate", function()
            local _, cy = GetCursorPosition()
            local s = self:GetEffectiveScale()
            local top, h = self:GetTop(), self:GetHeight()
            if not (cy and s and s > 0 and top and h and h > 0) then return end
            local max = range()
            list:To((top - cy / s) / h * max)
        end)
    end)
    bar:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    return list
end

-- ── Section header ────────────────────────────────────────────────
function UI.Section(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(UI.SECTION_H)
    b.text = API.Text(b, "small", "LEFT")
    b.text:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 4)
    b.text:SetWordWrap(false)
    b.line = UI.Rule(b)
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.value = API.Text(b, "small", "RIGHT")
    b.value:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 4)
    b.value:SetWordWrap(false)
    function b.Set(label, value)
        b.text:SetText(type(label) == "string" and label:upper() or "")
        UI.Ink(b.text, "pop")
        b.value:SetText(value or "")
        UI.Ink(b.value, "LABEL")
    end
    return b
end

-- ── List line ─────────────────────────────────────────────────────
-- A button UI.LINE high: hover wash, a mark wash (UI.Mark), the icon in its edge, name and sub as one block. The
-- caller anchors it, sets line.right (the frame the text block stops at, or nil for the line's right edge) and
-- paints it with line.Set{ icon, text, sub, dim }.
function UI.Line(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(UI.LINE)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.right, b.dim = false, false
    b.hi = UI.Tex(b, "BACKGROUND", UI.HI)
    b.hi:SetAllPoints(b)
    b.hi:Hide()
    b.mark = UI.Tex(b, "BORDER")
    b.mark:SetAllPoints(b)
    b.mark:Hide()
    b.edge = UI.Tex(b, "ARTWORK", UI.ICON_EDGE)
    b.edge:SetSize(UI.LINE_ICON + 2, UI.LINE_ICON + 2)
    b.edge:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.well = UI.Tex(b, "ARTWORK", { 0.063, 0.063, 0.071, 1 }, 1)
    b.well:SetPoint("TOPLEFT", b.edge, "TOPLEFT", 1, -1)
    b.well:SetPoint("BOTTOMRIGHT", b.edge, "BOTTOMRIGHT", -1, 1)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("TOPLEFT", b.edge, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b.edge, "BOTTOMRIGHT", -1, 1)
    UI.CropIcon(b.icon)
    b.block = CreateFrame("Frame", nil, b)
    b.name = API.Text(b.block, "body", "LEFT")
    b.name:SetPoint("TOPLEFT", b.block, "TOPLEFT", 0, 0)
    b.name:SetPoint("TOPRIGHT", b.block, "TOPRIGHT", 0, 0)
    b.name:SetWordWrap(false)
    b.sub = API.Text(b.block, "small", "LEFT")
    b.sub:SetPoint("BOTTOMLEFT", b.block, "BOTTOMLEFT", 0, 0)
    b.sub:SetPoint("BOTTOMRIGHT", b.block, "BOTTOMRIGHT", 0, 0)
    b.sub:SetWordWrap(false)
    local bodySize = select(2, b.name:GetFont()) or 13
    local smallSize = select(2, b.sub:GetFont()) or 12
    function b.Set(spec)
        if spec.icon then b.icon:SetTexture(spec.icon); b.icon:Show() else b.icon:Hide() end
        b.icon:SetDesaturated(spec.grey == true)
        local pair = spec.sub ~= nil and spec.sub ~= ""
        b.block:ClearAllPoints()
        b.block:SetPoint("LEFT", b.edge, "RIGHT", 10, 0)
        if b.right then b.block:SetPoint("RIGHT", b.right, "LEFT", -10, 0)
        else b.block:SetPoint("RIGHT", b, "RIGHT", -8, 0) end
        b.block:SetHeight(pair and (bodySize + UI.LINE_GAP + smallSize) or bodySize)
        b.name:SetText(spec.text or "")
        UI.Ink(b.name, spec.dim and "OFF" or "VALUE")
        b.sub:SetText(spec.sub or "")
        UI.Ink(b.sub, "LABEL")
        b.dim = spec.dim
    end
    function b.Mark(on)
        b.mark:SetShown(on == true)
        if on then UI.PaintAccent(b.mark, UI.PICKED) end
    end
    b:HookScript("OnEnter", function(self) if not self.dim then self.hi:Show() end end)
    b:HookScript("OnLeave", function(self) self.hi:Hide() end)
    return b
end

-- ── Footer ────────────────────────────────────────────────────────
-- foot.Set{ { text, primary, off, onClick }, ... }: the main action on the left, the rest packed to the right.
function UI.Footer(page)
    local E = UI.EDGE
    local f = CreateFrame("Frame", nil, page)
    f:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", E, 12)
    f:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -E, 12)
    f:SetHeight(UI.FOOT_H)
    local line = UI.Rule(f)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 10)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 10)
    f.buttons = {}
    function f.Set(list)
        for i, b in ipairs(f.buttons) do if not list[i] then b:Hide() end end
        local right
        for i = #list, 1, -1 do
            local spec = list[i]
            local b = f.buttons[i]
            if not b then
                b = API.Button(f, "", UI.FOOT_H)
                b:SetScript("OnClick", function(self)
                    if self.spec and not self.spec.off and self.spec.onClick then self.spec.onClick(self) end
                end)
                f.buttons[i] = b
            end
            b.spec = spec
            if b.text and b.text.SetText then b.text:SetText(spec.text or "") end
            local w = b.text and b.text:GetStringWidth()
            b:SetWidth(math.max(UI.FOOT_FIT, math.ceil(type(w) == "number" and w or 60) + UI.FOOT_PAD))
            if API.MainButton then API.MainButton(b, spec.primary == true) end
            if b.SetOff then b.SetOff(spec.off == true) end
            b:ClearAllPoints()
            if spec.primary then
                b:SetPoint("LEFT", f, "LEFT", 0, 0)
            else
                if right then b:SetPoint("RIGHT", right, "LEFT", -UI.FOOT_GAP, 0)
                else b:SetPoint("RIGHT", f, "RIGHT", 0, 0) end
                right = b
            end
            b:Show()
        end
    end
    return f
end
