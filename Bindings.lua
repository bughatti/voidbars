----------------------------------------------------------------------
-- VoidBars — keybinds. Nothing to re-bind: whatever key you set on a
-- Blizzard action button (Options -> Keybindings -> Action Bars) is routed
-- to the matching VoidBars button. Change a bind there and it follows
-- automatically (UPDATE_BINDINGS).
--
-- Keys already bound to something else (e.g. 1 -> VoidSequencer's button)
-- aren't on an ACTIONBUTTON command, so they're left alone.
--
-- The bindings live on a SECURE handler so they can switch in combat:
--   * pet battles: our overrides are dropped, so the action keys reach
--     Blizzard's pet battle UI again (abilities, swap, trap);
--   * key presses arrive as the "Keybind" button, which lets a button tell
--     a key press from a mouse click (Shift+mouse-down picks up the spell
--     instead of casting it -- Shift+key still casts).
----------------------------------------------------------------------
local _, VB = ...

local owner = CreateFrame("Frame", "VoidBarsBindingOwner", UIParent, "SecureHandlerStateTemplate")

-- Shared by the state handler and ApplyBindings.
local APPLY = [[
    self:ClearBindings()
    if self:GetAttribute("state-petbattle") ~= "on" then
        for key, name in pairs(binds) do
            self:SetBindingClick(false, key, name, "Keybind")
        end
    end
]]

-- The secure setup is blocked under combat lockdown, and a /reload mid-fight loads this
-- file under it (2026-11-07: every Void addon's secure setup failed that way and the keys
-- stayed dead all session). So it runs once, out of combat: now, or the first time the
-- bindings are applied (always out of combat).
local ownerReady
local function setupOwner()
    if ownerReady or InCombatLockdown() then return ownerReady end
    owner:Execute([[ binds = newtable() ]])
    owner:SetAttribute("_onstate-petbattle", APPLY)
    RegisterStateDriver(owner, "petbattle", "[petbattle] on; off")
    ownerReady = true
    return true
end
setupOwner()

local applied   -- signature of the binds currently set

-- The combat block promises keys 1-7 and Shift+1-7 (2026-10-28). A new character has no
-- keys on bar 2 and Shift+1-6 on Blizzard's "action page 1-6", so the block binds what's
-- missing: only commands with no key at all, and the keys they replace are kept in
-- VoidBarsCharDB.displacedBinds. Key 1 stays with VoidSequencer while it runs; a key 1
-- still aimed at a VoidSequencer that's gone or switched off goes back to the main bar.
-- Out of combat only. Returns how many keys it set.
function VB:EnsureBlockBindings()
    if InCombatLockdown() then return 0 end
    local seq = self.SeqActive and self.SeqActive()
    VoidBarsCharDB.displacedBinds = VoidBarsCharDB.displacedBinds or {}
    local n = 0
    local function bind(key, cmd)
        local old = GetBindingAction(key)
        if old == cmd then return end
        -- Never take a key from another bar button (a player who moved 2 onto button 1 keeps it).
        if old and (old:find("^ACTIONBUTTON%d+$") or old:find("^MULTIACTIONBAR%dBUTTON%d+$")) then return end
        if old and old ~= "" then VoidBarsCharDB.displacedBinds[key] = old end
        if SetBinding(key, cmd) then n = n + 1 end
    end
    for i = 1, 7 do
        local cmd = "ACTIONBUTTON" .. i
        if i == 1 then
            if not seq and (GetBindingAction("1"):find("^CLICK VoidSeqButton") or not GetBindingKey(cmd)) then
                bind("1", cmd)
            end
        elseif not GetBindingKey(cmd) then
            bind(tostring(i), cmd)
        end
        local shift = "MULTIACTIONBAR1BUTTON" .. i
        if not GetBindingKey(shift) then bind("SHIFT-" .. i, shift) end
    end
    if n > 0 then SaveBindings(GetCurrentBindingSet()) end
    return n
end

-- Out of combat only (callers use VB:RunOutOfCombat).
function VB:ApplyBindings()
    if not setupOwner() then return end
    local wanted, parts = {}, {}
    for _, bar in ipairs(self.bars) do
        local cfg = self:BarConfig(bar.def.key)
        if cfg.enabled then
            for i, b in ipairs(bar.buttons) do
                if b.bindCmd and i <= (cfg.num or 12) then   -- smart-bar buttons have no binding command
                    for _, key in ipairs({ GetBindingKey(b.bindCmd) }) do
                        wanted[#wanted + 1] = { key, b:GetName() }
                        parts[#parts + 1] = key .. "=" .. b:GetName()
                    end
                end
            end
        end
    end
    -- Setting bindings fires UPDATE_BINDINGS, which calls us again: only touch
    -- them when something actually changed, or it loops forever.
    local sig = table.concat(parts, ";")
    if sig == applied then return end
    applied = sig
    owner:Execute([[ binds = newtable() ]])
    for _, w in ipairs(wanted) do
        owner:Execute(("binds[%q] = %q"):format(w[1], w[2]))
    end
    owner:Execute(APPLY)
end
