----------------------------------------------------------------------
-- VoidBars — keybind mode: hover a button, press a key.
-- /vbars bind (or Options -> "Keybind mode", or the VoidHub menu).
--
-- Keys are set on Blizzard's own binding commands (ACTIONBUTTON3,
-- MULTIACTIONBAR1BUTTON5, BONUSACTIONBUTTON2, ...), the same ones Options ->
-- Keybindings edits, so they survive turning VoidBars off. Bindings.lua then
-- routes them to our buttons (UPDATE_BINDINGS), and the hotkey text updates.
--
-- While hovering a bindable button: any key (with Shift / Ctrl / Alt) binds it,
-- middle / side mouse buttons and the wheel too. Backspace or Delete clears that
-- button's keys. Esc (or Done) leaves. Combat ends the mode: SetBinding and
-- keyboard capture are protected in combat.
----------------------------------------------------------------------
local _, VB = ...

local active, hovered
local capture, banner

local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true,
}
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function Bindable(f)
    return f and f.bindCmd and f.header and f.header.def and true or false
end

local function ButtonLabel(b)
    return ("%s, button %d"):format(b.header.def.label, b.index or 0)
end

local function KeysOf(cmd)
    local keys = { GetBindingKey(cmd) }
    return #keys > 0 and table.concat(keys, ", ") or "none"
end

local function ShowTip(b)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:AddLine(ButtonLabel(b), 1, 1, 1)
    GameTooltip:AddLine("Keys: " .. KeysOf(b.bindCmd), VB.COLOR.accent:GetRGB())
    GameTooltip:AddLine("Press a key to bind it here. Backspace clears. Esc finishes.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

local function Combo(key)
    local mods = ""
    if IsAltKeyDown() then mods = mods .. "ALT-" end
    if IsControlKeyDown() then mods = mods .. "CTRL-" end
    if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
    if IsMetaKeyDown and IsMetaKeyDown() then mods = mods .. "META-" end
    return mods .. key
end

local function Save()
    SaveBindings(GetCurrentBindingSet())
end

local function Bind(key)
    local b = hovered
    if not b or InCombatLockdown() then return end
    local old = GetBindingAction(key, false)
    if old and old ~= "" and old ~= b.bindCmd then
        VB:Print(("%s was on %s; it's on %s now."):format(key, old, ButtonLabel(b)))
    end
    if SetBinding(key, b.bindCmd) then
        Save()
    else
        VB:Print(("couldn't bind %s."):format(key))
    end
    ShowTip(b)
end

local function Clear()
    local b = hovered
    if not b or InCombatLockdown() then return end
    for _, key in ipairs({ GetBindingKey(b.bindCmd) }) do SetBinding(key) end
    Save()
    ShowTip(b)
end

----------------------------------------------------------------------
-- Frames: a keyboard catcher (only swallows keys while over a button) and an
-- overlay on the hovered button that takes mouse buttons / wheel.
----------------------------------------------------------------------
local function SetHovered(b)
    if b == hovered then return end
    hovered = b
    if b then
        capture:ClearAllPoints()
        capture:SetAllPoints(b)
        capture:Show()
        capture:SetPropagateKeyboardInput(false)
        ShowTip(b)
    else
        capture:Hide()
        GameTooltip:Hide()
    end
end

local function Build()
    capture = CreateFrame("Button", nil, UIParent)
    capture:SetFrameStrata("TOOLTIP")
    capture:EnableKeyboard(true)
    capture:EnableMouseWheel(true)
    capture:RegisterForClicks("AnyUp")
    local hl = capture:CreateTexture(nil, "OVERLAY")
    hl:SetAllPoints()
    hl:SetColorTexture(VB.COLOR.accent.r, VB.COLOR.accent.g, VB.COLOR.accent.b, 0.35)
    capture:Hide()
    capture:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then VB:SetKeybindMode(false) return end
        if MODIFIER_KEYS[key] then return end
        if key == "BACKSPACE" or key == "DELETE" then Clear() return end
        Bind(Combo(key))
    end)
    capture:SetScript("OnClick", function(_, button)
        local k = MOUSE_KEYS[button]
        if k then Bind(Combo(k)) end
    end)
    capture:SetScript("OnMouseWheel", function(_, delta)
        Bind(Combo(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    end)
    capture:SetScript("OnLeave", function() SetHovered(nil) end)

    banner = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    banner:SetSize(420, 56)
    banner:SetPoint("TOP", 0, -110)
    banner:SetFrameStrata("DIALOG")
    banner:SetBackdrop({ bgFile = VB.TEX, edgeFile = VB.TEX, edgeSize = 1 })
    banner:SetBackdropColor(0.04, 0.04, 0.06, 0.92)
    banner:SetBackdropBorderColor(VB.COLOR.accent:GetRGB())
    local t = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", 12, 0)
    t:SetPoint("RIGHT", -96, 0)
    t:SetJustifyH("LEFT")
    t:SetText("Keybind mode: hover a VoidBars button and press a key. Backspace clears. Esc finishes.")
    local done = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    done:SetSize(76, 24)
    done:SetPoint("RIGHT", -10, 0)
    done:SetText(DONE or "Done")
    done:SetScript("OnClick", function() VB:SetKeybindMode(false) end)
    -- Esc anywhere ends the mode; every other key passes through to the game while
    -- no button is hovered (the overlay takes keys when one is)
    banner:EnableKeyboard(true)
    banner:SetPropagateKeyboardInput(true)
    banner:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            VB:SetKeybindMode(false)
            C_Timer.After(0, function() if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end end)
        end
    end)
    -- find the hovered button (our buttons keep their own mouse handling)
    banner:SetScript("OnUpdate", function()
        if hovered then return end   -- the overlay's OnLeave clears it
        local foci = GetMouseFoci and GetMouseFoci()
        local f = foci and foci[1]
        if Bindable(f) and f:IsVisible() then SetHovered(f) end
    end)
    banner:Hide()
end

function VB:SetKeybindMode(on)
    if on and InCombatLockdown() then self:Print("keybind mode opens out of combat.") return end
    if not capture then Build() end
    active = on and true or false
    VB.keybinding = active
    SetHovered(nil)
    banner:SetShown(active)
    -- the Esc handler turns propagation off for its key; a combat start could have
    -- stopped it being turned back on
    if not InCombatLockdown() then banner:SetPropagateKeyboardInput(true) end
    self:QueueFullUpdate()   -- empty slots show while binding (Button:UpdateEmpty)
    -- bars with a show rule (combat only, ...) show while binding (VB:ShowRule)
    self:RunOutOfCombat("visibility", function() self:ApplyVisibility() end)
    if active then
        if self.unlocked then self:SetUnlocked(false) end   -- handles would cover the buttons
        self:Print("keybind mode on. Hover a button, press a key. Esc when done.")
    end
end

function VB:IsKeybindMode() return active end

local guard = CreateFrame("Frame")
guard:RegisterEvent("PLAYER_REGEN_DISABLED")
guard:SetScript("OnEvent", function()
    if active then
        VB:SetKeybindMode(false)
        VB:Print("keybind mode closed for combat.")
    end
end)
