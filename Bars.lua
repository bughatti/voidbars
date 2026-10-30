----------------------------------------------------------------------
-- VoidBars — the bars: secure headers, main-bar paging, layout (imported
-- from the player's Blizzard/Edit Mode layout on first run), hiding
-- Blizzard's bars, move mode, out-of-combat fading, vehicle exit.
----------------------------------------------------------------------
local _, VB = ...

VB.bars = {}
VB.hider = CreateFrame("Frame")
VB.hider:Hide()

-- Main bar page, same priority Blizzard uses: override/vehicle/possess bars,
-- temp shapeshift, dragonriding (bonusbar:5), Shift+wheel pages, then
-- stance/form pages (cat, bear, stealth, ...), else page 1.
-- Rogues: [bonusbar:1] is set by Stealth AND by Shadow Dance, so paging on it flipped
-- keys 2-7 (Kick included) to the stealth page in every Dance mid-fight. [stealth] is
-- true for Stealth / Vanish but NOT Shadow Dance, so rogues page on that instead: the
-- stealth page (openers) in real stealth, the normal keys in Dance.
local function PageDriver()
    local _, class = UnitClass("player")
    local parts = {
        -- same priority as Blizzard's ActionBarController: vehicle before override
        "[vehicleui][possessbar] vehicle",
        "[overridebar] override",
        "[shapeshift] tempshapeshift",
        "[bonusbar:5] 11",
        "[bar:2] 2", "[bar:3] 3", "[bar:4] 4", "[bar:5] 5", "[bar:6] 6",
    }
    parts[#parts + 1] = (class == "ROGUE") and "[stealth] 7" or "[bonusbar:1] 7"
    for _, p in ipairs({ "[bonusbar:2] 8", "[bonusbar:3] 9", "[bonusbar:4] 10", "1" }) do
        parts[#parts + 1] = p
    end
    return table.concat(parts, "; ")
end

-- Runs in the secure environment (works in combat): turn the state into a
-- page number and point the 12 buttons at that page's slots.
local PAGE_SNIPPET = [[
    local page = newstate
    if page == "override" then
        page = GetOverrideBarIndex()
    elseif page == "vehicle" then
        page = GetVehicleBarIndex()
    elseif page == "tempshapeshift" then
        page = GetTempShapeshiftBarIndex()
    else
        page = tonumber(page)
    end
    if not page or page < 1 then page = 1 end
    for i = 1, 12 do
        local slot = (page - 1) * 12 + i
        local b = buttons[i]
        b:SetAttribute("action", slot)
        -- keep empowered-spell release right even when the page changes in combat
        local t, id = GetActionInfo(slot)
        b:SetAttribute("pressAndHoldAction", (t == "spell" and id and IsPressHoldReleaseSpell(id)) and true or false)
    end
]]

local DEFAULT_SIZE, DEFAULT_SPACING = 40, 3

function VB:CreateBars()
    for _, def in ipairs(self.BAR_DEFS) do
        local bar = CreateFrame("Frame", "VoidBars_" .. def.key, UIParent, "SecureHandlerStateTemplate")
        bar.def = def
        bar.buttons = {}
        bar:SetSize(1, 1)
        bar:SetMovable(true)
        bar:SetClampedToScreen(true)
        bar:Hide()   -- shown by ApplyVisibility once the layout is ready
        for i = 1, def.count or 12 do
            local name = "VoidBars" .. def.key .. "Button" .. i
            local b
            if def.kind == "pet" then
                b = self:CreatePetButton(bar, i, name)
            elseif def.kind == "stance" then
                b = self:CreateStanceButton(bar, i, name)
            elseif def.kind == "markers" then
                b = self:CreateMarkerButton(bar, i)
            else
                b = self:CreateButton(bar, i, name)
                if not def.paging then
                    b:SetAttribute("action", (def.page - 1) * 12 + i)
                end
            end
            b.bindCmd = def.bind and (def.bind .. i) or nil
            bar.buttons[i] = b
            bar:SetFrameRef("b" .. i, b)
        end
        if def.paging then
            bar:Execute([[
                buttons = newtable()
                for i = 1, 12 do buttons[i] = self:GetFrameRef("b" .. i) end
            ]])
            bar:SetAttribute("_onstate-page", PAGE_SNIPPET)
            RegisterStateDriver(bar, "page", PageDriver())
        end
        self.bars[#self.bars + 1] = bar
        self.bars[def.key] = bar
    end
    self:CreateVehicleExit()
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
local function GridOffsets(num, cols, size, spacing)
    cols = math.max(1, cols or 12)
    local o = {}
    for i = 1, num do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        o[i] = { col * (size + spacing), row * (size + spacing) }
    end
    return o
end

VB.GridOffsets = GridOffsets
VB.DEFAULT_SIZE, VB.DEFAULT_SPACING = DEFAULT_SIZE, DEFAULT_SPACING

-- Fallback when nothing could be imported: stacked rows above the bottom center.
local function DefaultPosition(index, width)
    local x = (UIParent:GetWidth() - width) / 2
    local y = 60 + index * (DEFAULT_SIZE + DEFAULT_SPACING + 2)
    return x, y
end

function VB:LayoutBar(bar)
    local cfg = self:BarConfig(bar.def.key)
    local size = cfg.size or DEFAULT_SIZE
    local num = cfg.num or #bar.buttons
    local offsets = cfg.offsets or GridOffsets(num, 12, size, DEFAULT_SPACING)
    local w, h = 1, 1
    for i, b in ipairs(bar.buttons) do
        b:ApplySize(size)
        b:ClearAllPoints()
        local o = offsets[i]
        if i <= num and o then
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", o[1], -o[2])
            b:Show()
            w = math.max(w, o[1] + size)
            h = math.max(h, o[2] + size)
        else
            b:Hide()
        end
    end
    bar:SetSize(w, h)
    if not cfg.x then
        for idx, other in ipairs(self.bars) do
            if other == bar then cfg.x, cfg.y = DefaultPosition(idx, w) end
        end
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
    self:Outline(bar)
end

-- A very faint outline around each bar section (option "Outline bars", on by default),
-- so you can see where a bar is and drop spells / items on it even when its slots are
-- empty (2026-10-25). Plain textures anchored to the bar's edges: they follow moves and
-- resizes, fade with the bar, and are safe in combat.
local OUTLINE_PAD, OUTLINE_ALPHA = 2, 0.14
function VB:Outline(bar)
    local o = bar.vbOutline
    if not o then
        o = {}
        local function edge(a1, x1, y1, a2, x2, y2, w, h)
            local t = bar:CreateTexture(nil, "BACKGROUND")
            t:SetColorTexture(1, 1, 1, OUTLINE_ALPHA)
            t:SetPoint(a1, bar, a1, x1, y1)
            t:SetPoint(a2, bar, a2, x2, y2)
            if w then t:SetWidth(w) else t:SetHeight(h) end
            o[#o + 1] = t
        end
        local p = OUTLINE_PAD
        edge("TOPLEFT", -p, p, "TOPRIGHT", p, p, nil, 1)            -- top
        edge("BOTTOMLEFT", -p, -p, "BOTTOMRIGHT", p, -p, nil, 1)    -- bottom
        edge("TOPLEFT", -p, p, "BOTTOMLEFT", -p, -p, 1, nil)        -- left
        edge("TOPRIGHT", p, p, "BOTTOMRIGHT", p, -p, 1, nil)        -- right
        bar.vbOutline = o
    end
    local on = self:Get("barOutline") ~= false
    for _, t in ipairs(o) do t:SetShown(on) end
end

-- One empty square per action bar to drop spells / items on (2026-10-25): the bar's
-- first empty slot is always drawn, with a "+". A full bar grows by one square (out of
-- combat, up to its 12 buttons) so there's always a next one -- except bar1 / bar2, the
-- keybound 2x7 combat block (keys 1-7 / Shift+1-7), which never grows.
local NO_GROW = { bar1 = true, bar2 = true }

-- Never grows: a bar carrying the combat keys (1-7 or Shift+1-7) on any character,
-- not just the preset's bar1 / bar2 (a druid's Shift column grew, 2026-10-25).
local function HoldsCombatKeys(bar)
    for _, b in ipairs(bar.buttons) do
        if b.bindCmd then
            for _, key in ipairs({ GetBindingKey(b.bindCmd) }) do
                if key:match("^[1-7]$") or key:match("^SHIFT%-[1-7]$") then return true end
            end
        end
    end
    return false
end

function VB:UpdateDropSlots()
    for _, bar in ipairs(self.bars) do
        local def = bar.def
        if not def.kind and bar:IsShown() then   -- plain action bars only
            local cfg = self:BarConfig(def.key)
            local num = math.min(cfg.num or #bar.buttons, #bar.buttons)
            local drop
            -- bar1 slot 1 = key 1 = VoidSequencer: it stays empty, so it's never the drop square
            local first = (def.key == "bar1" and VB.SeqActive and VB.SeqActive()) and 2 or 1
            -- The "+" goes on the first slot of the EMPTY RUN AT THE END only: a gap in
            -- the middle of a bar is the player's spacing and stays blank (2026-10-25).
            for i = num, first, -1 do
                if bar.buttons[i].hasAction then break end
                drop = bar.buttons[i]
            end
            if not drop and not NO_GROW[def.key] and not cfg.numFixed and num < #bar.buttons and not HoldsCombatKeys(bar) then
                self:RunOutOfCombat("grow_" .. def.key, function() self:GrowBar(bar) end)
            end
            for _, b in ipairs(bar.buttons) do
                local want = (b == drop)
                if b.vbDrop ~= want then
                    b.vbDrop = want
                    if b.UpdateEmpty then b:UpdateEmpty() end
                end
            end
        end
    end
end

local dropQueued
function VB:QueueDropSlots()
    if dropQueued then return end
    dropQueued = true
    C_Timer.After(0.3, function() dropQueued = false; VB:UpdateDropSlots() end)
end

-- Add one square to a full bar, continuing its row / column (imported layouts keep their
-- own spacing). Out of combat only (it moves secure buttons).
function VB:GrowBar(bar)
    local cfg = self:BarConfig(bar.def.key)
    local num = math.min(cfg.num or #bar.buttons, #bar.buttons)
    if num >= #bar.buttons then return end
    if not bar.buttons[num].hasAction then return end   -- the end freed up meanwhile (gaps don't count)
    -- grid bars get explicit offsets, so a new square can go on either end
    if not cfg.offsets then cfg.offsets = GridOffsets(num, 12, cfg.size or DEFAULT_SIZE, DEFAULT_SPACING) end
    if not cfg.offsets[num + 1] then
        -- continue the last button's ROW (or, for a vertical bar, its column); the step
        -- comes from a neighbour in that same row / column, not from the previous index
        -- (two indexes can straddle a row break)
        local last = cfg.offsets[num]
        local step = (cfg.size or DEFAULT_SIZE) + DEFAULT_SPACING
        if last then
            local dx, dy
            for j = num - 1, 1, -1 do   -- a neighbour in the same row first
                local o = cfg.offsets[j]
                if o and o[2] == last[2] and o[1] ~= last[1] then
                    dx, dy = (last[1] - o[1]) / (num - j), 0
                    break
                end
            end
            if not dx then   -- a lone button in its row: a vertical bar's column?
                local o = cfg.offsets[num - 1]
                if o and o[1] == last[1] and o[2] ~= last[2] then dx, dy = 0, last[2] - o[2] end
            end
            dx, dy = dx or step, dy or 0
            local nx, ny = last[1] + dx, last[2] + dy
            -- Grow from the middle OUT (the player, 2026-10-25): a bar on the left half
            -- adds its square on the row's left end, a right-half bar on its right end.
            if dy == 0 and dx ~= 0 then
                local out = ((cfg.x or 0) + bar:GetWidth() / 2 < UIParent:GetWidth() / 2) and -1 or 1
                local edge
                for j = 1, num do
                    local o = cfg.offsets[j]
                    if o and o[2] == last[2] then
                        edge = edge and ((out < 0) and math.min(edge, o[1]) or math.max(edge, o[1])) or o[1]
                    end
                end
                nx, ny = (edge or last[1]) + out * math.abs(dx), last[2]
            end
            cfg.offsets[num + 1] = { nx, ny }
            -- a square left of x = 0: shift every offset right and the bar left by the same
            -- amount, so nothing already on screen moves
            local minX = 0
            for _, o in ipairs(cfg.offsets) do minX = math.min(minX, o[1]) end
            if minX < 0 then
                for _, o in ipairs(cfg.offsets) do o[1] = o[1] - minX end
                cfg.x = (cfg.x or 0) + minX
            end
        end
    end
    cfg.num = num + 1
    self:LayoutBar(bar)
    self:ApplyBindings()
    self:QueueFullUpdate()
    self:QueueDropSlots()
end

function VB:ApplyAllLayouts()
    for _, bar in ipairs(self.bars) do
        if bar.def.kind == "smart" then
            if self.LayoutSmartBar then self:LayoutSmartBar(bar) end
        else
            self:LayoutBar(bar)
        end
    end
    self:PlaceEncounterBar()
end

function VB:ApplyVisibility()
    for _, bar in ipairs(self.bars) do
        if bar.def.kind == "smart" then
            -- smart bars set their own visibility (shown only when they hold items)
            if self.LayoutSmartBar then self:LayoutSmartBar(bar) end
        elseif bar.def.kind == "stance" then
            if self.UpdateStanceVisibility then self:UpdateStanceVisibility() end
        else
            local cfg = self:BarConfig(bar.def.key)
            -- vehicles / quest override bars: ours hide, Blizzard's vehicle bar stays at the
            -- bottom (see VEHICLES below); keys still reach the hidden bar1 buttons
            local show = "[petbattle][vehicleui][overridebar] hide; " .. self:ShowRule(cfg)
            local skinned = C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar()
                and (C_ActionBar.GetOverrideBarSkin and C_ActionBar.GetOverrideBarSkin() or 0) ~= 0
            if bar.def.paging and not skinned then
                -- The main bar stays up on a PLAIN override bar: Blizzard puts those
                -- abilities on its main bar, which is parked, so hiding ours left them
                -- nowhere on screen (Alleria fight, "Abyssus, Abyssum", 2026-10-26).
                -- Only a SKINNED override bar has Blizzard's own frame; then bar1 goes
                -- invisible instead (fader, OverrideActionBar shown).
                show = "[petbattle][vehicleui] hide; " .. self:ShowRule(cfg)
            end
            if bar.def.kind == "pet" then
                -- like Blizzard's pet bar: only with a pet that has a bar, not in vehicles
                show = "[petbattle][vehicleui][overridebar][possessbar][nopet] hide; " .. self:ShowRule(cfg)
            end
            RegisterStateDriver(bar, "visibility", cfg.enabled and show or "hide")
        end
    end
end

-- Copy one Blizzard bar's layout into VoidBars (button rects, count, on/off).
-- Returns true when positions were found.
function VB:ImportBarLayout(def)
    if def.kind == "markers" then   -- not a Blizzard bar: its own first-time setup
        self:InitMarkersConfig(def)
        return true
    end
    local uis = UIParent:GetEffectiveScale()
    local cfg = self:BarConfig(def.key)
    local bf = _G[def.blizz]
    local num = math.min((bf and bf.numButtonsShowable) or def.count or 12, def.count or 12)
    local pts, size, minL, maxT = {}, nil, nil, nil
    for i = 1, num do
        local b = _G[def.prefix .. i]
        local l, t = b and b:GetLeft(), b and b:GetTop()
        if l and t then
            local s = b:GetEffectiveScale() / uis
            l, t = l * s, t * s
            pts[i] = { l, t }
            size = size or b:GetWidth() * s
            minL = minL and math.min(minL, l) or l
            maxT = maxT and math.max(maxT, t) or t
        end
    end
    -- pet/stance bars are "on" by default: their own drivers hide them when
    -- there is no pet / no forms (Blizzard hides those bars the same way)
    cfg.enabled = def.key == "bar1" or def.kind == "pet" or def.kind == "stance" or (bf and bf:IsShown()) or false
    if not (size and minL) then return false end
    cfg.x, cfg.y, cfg.num = minL, maxT, num
    cfg.size = math.floor(size + 0.5)
    cfg.offsets = {}
    cfg.cols, cfg.spacing = nil, nil   -- new shape: Bar settings reads them off the offsets again
    for i = 1, num do
        local p = pts[i]
        if p then cfg.offsets[i] = { p[1] - minL, maxT - p[2] } end
    end
    if def.kind == "stance" then
        -- Blizzard shows only today's form count; reserve every slot so a form
        -- learned later has a place (empty slots draw nothing). Extend the row.
        local step = (cfg.offsets[2] and (cfg.offsets[2][1] - cfg.offsets[1][1])) or (cfg.size + 3)
        for i = 1, def.count do
            if not cfg.offsets[i] then
                local prev = cfg.offsets[i - 1] or { -step, 0 }
                cfg.offsets[i] = { prev[1] + step, prev[2] }
            end
        end
        cfg.num = def.count
    end
    return true
end

-- Copy the player's current Blizzard layout: every button's exact on-screen
-- spot and size, which bars are on, how many buttons each shows. Reads the
-- real button rects, so whatever Edit Mode arrangement (rows, columns,
-- padding, scale) they built comes across as-is.
function VB:ImportBlizzardLayout(fromOptions)
    if fromOptions and self.blizzardHidden then
        -- Blizzard's bars are parked; bring them back for a moment to read them.
        self:ShowBlizzard()
        C_Timer.After(0.5, function()
            self:RunOutOfCombat("import", function() self:ImportBlizzardLayout(false) end)
        end)
        return
    end
    local found = 0
    for _, def in ipairs(self.BAR_DEFS) do
        if self:ImportBarLayout(def) then found = found + 1 end
    end
    VoidBarsCharDB.imported = true
    self:ApplyAllLayouts()
    self:ApplyVisibility()
    if self:Get("hideBlizzard") then self:HideBlizzard() end
    self:ApplyBindings()
    self:QueueFullUpdate()
    if self.RebuildSmartBars then self:RebuildSmartBars() end
    self:QueueDropSlots()   -- first run too (they used to wait for the first slot change)
    self:Print(("copied your layout from Blizzard's bars (%d bars)."):format(found))
end

StaticPopupDialogs.VOIDBARS_FIRSTRUN = {
    text = "|cff00c7ffVoidBars|r is now running your action bars.\n\nIt copied where your Blizzard bars were. "
        .. "Want the clean layout instead? Keys 1-7 and Shift 1-7 in a block at the bottom, with "
        .. "Consumables, Travel and Professions bars around it, and the best spells for your spec on those keys.\n\n"
        .. "Your current bars are saved first, so you can always go back (Options -> VoidBars -> Restore).",
    button1 = "Use the clean layout", button2 = "Keep my bars",
    OnAccept = function()
        local VBa = _G.VoidBars
        if not VBa or InCombatLockdown() then return end
        VBa:ApplyPreset("naga7")
        C_Timer.After(0.5, function() if VBa.ShowSuggestion then VBa:ShowSuggestion() end end)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

----------------------------------------------------------------------
-- Takeover: first run imports, later runs use the saved layout.
----------------------------------------------------------------------
function VB:TakeOver()
    if self.RegisterMarkerSlash then self:RegisterMarkerSlash() end   -- both first-run and later paths
    if not VoidBarsCharDB.imported then
        self:ImportBlizzardLayout(false)
        -- First run on this character: a copy of Blizzard's bars can land anywhere (on
        -- one character it put bars over the player frame, 2026-10-27), so offer the clean layout
        -- right away instead of leaving a new player to find it in the options.
        -- Snapshot "Default" (the player's own bars) BEFORE offering anything that changes
        -- them, and let the smart bars seed from it (Astra review, 2026-10-28).
        C_Timer.After(3, function()
            self:EnsureDefaultProfile()
            if self.RebuildSmartBars then self:RunOutOfCombat("smartlayout", function() self:RebuildSmartBars() end) end
            if not InCombatLockdown() then StaticPopup_Show("VOIDBARS_FIRSTRUN") end
        end)
        return
    end
    -- Bars added in a later VoidBars version (pet, stance): copy their Blizzard
    -- spot once, before Blizzard's are parked.
    for _, def in ipairs(self.BAR_DEFS) do
        if self:BarConfig(def.key).enabled == nil then self:ImportBarLayout(def) end
    end
    if self.MigrateUtilityRows then self:MigrateUtilityRows() end
    if self.CheckSpecLayout then self:CheckSpecLayout() end   -- per-spec layout, spec changed while away
    self:ApplyAllLayouts()
    self:ApplyVisibility()
    if self:Get("hideBlizzard") then self:HideBlizzard() end
    self:ApplyBindings()
    self:QueueFullUpdate()
    if self.RebuildSmartBars then self:RebuildSmartBars() end
    if self.UpdatePetStanceButtons then self:UpdatePetStanceButtons() end
    if self.UpdateMarkerUsable then self:UpdateMarkerUsable() end
    self:PublishLayout()      -- other characters can copy this layout
    -- Action slots are ready a moment after login; snapshot "Default" once.
    C_Timer.After(3, function() self:EnsureDefaultProfile() end)
    VoidBarsDB.dbg = nil      -- leftover from the 2026-10-24 key-routing log
    self:QueueDropSlots()     -- each bar's "+" square to drop things on
end

-- Park Blizzard's eight bars under a hidden frame. (Keys are routed to our
-- buttons by override bindings, so their buttons never fire.)
function VB:HideBlizzard()
    for _, def in ipairs(self.BAR_DEFS) do
        local f = _G[def.blizz]
        if f then
            f.vbOrigParent = f.vbOrigParent or f:GetParent()
            f:SetParent(self.hider)
        end
    end
    self.blizzardHidden = true
    self:SyncSeqVehicleKey()
    self:PlaceEncounterBar()
end

-- Self-heal, out of combat: a grab with no vehicle bar (a Frostfire Gronn holding a
-- hunter, 2026-10-29) left Blizzard's bars up and ours gone until a relog. After every
-- fight and every vehicle / override change, park any Blizzard bar that came back and
-- re-apply our visibility. Nothing to do -> nothing changes.
function VB:Recheck()
    if not self.blizzardHidden or InCombatLockdown() then return end
    local moved = false
    for _, def in ipairs(self.BAR_DEFS) do
        local f = _G[def.blizz]
        if f and f:GetParent() ~= self.hider then
            f.vbOrigParent = f.vbOrigParent or f:GetParent()
            f:SetParent(self.hider)
            moved = true
        end
    end
    if moved then self:SyncSeqVehicleKey() end
    self:ApplyVisibility()
end

function VB:ShowBlizzard()
    for _, def in ipairs(self.BAR_DEFS) do
        local f = _G[def.blizz]
        if f and f.vbOrigParent then f:SetParent(f.vbOrigParent) end
    end
    self.blizzardHidden = false
    self:SyncSeqVehicleKey()
end

-- VoidSequencer sends key 1 to the vehicle/skyriding slot 1 while mounted. With
-- Blizzard's bars parked that has to be our bar-1 button 1, not ACTIONBUTTON1.
function VB:SyncSeqVehicleKey()
    local api = _G.VoidSequencerAPI
    if api and api.SyncVehicleKey then api.SyncVehicleKey() end
end

----------------------------------------------------------------------
-- Encounter bar: Blizzard's Edit Mode frame that holds quest / boss power bars
-- (PlayerPowerBarAlt, e.g. "Coal of Jan'alai empowered"). Edit Mode layouts often
-- pin it to one of Blizzard's action bars, and those are parked, so it lands where
-- the hidden bar sits (seen 2026-10-25: anchored to MultiBarRight's top-right,
-- off-center over our bars). With Blizzard's bars hidden we place it: centered,
-- just above our bars at the bottom center. Edit Mode / the bottom frame manager
-- re-anchor it now and then; the SetPoint hook puts ours back. Left alone while
-- Edit Mode is open, so it can still be looked at there.
----------------------------------------------------------------------
local ENCOUNTER_GAP = 6

-- Top of the highest enabled bar that sits under the screen's center line, in the
-- lower part of the screen (bars use TOPLEFT at cfg.x / cfg.y in UIParent units).
function VB:BottomStackTop(halfWidth)
    local cx = UIParent:GetWidth() / 2
    local limit = UIParent:GetHeight() * 0.45
    local top = 0
    for _, bar in ipairs(self.bars) do
        local cfg = self:BarConfig(bar.def.key)
        if cfg.enabled and cfg.x and cfg.y and cfg.y < limit then
            local w = bar:GetWidth() or 0
            if cfg.x < cx + halfWidth and cfg.x + w > cx - halfWidth then
                top = math.max(top, cfg.y)
            end
        end
    end
    -- VoidSequencer's ST/AoE switch often sits just above the combat block; the
    -- Extra Action button covered it (seen 2026-10-26). Count it as part of the stack.
    local t = _G.VoidSeqToggle
    if t and t:IsShown() and t:GetTop() and t:GetLeft() then
        local s = t:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local tTop, tL, tR = t:GetTop() * s, t:GetLeft() * s, t:GetRight() * s
        if tTop < limit and tL < cx + halfWidth and tR > cx - halfWidth then
            top = math.max(top, tTop)
        end
    end
    return top
end

-- Native Base methods: Edit Mode replaces SetPoint / ClearAllPoints with Lua
-- wrappers that write its snap bookkeeping (EditModeSystemTemplates.lua:13-17,
-- 147-156); calling those from addon code would taint Edit Mode.
local function PlaceAt(f, y, x, point)
    local clear, set = f.ClearAllPointsBase or f.ClearAllPoints, f.SetPointBase or f.SetPoint
    clear(f)
    set(f, point or "BOTTOM", UIParent, "BOTTOMLEFT", x or UIParent:GetWidth() / 2, y)
end

-- Where the Extra Action / zone ability box goes: RIGHT of the combat block, above
-- the bars on that side (the player, 2026-10-26: centered it was in the way of
-- moving around). Returns the BOTTOMLEFT x, y in UIParent units, or nil without a block.
function VB:ExtraAbilitySpot()
    local x1
    for _, key in ipairs({ "bar1", "bar2" }) do
        local b, c = self.bars[key], self:BarConfig(key)
        if b and c.enabled and c.x and (b:GetWidth() or 0) > 1 then
            x1 = math.max(x1 or 0, c.x + b:GetWidth())
        end
    end
    if not x1 then return nil end
    local gap = self.GROUP_GAP or 14
    local limit = UIParent:GetHeight() * 0.45
    local top = 0
    -- the bars sitting right of the block (Travel and so on): go above them
    for _, bar in ipairs(self.bars) do
        local cfg = self:BarConfig(bar.def.key)
        if cfg.enabled and cfg.x and cfg.y and cfg.y < limit and cfg.x >= x1 - 1 and bar:IsShown() then
            top = math.max(top, cfg.y)
        end
    end
    return x1 + gap, top + gap
end

-- The Extra Action Button / zone ability box (ExtraAbilityContainer) is the same
-- kind of Edit Mode frame and had the same problem: with Blizzard's bars parked it
-- floated mid-screen (seen 2026-10-25 in Den of Nalorakk). Stack, bottom up: our
-- bars, the extra / zone ability box, then the encounter bar. The extra box holds a
-- secure button, so it can only move out of combat; its anchor sticks when it shows
-- mid-fight.
function VB:PlaceEncounterBar()
    if not self.blizzardHidden or self.placingBottom then return end
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then return end
    local xa, eb = _G.ExtraAbilityContainer, _G.EncounterBar
    local combat = InCombatLockdown()
    self.placingBottom = true
    local y = self:BottomStackTop(150) + ENCOUNTER_GAP
    if xa then
        -- protected (secure child): placed out of combat only; its anchor sticks when
        -- it shows mid-fight. Right of the combat block (ExtraAbilitySpot); centered
        -- above the bars only when there's no block to go beside.
        local ex, ey = self:ExtraAbilitySpot()
        if combat and xa:IsProtected() then
            self:RunOutOfCombat("bottomcenter", function() self:PlaceEncounterBar() end)
        elseif ex then
            PlaceAt(xa, ey, ex, "BOTTOMLEFT")
        else
            PlaceAt(xa, y)
            if xa:IsShown() then
                local h = xa:GetHeight() or 0
                y = y + (h > 1 and h or 52) + ENCOUNTER_GAP
            end
        end
    end
    -- the encounter bar isn't protected: it can move up in combat when an extra
    -- ability appears under it
    if eb then
        if combat and eb:IsProtected() then
            self:RunOutOfCombat("bottomcenter", function() self:PlaceEncounterBar() end)
        else
            PlaceAt(eb, y)
        end
    end
    self.placingBottom = false
    if not self.bottomHooked then
        self.bottomHooked = true
        local function again() VB:PlaceEncounterBar() end
        if eb then hooksecurefunc(eb, "SetPoint", again) end
        if xa then hooksecurefunc(xa, "SetPoint", again) end
        -- the encounter bar moves up / down when the extra box shows / hides
        if xa then
            xa:HookScript("OnShow", again)
            xa:HookScript("OnHide", again)
        end
        -- the stack starts above VoidSequencer's switch while it shows (BottomStackTop)
        local vt = _G.VoidSeqToggle
        if vt then
            vt:HookScript("OnShow", again)
            vt:HookScript("OnHide", again)
        end
        -- leaving Edit Mode re-applies their anchors (maybe while still "active")
        if EditModeManagerFrame then
            EditModeManagerFrame:HookScript("OnHide", function() C_Timer.After(0, again) end)
        end
    end
end

----------------------------------------------------------------------
-- Move mode: a labelled handle over each bar; drag to place.
----------------------------------------------------------------------
local function MakeHandle(bar)
    local h = CreateFrame("Frame", nil, bar)
    h:SetAllPoints()
    h:SetFrameLevel(bar:GetFrameLevel() + 30)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    local bg = h:CreateTexture(nil, "OVERLAY")
    bg:SetAllPoints()
    bg:SetColorTexture(VB.COLOR.accent.r, VB.COLOR.accent.g, VB.COLOR.accent.b, 0.25)
    local label = h:CreateFontString(nil, "OVERLAY")
    label:SetFont(VB.FONT, 12, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(bar.def.label .. "\n|cffaaaaaaright-click: settings|r")
    -- right-click: this bar's settings window (BarSettings.lua)
    h:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and VB.OpenBarSettings then VB:OpenBarSettings(bar) end
    end)
    h:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        bar.vbMoving = true
        bar:StartMoving()
    end)
    -- Protected calls: if combat started mid-drag, finish when it ends.
    local function finish()
        if not bar.vbMoving then return end
        bar.vbMoving = nil
        bar:StopMovingOrSizing()
        bar:SetUserPlaced(false)
        local cfg = VB:BarConfig(bar.def.key)
        cfg.x, cfg.y = bar:GetLeft(), bar:GetTop()
        if bar.def.kind == "smart" then   -- dropped side of center = the side it lines up on
            local cx = cfg.x + bar:GetWidth() / 2
            cfg.side = cx < UIParent:GetWidth() / 2 and "left" or "right"
        end
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
        VB:PlaceEncounterBar()   -- the bottom stack may have moved
        if bar.def.kind == "smart" then VB:LayoutSmartBar(bar) end   -- snap to its line now
    end
    h:SetScript("OnDragStop", function()
        VB:RunOutOfCombat("drag-" .. bar.def.key, finish)
    end)
    bar.vbFinishDrag = finish   -- the combat guard calls it: a hidden handle may never get OnDragStop
    h:Hide()
    return h
end

function VB:SetUnlocked(on)
    if InCombatLockdown() then
        self:Print("can't move bars in combat.")
        return
    end
    self.unlocked = on and true or false
    for _, bar in ipairs(self.bars) do
        bar.vbHandle = bar.vbHandle or MakeHandle(bar)
        local enabled = self:BarConfig(bar.def.key).enabled
        bar.vbHandle:SetShown(self.unlocked and enabled)
        bar:SetAlpha(1)
    end
    if not self.lockButton then
        local b = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        b:SetSize(160, 28)
        b:SetPoint("TOP", 0, -120)
        b:SetText("Lock VoidBars")
        b:SetFrameStrata("DIALOG")
        b:SetScript("OnClick", function() VB:SetUnlocked(false) end)
        self.lockButton = b
    end
    self.lockButton:SetShown(self.unlocked)
    self:ApplyVisibility()   -- show rules pause in move mode (VB:ShowRule)
    self:QueueFullUpdate()
    -- smart bars show in move mode even when empty, so they can be placed
    for _, bar in ipairs(self.smartBars or {}) do self:LayoutSmartBar(bar) end
end

-- Combat while in move mode: drop the handles so the buttons underneath are
-- usable. (Handles and the lock button are plain frames, fine to hide in combat.)
local moveGuard = CreateFrame("Frame")
moveGuard:RegisterEvent("PLAYER_REGEN_DISABLED")
moveGuard:SetScript("OnEvent", function()
    if not VB.unlocked then return end
    VB.unlocked = false
    for _, bar in ipairs(VB.bars) do
        if bar.vbMoving and bar.vbFinishDrag then
            VB:RunOutOfCombat("drag-" .. bar.def.key, bar.vbFinishDrag)   -- runs when combat ends
        end
        if bar.vbHandle then bar.vbHandle:Hide() end
    end
    if VB.lockButton then VB.lockButton:Hide() end
    if VB.CloseBarSettings then VB:CloseBarSettings() end
    -- show rules come back when combat ends (state drivers can't be re-registered now)
    VB:RunOutOfCombat("visibility", function() VB:ApplyVisibility() end)
    VB:QueueFullUpdate()
    VB:Print("bars locked for combat.")
end)

----------------------------------------------------------------------
-- Fading: bars set to fade show at full alpha in combat, on mouseover,
-- while dragging a spell or in move mode; otherwise drop to fadeAlpha.
-- (SetAlpha is allowed on protected frames in combat.)
----------------------------------------------------------------------
-- Override bars come and go: re-pick bar1's visibility rule (skinned or plain).
local overrideWatch = CreateFrame("Frame")
for _, e in ipairs({ "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_BONUS_ACTIONBAR" }) do
    pcall(overrideWatch.RegisterEvent, overrideWatch, e)
end
overrideWatch:SetScript("OnEvent", function()
    if VB.bars and VB.bars.bar1 then
        VB:RunOutOfCombat("visibility", function() VB:ApplyVisibility(); VB:Recheck() end)
    end
end)

local fader = CreateFrame("Frame")
local acc = 0
fader:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.05 then return end
    acc = 0
    if not VoidBarsCharDB then return end
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local low = VB:Get("fadeAlpha")
    -- Blizzard's skinned vehicle / override frame is up: the main bar steps aside. Out
    -- of combat ApplyVisibility (override events below) hides it properly; this alpha
    -- is the in-combat fallback (its keys still work, its buttons stay clickable).
    local oab = _G.OverrideActionBar
    local blizzOverride = oab and oab:IsVisible()
    for _, bar in ipairs(VB.bars) do
        local cfg = VoidBarsCharDB.bars and VoidBarsCharDB.bars[bar.def.key]
        if bar.def.paging and blizzOverride then
            if bar:GetAlpha() ~= 0 then bar:SetAlpha(0) end
        elseif cfg and cfg.fade and bar:IsShown() then
            local want = (inCombat or VB.unlocked or VB.dragging or bar:IsMouseOver()) and 1 or low
            local a = bar:GetAlpha()
            if math.abs(a - want) > 0.01 then
                bar:SetAlpha(a + (want - a) * 0.35)
            elseif a ~= want then
                bar:SetAlpha(want)
            end
        elseif bar:GetAlpha() ~= 1 then
            bar:SetAlpha(1)
        end
    end
end)

----------------------------------------------------------------------
-- Vehicle / taxi exit (Blizzard's lives on the main bar we park).
----------------------------------------------------------------------
function VB:CreateVehicleExit()
    local b = CreateFrame("Button", "VoidBarsVehicleExit", UIParent)
    b:SetSize(36, 36)
    -- above the right end of the main bar: beside it is where the Travel bar
    -- sits in the naga7 layout, and it would have covered the first Travel buttons
    b:SetPoint("BOTTOMRIGHT", self.bars.bar1, "TOPRIGHT", 0, 4)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
    t:SetTexCoord(0.14, 0.86, 0.14, 0.86)
    b:SetHighlightTexture(VB.TEX, "ADD")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
    b:SetScript("OnClick", function()
        if UnitOnTaxi("player") then
            TaxiRequestEarlyLanding()
        else
            VehicleExit()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetText(LEAVE_VEHICLE or "Leave vehicle")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    RegisterStateDriver(b, "visibility", "[canexitvehicle] show; hide")
    self.vehicleExit = b
end

----------------------------------------------------------------------
-- VEHICLES. Blizzard's vehicle / quest bar (OverrideActionBar) stays at its own
-- spot at the bottom of the screen, untouched; every VoidBars bar hides while
-- you're in a vehicle or on an override bar ("[vehicleui][overridebar] hide" in
-- each bar's visibility driver -- evaluated by Blizzard's driver, so in combat
-- too), and VoidSequencer's ST/AoE button does the same. Moving Blizzard's bar
-- above ours (2026-10-23) put it mid-screen, over where you aim (the player,
-- 2026-10-25). Keys keep working: bar1's hidden buttons still page to the
-- vehicle's abilities. (A wrap on OverrideActionBar was tried and can't work: it
-- isn't explicitly protected, and drivers re-apply show every 0.2s.)
