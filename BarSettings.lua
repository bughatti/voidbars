----------------------------------------------------------------------
-- VoidBars — per-bar settings window. Move mode -> right-click a bar, or
-- Options -> "Bar settings", or /vbars bar. One window; "<" and ">" pick the bar.
--
-- Layout changes rebuild the bar as a grid (buttons / per row / size / spacing)
-- and keep its INNER edge, so everything grows outward from the middle: a bar
-- left of center keeps its right edge, right of center its left edge, a
-- centered bar its center. Smart bars (Consumables, Travel, Professions) keep
-- their own layout code; their button count follows their contents.
-- Everything here moves secure frames: out of combat only.
----------------------------------------------------------------------
-- Borders are one screen pixel (tools/cmd/pixelfix, 2026-11-09). WoW snaps each border
-- piece to the pixel grid, and a thin line on a fractional position can snap to 0 px: a side
-- of a box vanishes. VoidPX() asks for one real pixel, and the hook below (installed once, by
-- the first Void addon loaded) turns snapping off on the edges of flat WHITE8X8 borders, like
-- Blizzard's NineSliceUtil.DisableSharpening, so a 1 px line always covers a pixel.
local _, ns = ...   -- ns.Move (VoidMove.lua)
local function VoidPX()
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end
if not _G.__VoidBorderHook and hooksecurefunc and NineSliceUtil and NineSliceUtil.ApplyLayout then
    _G.__VoidBorderHook = true
    local EDGES = { "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
                    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
    hooksecurefunc(NineSliceUtil, "ApplyLayout", function(c)
        local i = type(c) == "table" and c.backdropInfo
        local e = i and i.edgeFile
        if type(e) ~= "string" or not e:lower():find("white8x8", 1, true) or (tonumber(i.edgeSize) or 0) > 3 then return end
        for _, k in ipairs(EDGES) do
            local t = c[k]
            if t and t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
            end
        end
    end)
end
local _, VB = ...

local win, current
local W, PAD = 340, 16

local function SideOf(cfg, w)
    local cx, mid = (cfg.x or 0) + w / 2, UIParent:GetWidth() / 2
    if math.abs(cx - mid) < 40 then return "center" end
    return cx < mid and "left" or "right"
end

-- A bar that was imported or preset has offsets but no cols / spacing saved: read
-- them off its current shape, so changing one setting doesn't reset the others.
local function Shape(cfg, bar)
    local size = cfg.size or VB.DEFAULT_SIZE
    local cols, spacing = cfg.cols, cfg.spacing
    local o = cfg.offsets
    if o and o[1] then
        if not spacing and o[2] and o[2][2] == o[1][2] and o[2][1] > o[1][1] then
            spacing = math.max(0, math.floor(o[2][1] - o[1][1] - size + 0.5))
        end
        if not cols then
            cols = 0
            for i = 1, #o do if o[i][2] == o[1][2] then cols = cols + 1 end end
        end
    end
    cols = math.max(1, math.min(#bar.buttons, cols or 12))
    return cols, spacing or VB.DEFAULT_SPACING, size
end

-- Rebuild a regular / pet / stance / marker bar as a grid, keeping its inner edge.
local function Regrid(bar)
    local cfg = VB:BarConfig(bar.def.key)
    local oldW = bar:GetWidth() or 0
    local side = SideOf(cfg, oldW)
    local num = math.min(cfg.num or #bar.buttons, #bar.buttons)
    local cols, spacing, size = Shape(cfg, bar)
    cfg.cols, cfg.spacing = cols, spacing
    cfg.offsets = VB.GridOffsets(num, cols, size, spacing)
    VB:LayoutBar(bar)
    local newW = bar:GetWidth() or 0
    if cfg.x and oldW > 1 then
        if side == "left" then
            cfg.x = cfg.x + oldW - newW
        elseif side == "center" then
            cfg.x = cfg.x + (oldW - newW) / 2
        end
        VB:LayoutBar(bar)
    end
end

local function ApplyLayout(bar)
    VB:RunOutOfCombat("barsettings-" .. bar.def.key, function()
        if bar.def.kind == "smart" then
            VB:RebuildSmartBars()
        else
            Regrid(bar)
        end
        VB:ApplyBindings()
        VB:QueueFullUpdate()
        VB:QueueDropSlots()
        VB:PlaceEncounterBar()
    end)
end

local function ApplyShown(bar)
    VB:RunOutOfCombat("barsettings-vis", function()
        VB:ApplyVisibility()
        VB:ApplyBindings()
        if VB.unlocked then VB:SetUnlocked(true) end   -- handles follow on / off
        VB:PlaceEncounterBar()
    end)
end

----------------------------------------------------------------------
-- Widgets
----------------------------------------------------------------------
local function Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    return fs
end

local function Check(parent, text, y, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", PAD - 4, y)
    cb:SetSize(26, 26)
    local fs = Label(parent, text)
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return cb
end

-- Slider row: label on the left, Blizzard's minimal slider with steppers on the right.
local function Slider(parent, text, y, min, max, onChange)
    local fs = Label(parent, text)
    fs:SetPoint("TOPLEFT", PAD, y - 4)
    fs:SetWidth(110)
    local s = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    s:SetPoint("TOPLEFT", PAD + 112, y)
    s:SetSize(W - PAD * 2 - 112 - 34, 20)   -- room on the right for the value text
    s.vbMin, s.vbMax, s.vbLabel = min, max, fs
    local pending = {}   -- [bar] = latest token: one pending edit per bar
    s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
        if s.vbLoading then return end
        v = math.floor(v + 0.5)
        -- dragging fires every tick: apply once it settles, to the bar it was
        -- changed on (the picker may have moved on by then)
        local target, token = current, {}
        pending[target] = token
        C_Timer.After(0.15, function()
            if pending[target] == token then pending[target] = nil; onChange(v, target) end
        end)
    end, s)
    function s:VBSet(value, maxOverride)
        local max2 = maxOverride or self.vbMax
        self.vbLoading = true
        self:Init(math.max(self.vbMin, math.min(max2, value)), self.vbMin, max2, max2 - self.vbMin, {
            [MinimalSliderWithSteppersMixin.Label.Right] = function(val) return tostring(math.floor(val + 0.5)) end,
        })
        self.vbLoading = false
    end
    function s:VBShow(on) self:SetShown(on); self.vbLabel:SetShown(on) end
    return s
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
local Refresh

local function Build()
    win = CreateFrame("Frame", "VoidBarsBarSettings", UIParent, "BackdropTemplate")
    win:SetSize(W, 372)
    win:SetPoint("TOP", 0, -170)   -- below move mode's "Lock VoidBars" button (TOP -120)
    win:SetFrameStrata("DIALOG")
    win:SetBackdrop({ bgFile = VB.TEX, edgeFile = VB.TEX, edgeSize = VoidPX() })
    win:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    win:SetBackdropBorderColor(VB.COLOR.accent:GetRGB())
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    ns.Move(win, { db = function() return VoidBarsDB end, key = "barSettings" })   -- drag + kept after a restart (VoidMove.lua)
    tinsert(UISpecialFrames, "VoidBarsBarSettings")   -- Esc closes it

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- bar picker: < Name >
    local prev = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    prev:SetSize(26, 22)
    prev:SetPoint("TOPLEFT", PAD, -14)
    prev:SetText("<")
    local nextB = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    nextB:SetSize(26, 22)
    nextB:SetPoint("TOPRIGHT", -36, -14)
    nextB:SetText(">")
    win.title = Label(win, "", "GameFontNormalLarge")
    win.title:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    win.title:SetPoint("RIGHT", nextB, "LEFT", -8, 0)
    win.title:SetJustifyH("CENTER")
    local function step(d)
        local list, at = VB.bars, 1
        for i, b in ipairs(list) do if b == current then at = i end end
        current = list[(at - 1 + d) % #list + 1]
        Refresh()
    end
    prev:SetScript("OnClick", function() step(-1) end)
    nextB:SetScript("OnClick", function() step(1) end)

    local y = -48
    win.enabled = Check(win, "Show this bar", y, function(on)
        VB:BarConfig(current.def.key).enabled = on
        if current.def.kind == "smart" then ApplyLayout(current) else ApplyShown(current) end
    end)
    y = y - 28
    win.fade = Check(win, "Fade out of combat (back on mouseover)", y, function(on)
        VB:BarConfig(current.def.key).fade = on
        if not on then current:SetAlpha(1) end
    end)

    y = y - 40
    local function layoutSetter(field)
        return function(v, bar)
            bar = bar or current
            local cfg = VB:BarConfig(bar.def.key)
            if bar.def.kind ~= "smart" then
                -- pin the current shape first: Shape() reads spacing off the old size
                local cols, spacing = Shape(cfg, bar)
                cfg.cols, cfg.spacing = cfg.cols or cols, cfg.spacing or spacing
            end
            cfg[field] = v
            if field == "num" then cfg.numFixed = true end   -- a count you picked: never auto-grow past it
            ApplyLayout(bar)
        end
    end
    win.num     = Slider(win, "Buttons",          y, 1, 12, layoutSetter("num"));     y = y - 30
    win.cols    = Slider(win, "Buttons per row",  y, 1, 12, layoutSetter("cols"));    y = y - 30
    win.size    = Slider(win, "Button size",      y, 20, 64, layoutSetter("size"));   y = y - 30
    win.spacing = Slider(win, "Spacing",          y, 0, 12, layoutSetter("spacing")); y = y - 40

    -- show rule: click to cycle; "Custom" opens a box for macro conditions
    local ruleLabel = Label(win, "Show")
    ruleLabel:SetPoint("TOPLEFT", PAD, y - 4)
    win.rule = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    win.rule:SetSize(W - PAD * 2 - 112, 22)
    win.rule:SetPoint("TOPLEFT", PAD + 112, y)
    win.rule:SetScript("OnClick", function()
        local cfg = VB:BarConfig(current.def.key)
        local at = 1
        for i, r in ipairs(VB.SHOW_RULES) do if r.value == (cfg.show or "always") then at = i end end
        cfg.show = VB.SHOW_RULES[at % #VB.SHOW_RULES + 1].value
        ApplyShown(current)
        Refresh()
    end)
    y = y - 30
    win.custom = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
    win.custom:SetSize(W - PAD * 2 - 8, 22)
    win.custom:SetPoint("TOPLEFT", PAD + 6, y)
    win.custom:SetAutoFocus(false)
    win.custom:SetScript("OnEnterPressed", function(self)
        local text = strtrim(self:GetText() or "")
        local cfg = VB:BarConfig(current.def.key)
        if text ~= "" and not (text:find("show") or text:find("hide")) then
            VB:Print("custom show rule needs \"show\" and/or \"hide\", e.g. [combat] show; hide")
        else
            cfg.showCustom = text
            ApplyShown(current)
        end
        self:ClearFocus()
    end)
    win.custom:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Refresh() end)
    win.customHint = Label(win, "Macro conditions, e.g.  [mod:shift] show; hide   (Enter to apply)", "GameFontDisableSmall")
    win.customHint:SetPoint("TOPLEFT", win.custom, "BOTTOMLEFT", -4, -2)

    win.note = Label(win, "Drag bars to move them in move mode (Options -> Unlock). Changes apply out of combat.", "GameFontDisableSmall")
    win.note:SetPoint("BOTTOMLEFT", PAD, 12)
    win.note:SetWidth(W - PAD * 2)
end

Refresh = function()
    if not (win and current) then return end
    local def, cfg = current.def, VB:BarConfig(current.def.key)
    win.title:SetText(def.label)
    win.enabled:SetChecked(cfg.enabled and true or false)
    win.fade:SetChecked(cfg.fade and true or false)

    local smart = def.kind == "smart"
    local fixedCount = def.kind == "pet" or def.kind == "stance" or def.kind == "markers"
    win.num:VBShow(not smart and not fixedCount)
    win.num:VBSet(math.min(cfg.num or #current.buttons, #current.buttons), #current.buttons)
    if smart then
        win.cols:VBSet(cfg.cols or 12, 12)
        win.size:VBSet(cfg.size or 36)
        win.spacing:VBSet(cfg.spacing or 3)
    else
        local cols, spacing, size = Shape(cfg, current)
        win.cols:VBSet(cols, #current.buttons)
        win.size:VBSet(size)
        win.spacing:VBSet(spacing)
    end

    local rule = cfg.show or "always"
    for _, r in ipairs(VB.SHOW_RULES) do
        if r.value == rule then win.rule:SetText(r.label) end
    end
    local custom = rule == "custom"
    win.custom:SetShown(custom)
    win.customHint:SetShown(custom)
    win.custom:SetText(cfg.showCustom or "")
end

function VB:OpenBarSettings(bar)
    if InCombatLockdown() then self:Print("bar settings open out of combat.") return end
    if not win then Build() end
    current = bar or current or self.bars.bar1
    Refresh()
    win:Show()
end

function VB:CloseBarSettings()
    if win then win:Hide() end
end
