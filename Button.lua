----------------------------------------------------------------------
-- VoidBars — one action button: flat Void look + every visual update.
--
-- The secure template does the actual casting (type "action", slot in the
-- "action" attribute). This file only DRAWS: icon, cooldowns, count, hotkey,
-- range/resource tint, checked state, proc glow. All of it is safe with 12.x
-- secret values (see Core.lua header).
----------------------------------------------------------------------
local _, VB = ...

local C_ActionBar = C_ActionBar
local GetActionInfo = GetActionInfo
local IsSecret = VB.IsSecret

local Button = {}
VB.Button = Button
VB.allButtons = {}
local bySlot = {}   -- action slot -> { [button] = true }

----------------------------------------------------------------------
-- Construction + flat Void style
----------------------------------------------------------------------
local function MakeGlow(btn)
    local g = CreateFrame("Frame", nil, btn)
    g:SetAllPoints()
    g:SetFrameLevel(btn:GetFrameLevel() + 5)
    local c = VB.COLOR.glow
    local edges = {}
    for i = 1, 4 do
        local t = g:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(c:GetRGB())
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(2)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(2)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(2)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(2)
    local ag = g:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.45); a:SetSmoothing("IN_OUT")
    g.anim = ag
    g:Hide()
    return g
end

function Button:Style()
    local icon = self.icon
    if self.IconMask then icon:RemoveMaskTexture(self.IconMask) end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Blizzard's slot art / frame atlases off; a 1px black frame instead.
    if self.SlotArt then self.SlotArt:SetAlpha(0) end
    if self.SlotBackground then self.SlotBackground:SetAlpha(0) end
    if self.Border then self.Border:SetAlpha(0) end
    if self.NormalTexture then self.NormalTexture:SetAlpha(0) end
    if self.Flash then self.Flash:SetAlpha(0) end

    local bg = self:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetColorTexture(VB.COLOR.border:GetRGB())
    self.vbBG = bg
    local empty = self:CreateTexture(nil, "BACKGROUND", nil, -6)
    empty:SetPoint("TOPLEFT", 1, -1)
    empty:SetPoint("BOTTOMRIGHT", -1, 1)
    empty:SetColorTexture(VB.COLOR.empty:GetRGB())
    self.vbEmpty = empty
    -- "+" on the bar's drop square (UpdateDropSlots / smart bars' "drop" entry)
    local plus = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    plus:SetPoint("CENTER")
    plus:SetText("+")
    plus:SetTextColor(1, 1, 1, 0.45)
    plus:Hide()
    self.vbPlus = plus

    self:SetPushedTexture(VB.TEX)
    self:GetPushedTexture():SetVertexColor(1, 1, 1, 0.25)
    self:GetPushedTexture():SetAllPoints(icon)
    self:SetHighlightTexture(VB.TEX, "ADD")
    self:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
    self:GetHighlightTexture():SetAllPoints(icon)
    self:SetCheckedTexture(VB.TEX)
    local ck = self:GetCheckedTexture()
    ck:SetVertexColor(VB.COLOR.accent.r, VB.COLOR.accent.g, VB.COLOR.accent.b, 0.35)
    ck:SetAllPoints(icon)

    self.cooldown:ClearAllPoints()
    self.cooldown:SetPoint("TOPLEFT", 1, -1)
    self.cooldown:SetPoint("BOTTOMRIGHT", -1, 1)
    self.cooldown:SetSwipeColor(0, 0, 0, 0.75)
    self.cooldown:SetDrawEdge(false)
    self.cooldown:SetDrawBling(false)

    -- Recharge of a charge spell: thin spinning edge only, under the main swipe.
    local cc = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
    cc:SetAllPoints(self.cooldown)
    cc:SetDrawSwipe(false)
    cc:SetDrawEdge(true)
    cc:SetDrawBling(false)
    cc:SetHideCountdownNumbers(true)
    self.chargeCooldown = cc

    self.HotKey:ClearAllPoints()
    self.HotKey:SetPoint("TOPRIGHT", -2, -3)
    self.HotKey:SetJustifyH("RIGHT")
    self.Count:ClearAllPoints()
    self.Count:SetPoint("BOTTOMRIGHT", -2, 3)
    self.Name:ClearAllPoints()
    self.Name:SetPoint("BOTTOMLEFT", 2, 2)
    self.Name:SetPoint("BOTTOMRIGHT", -2, 2)

    self.vbGlow = MakeGlow(self)
end

-- Fonts scale with the button so text stays readable at any size.
function Button:ApplySize(size)
    self:SetSize(size, size)
    local hk = math.max(9, math.floor(size * 0.30))
    self.HotKey:SetFont(VB.FONT, hk, "OUTLINE")
    self.HotKey:SetTextColor(VB.COLOR.hotkey:GetRGB())
    self.Count:SetFont(VB.FONT, math.max(9, math.floor(size * 0.30)), "OUTLINE")
    self.Name:SetFont(VB.FONT, math.max(8, math.floor(size * 0.22)), "OUTLINE")
    local cdText = self.cooldown.GetCountdownFontString and self.cooldown:GetCountdownFontString()
    if cdText then cdText:SetFont(VB.FONT, math.max(10, math.floor(size * 0.40)), "OUTLINE") end
end

function VB:CreateButton(header, index, name)
    -- Order matters: later templates' scripts win. ActionButtonTemplate pulls in
    -- FlyoutButtonTemplate, whose OnClick (Flyout_OnClick) would replace the
    -- secure OnClick if it came last -- every press did nothing. Visual first,
    -- secure last, same as Blizzard's ActionBarButtonTemplate.
    local b = CreateFrame("CheckButton", name, header, "ActionButtonTemplate, SecureActionButtonTemplate")
    Mixin(b, Button)
    b.header, b.index = header, index
    -- Down AND up: the secure template then follows the player's
    -- ActionButtonUseKeyDown setting (an Up-only button does nothing when it's on).
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:RegisterForDrag("LeftButton", "RightButton")
    b:SetAttribute("type", "action")
    -- Empowered / press-and-hold spells release on key-up through this, as on
    -- Blizzard's buttons (pressAndHoldAction is kept current in UpdatePressAndHold).
    b:SetAttribute("typerelease", "actionrelease")
    b:SetAttribute("checkselfcast", true)
    b:SetAttribute("checkfocuscast", true)
    b:SetAttribute("checkmouseovercast", true)
    b:Style()

    -- Shift(+pickup modifier) MOUSE-down = start a drag, not a cast (Blizzard's
    -- buttons do the same). Matters with "cast on key down" on: the down press
    -- would otherwise fire the spell before the drag starts. Key presses arrive
    -- as "Keybind" (see Bindings.lua), so Shift+key binds still cast.
    -- Returning a string swaps the button name: key presses continue as
    -- "LeftButton", so macros using [btn:1] / [button:1] work as on Blizzard's bars.
    SecureHandlerWrapScript(b, "OnClick", header, [[
        if button == "Keybind" then return "LeftButton" end
        if down and IsModifiedClick("PICKUPACTION") then return false end
    ]])

    b:HookScript("OnAttributeChanged", function(self, attr, value)
        if attr == "action" then self:SetAction(value) end
    end)
    b:HookScript("OnEnter", Button.VBOnEnter)
    b:HookScript("OnLeave", Button.VBOnLeave)
    b:HookScript("OnDragStart", Button.VBOnDragStart)
    b:SetScript("OnReceiveDrag", Button.VBOnReceiveDrag)
    b:HookScript("PostClick", Button.VBPostClick)

    VB.allButtons[#VB.allButtons + 1] = b
    return b
end

----------------------------------------------------------------------
-- Slot tracking
----------------------------------------------------------------------
function Button:SetAction(slot)
    slot = tonumber(slot)
    if slot == self.action then self:UpdateAll() return end
    if self.action then
        local t = bySlot[self.action]
        if t then t[self] = nil end
        -- range checks are per SLOT: bar1 paged onto bar2's slots shares them, so switch
        -- it off only when no button shows this slot any more
        if not (t and next(t)) then pcall(C_ActionBar.EnableActionRangeCheck, self.action, false) end
    end
    self.action = slot
    if slot then
        bySlot[slot] = bySlot[slot] or {}
        bySlot[slot][self] = true
        pcall(C_ActionBar.EnableActionRangeCheck, slot, true)
    end
    self.outOfRange = nil
    self:UpdateAll()
end

function VB:ButtonsForSlot(slot)
    return bySlot[slot]
end

----------------------------------------------------------------------
-- Visual updates
----------------------------------------------------------------------
function Button:UpdateAll()
    local slot = self.action
    if not slot then return end
    local had = self.hasAction
    self.hasAction = C_ActionBar.HasAction(slot)
    -- filled / emptied (incl. page and form swaps): re-pick the bar's drop square
    if had ~= self.hasAction and VB.QueueDropSlots then VB:QueueDropSlots() end
    if self.hasAction then
        self.icon:SetTexture(C_ActionBar.GetActionTexture(slot))
        self.icon:Show()
    else
        self.icon:Hide()
    end
    self:UpdateEmpty()
    self:UpdateCount()
    self:UpdateCooldown()
    self:UpdateUsable()
    self:UpdateChecked()
    self:UpdateHotkey()
    self:UpdateName()
    self:UpdateGlow()
    self:UpdatePressAndHold()
    if self.UpdateFlyout then self:UpdateFlyout() end
end

-- Secure attribute, so out of combat only. A main-bar page swap in combat
-- (forms, vehicle) keeps the previous value until combat ends -- then the
-- PLAYER_REGEN_ENABLED full update refreshes it.
function Button:UpdatePressAndHold()
    if InCombatLockdown() then return end
    local hold = false
    if self.hasAction then
        local t, id = GetActionInfo(self.action)
        if t == "spell" and id and not IsSecret(id) and C_Spell.IsPressHoldReleaseSpell then
            local ok, v = pcall(C_Spell.IsPressHoldReleaseSpell, id)
            hold = ok and not IsSecret(v) and v == true
        end
    end
    if self:GetAttribute("pressAndHoldAction") ~= hold then
        self:SetAttribute("pressAndHoldAction", hold)
    end
end

-- Empty slots stay clickable (secure Show/Hide is combat-locked and the main
-- bar's slots change in combat) -- they just draw nothing.
-- vbDrop: this is the bar's drop square (Bars.lua UpdateDropSlots) -- always drawn, with a "+".
function Button:UpdateEmpty()
    local visible = self.hasAction or VB:Get("showEmpty") or VB.dragging or VB.unlocked or self.vbDrop
        or VB.keybinding   -- keybind mode: empty slots can be bound too
    self:SetAlpha(visible and 1 or 0)
    self.vbEmpty:SetShown(not self.hasAction)
    self.vbPlus:SetShown((self.vbDrop and not self.hasAction) and true or false)
end

function Button:UpdateCount()
    if not self.hasAction then self.Count:SetText("") return end
    self.Count:SetText(C_ActionBar.GetActionDisplayCount(self.action))
end

-- Duration objects: the only cooldown path that works while cooldowns are
-- secret (M+, raids). The frame does the math; we never read the numbers.
function Button:UpdateCooldown()
    if not self.hasAction then
        self.cooldown:Clear()
        self.chargeCooldown:Clear()
        return
    end
    local ok, d = pcall(C_ActionBar.GetActionCooldownDuration, self.action)
    if ok and d then self.cooldown:SetCooldownFromDurationObject(d) else self.cooldown:Clear() end
    local ok2, cd = pcall(C_ActionBar.GetActionChargeDuration, self.action)
    if ok2 and cd then self.chargeCooldown:SetCooldownFromDurationObject(cd) else self.chargeCooldown:Clear() end
    self.cooldown:SetHideCountdownNumbers(not VB:Get("showCountdown"))
end

-- usable/noMana come from IsUsableAction or the ACTION_USABLE_CHANGED event.
function Button:UpdateUsable(usable, noMana)
    if not self.hasAction then return end
    if usable == nil then
        usable, noMana = C_ActionBar.IsUsableAction(self.action)
    end
    if IsSecret(usable) or IsSecret(noMana) then return end
    self.usable, self.noMana = usable, noMana
    self:ApplyTint()
end

function Button:UpdateRange(inRange, checksRange)
    if IsSecret(inRange) or IsSecret(checksRange) then return end
    self.outOfRange = checksRange and not inRange or nil
    self:ApplyTint()
end

function Button:ApplyTint()
    local c
    if self.outOfRange and VB:Get("rangeColor") then
        c = VB.COLOR.outOfRange
    elseif self.usable == false and self.noMana and VB:Get("resourceColor") then
        c = VB.COLOR.noResource
    elseif self.usable == false then
        c = VB.COLOR.unusable
    end
    if c then self.icon:SetVertexColor(c:GetRGB()) else self.icon:SetVertexColor(1, 1, 1) end
end

function Button:UpdateChecked()
    if not self.hasAction then self:SetChecked(false) return end
    local cur = C_ActionBar.IsCurrentAction(self.action)
    local auto = C_ActionBar.IsAutoRepeatAction(self.action)
    if IsSecret(cur) or IsSecret(auto) then return end
    self:SetChecked(cur or auto)
end

local KEY_SHORT = {
    { "SHIFT%-", "s" }, { "CTRL%-", "c" }, { "ALT%-", "a" }, { "META%-", "m" },
    { "MOUSEWHEELUP", "WU" }, { "MOUSEWHEELDOWN", "WD" }, { "MIDDLEMOUSE", "M3" },
    { "BUTTON(%d+)", "M%1" }, { "NUMPAD", "N" }, { "SPACE", "Sp" },
    { "CAPSLOCK", "Cap" }, { "BACKSPACE", "Bs" }, { "PAGEUP", "PU" }, { "PAGEDOWN", "PD" },
}
function VB.ShortKey(key)
    if not key then return "" end
    for _, r in ipairs(KEY_SHORT) do key = key:gsub(r[1], r[2]) end
    return key
end

function Button:UpdateHotkey()
    local key = VB:Get("showHotkeys") and self.bindCmd and GetBindingKey(self.bindCmd)
    self.HotKey:SetText(key and VB.ShortKey(key) or "")
    self.HotKey:Show()
end

function Button:UpdateName()
    if VB:Get("showMacroNames") and self.hasAction then
        self.Name:SetText(C_ActionBar.GetActionText(self.action) or "")
    else
        self.Name:SetText("")
    end
end

-- Proc glow: our own pulsing edge. (Blizzard's alert manager keeps one shared
-- table for every button -- writing to it from addon code could taint theirs.)
function Button:UpdateGlow()
    local on = false
    if VB:Get("procGlow") and self.hasAction and C_SpellActivationOverlay then
        local t, id, sub = GetActionInfo(self.action)
        if not IsSecret(id) and id and (t == "spell" or (t == "macro" and sub == "spell")) then
            local ok, lit = pcall(C_SpellActivationOverlay.IsSpellOverlayed, id)
            on = ok and not IsSecret(lit) and lit or false
        end
    end
    if on then
        if not self.vbGlow:IsShown() then self.vbGlow:Show(); self.vbGlow.anim:Play() end
    elseif self.vbGlow:IsShown() then
        self.vbGlow.anim:Stop(); self.vbGlow:Hide()
    end
end

----------------------------------------------------------------------
-- Mouse: tooltip, drag & drop (out of combat; same as Blizzard's locked bars,
-- Shift-drag picks up)
----------------------------------------------------------------------
function Button:VBOnEnter()
    if not self.action or not self.hasAction then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetAction(self.action)
    GameTooltip:Show()
end

function Button:VBOnLeave()
    GameTooltip:Hide()
end

function Button:VBOnDragStart()
    if InCombatLockdown() or not self.action then return end
    if GetCVarBool("lockActionBars") and not IsModifiedClick("PICKUPACTION") and not VB.unlocked then return end
    PickupAction(self.action)
    self:UpdateAll()
end

function Button:VBOnReceiveDrag()
    if InCombatLockdown() or not self.action then return end
    PlaceAction(self.action)
    self:UpdateAll()
end

function Button:VBPostClick()
    self:UpdateChecked()
end

----------------------------------------------------------------------
-- Event fan-out (one frame for every button)
----------------------------------------------------------------------
local function ForSlot(slot, method, ...)
    local t = bySlot[slot]
    if not t then return end
    for b in pairs(t) do b[method](b, ...) end
end

local function ForAll(method, ...)
    for _, b in ipairs(VB.allButtons) do
        if b.action then b[method](b, ...) end
    end
end

local fullPending = false
local function QueueFull()
    if fullPending then return end
    fullPending = true
    C_Timer.After(0, function()
        fullPending = false
        ForAll("UpdateAll")
    end)
end
VB.QueueFullUpdate = QueueFull

function VB:RefreshAllButtons()
    QueueFull()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES", "ACTIONBAR_UPDATE_STATE", "ACTION_USABLE_CHANGED",
    "ACTION_RANGE_CHECK_UPDATE", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
    "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "UPDATE_BINDINGS", "UPDATE_SHAPESHIFT_FORM",
    "SPELL_UPDATE_ICON", "UPDATE_MACROS", "BAG_UPDATE_DELAYED", "PLAYER_TARGET_CHANGED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
    "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID",
    "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "UNIT_INVENTORY_CHANGED",
    "PLAYER_REGEN_ENABLED",   -- refresh secure attributes skipped during combat
}) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
    if event == "ACTIONBAR_SLOT_CHANGED" then
        if a1 == 0 or a1 == nil then QueueFull() else ForSlot(a1, "UpdateAll") end
    elseif event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "LOSS_OF_CONTROL_ADDED"
        or event == "LOSS_OF_CONTROL_UPDATE" then
        ForAll("UpdateCooldown")
    elseif event == "SPELL_UPDATE_CHARGES" then
        ForAll("UpdateCooldown")
        ForAll("UpdateCount")
    elseif event == "ACTION_USABLE_CHANGED" then
        for _, change in ipairs(a1 or {}) do
            ForSlot(change.slot, "UpdateUsable", change.usable, change.noMana)
        end
    elseif event == "ACTION_RANGE_CHECK_UPDATE" then
        ForSlot(a1, "UpdateRange", a2, a3)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        ForAll("UpdateGlow")
    elseif event == "ACTIONBAR_UPDATE_STATE" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE"
        or event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL"
        or event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_LEAVE_COMBAT" then
        ForAll("UpdateChecked")
    elseif event == "UPDATE_BINDINGS" then
        ForAll("UpdateHotkey")
        if VB.ApplyBindings then VB:RunOutOfCombat("bindings", function() VB:ApplyBindings() end) end
    elseif event == "ACTIONBAR_SHOWGRID" then
        VB.dragging = true
        ForAll("UpdateEmpty")
    elseif event == "ACTIONBAR_HIDEGRID" then
        VB.dragging = false
        ForAll("UpdateEmpty")
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if a1 == "player" then QueueFull() end
    else
        QueueFull()
    end
    if (event == "ACTIONBAR_SLOT_CHANGED" or event == "PLAYER_ENTERING_WORLD") and VB.QueueDropSlots then
        VB:QueueDropSlots()
    end
end)
