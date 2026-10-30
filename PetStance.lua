----------------------------------------------------------------------
-- VoidBars — pet bar + stance/form bar. Same Void buttons, pinned where the
-- player put them (Blizzard's pet bar is a frame Edit Mode re-lays out, e.g.
-- after a vehicle; ours never moves).
--
-- Pet:    secure type "pet", action 1..10 -> CastPetAction. Right-click is
--         delegated to Blizzard's PetActionButtonN (toggles autocast).
-- Stance: secure type "spell" with the form's spellID (casting the active
--         form's spell leaves it, as on Blizzard's bar).
----------------------------------------------------------------------
local _, VB = ...

local IsSecret = VB.IsSecret
local PetButton, StanceButton = {}, {}
VB.petButtons, VB.stanceButtons = {}, {}

local function MakeBase(header, index, name, kind)
    local b = CreateFrame("CheckButton", name, header, "ActionButtonTemplate, SecureActionButtonTemplate")
    b.header, b.index, b.kind = header, index, kind
    b:RegisterForClicks("AnyDown", "AnyUp")
    VB.Button.Style(b)
    b.ApplySize = VB.Button.ApplySize
    b.UpdateHotkey = VB.Button.UpdateHotkey
    -- Key presses arrive as "Keybind" (Bindings.lua); act as a left click.
    SecureHandlerWrapScript(b, "OnClick", header, [[
        if button == "Keybind" then return "LeftButton" end
    ]])
    b:HookScript("PostClick", function(self) self:UpdateAll() end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    VB.allButtons[#VB.allButtons + 1] = b
    return b
end

-- Cooldown from start/duration numbers. Pet/stance cooldowns have no
-- duration-object API; if they ever come back secret, hand them straight to
-- the cooldown frame (display-only) instead of comparing them.
local function SetCD(cd, start, duration, enable)
    if IsSecret(start) or IsSecret(duration) then
        pcall(cd.SetCooldown, cd, start, duration)
    elseif enable and enable ~= 0 and duration and duration > 0 then
        cd:SetCooldown(start, duration)
    else
        cd:Clear()
    end
end

----------------------------------------------------------------------
-- Pet
----------------------------------------------------------------------
function VB:CreatePetButton(header, index, name)
    local b = MakeBase(header, index, name, "pet")
    Mixin(b, PetButton)
    b:SetAttribute("type", "pet")
    b:SetAttribute("action", index)
    -- Right-click goes to Blizzard's own (parked) pet button for this slot, whose
    -- handler toggles autocast for whatever pet is out -- even one swapped in
    -- combat. Without an explicit type2, right-click fell back to "pet" and ran
    -- Attack/Follow/Stay.
    b:SetAttribute("type2", "click")
    b:SetAttribute("clickbutton2", _G["PetActionButton" .. index])
    b:HookScript("OnEnter", function(self)
        if not self.hasAction then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetPetAction(self.index)
        GameTooltip:Show()
    end)
    VB.petButtons[#VB.petButtons + 1] = b
    return b
end

function PetButton:UpdateAll()
    local name, texture, isToken, isActive, autoAllowed, autoOn, _, checksRange, inRange = GetPetActionInfo(self.index)
    self.hasAction = name ~= nil
    if self.hasAction then
        self.icon:SetTexture(isToken and _G[texture] or texture)
        self.icon:Show()
    else
        self.icon:Hide()
    end
    self:SetAlpha((self.hasAction or VB:Get("showEmpty") or VB.unlocked) and 1 or 0)
    self.vbEmpty:SetShown(not self.hasAction)
    if not IsSecret(isActive) then self:SetChecked(isActive and true or false) end
    if self.AutoCastOverlay then
        self.AutoCastOverlay:SetShown(autoAllowed and true or false)
        if self.AutoCastOverlay.ShowAutoCastEnabled then self.AutoCastOverlay:ShowAutoCastEnabled(autoOn and true or false) end
    end
    local out = VB:Get("rangeColor") and checksRange and not inRange
    if not (IsSecret(checksRange) or IsSecret(inRange)) then
        if out then self.icon:SetVertexColor(VB.COLOR.outOfRange:GetRGB()) else self.icon:SetVertexColor(1, 1, 1) end
    end
    SetCD(self.cooldown, GetPetActionCooldown(self.index))
    self:UpdateHotkey()
end

----------------------------------------------------------------------
-- Stance / form
----------------------------------------------------------------------
function VB:CreateStanceButton(header, index, name)
    local b = MakeBase(header, index, name, "stance")
    Mixin(b, StanceButton)
    b:SetAttribute("type", "spell")
    b:HookScript("OnEnter", function(self)
        if not self.hasAction then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetShapeshift(self.index)
        GameTooltip:Show()
    end)
    VB.stanceButtons[#VB.stanceButtons + 1] = b
    return b
end

function StanceButton:UpdateAll()
    local icon, active, castable, spellID
    if self.index <= GetNumShapeshiftForms() then
        icon, active, castable, spellID = GetShapeshiftFormInfo(self.index)
    end
    self.hasAction = icon ~= nil
    if self.hasAction then
        self.icon:SetTexture(icon)
        self.icon:Show()
    else
        self.icon:Hide()
    end
    self:SetAlpha((self.hasAction or VB.unlocked) and 1 or 0)
    self.vbEmpty:SetShown(not self.hasAction)
    if not IsSecret(active) then self:SetChecked(active and true or false) end
    if not IsSecret(castable) then
        if castable == false then self.icon:SetVertexColor(VB.COLOR.unusable:GetRGB()) else self.icon:SetVertexColor(1, 1, 1) end
    end
    SetCD(self.cooldown, GetShapeshiftFormCooldown(self.index))
    self:UpdateHotkey()
    if not InCombatLockdown() and self:GetAttribute("spell") ~= spellID then
        self:SetAttribute("spell", spellID)
    end
end

-- Stance bar shows only for classes/specs that have forms; the count can
-- change with talents. Visibility is a secure state driver -> out of combat.
function VB:UpdateStanceVisibility()
    local bar = self.bars.stance
    if not bar then return end
    local cfg = self:BarConfig("stance")
    local has = (GetNumShapeshiftForms() or 0) > 0
    RegisterStateDriver(bar, "visibility",
        (cfg.enabled and has) and ("[petbattle][vehicleui][overridebar] hide; " .. self:ShowRule(cfg)) or "hide")
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local function UpdateList(list)
    for _, b in ipairs(list) do b:UpdateAll() end
end

-- Bars are created after the login events fired: paint them once on takeover.
function VB:UpdatePetStanceButtons()
    UpdateList(self.petButtons)
    UpdateList(self.stanceButtons)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({
    "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PET_UI_UPDATE", "PET_BAR_UPDATE_USABLE",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED",
    "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE",
    "UPDATE_SHAPESHIFT_COOLDOWN", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS",
}) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:RegisterUnitEvent("UNIT_PET", "player")
ev:RegisterUnitEvent("UNIT_FLAGS", "pet")
ev:RegisterUnitEvent("UNIT_AURA", "pet")
ev:SetScript("OnEvent", function(_, event)
    if event:find("SHAPESHIFT") then
        UpdateList(VB.stanceButtons)
        if event == "UPDATE_SHAPESHIFT_FORMS" then
            VB:RunOutOfCombat("stancevis", function() VB:UpdateStanceVisibility() end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_BINDINGS" or event == "PLAYER_REGEN_ENABLED" then
        UpdateList(VB.petButtons)
        UpdateList(VB.stanceButtons)
    else
        UpdateList(VB.petButtons)
    end
end)
