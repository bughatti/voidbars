----------------------------------------------------------------------
-- VoidBars — PvP setup: VoidSequencer's PvP mode swaps your keys and your gear (the user, 2026-11-27: "the
-- st/aoe/pvp mode button, we need to setup when i select pvp it swaps gear and my naga buttons 2-7 and shift 1-7, 1
-- will stay the sequancer but have either the pvp seq or dungeon seq").
--
-- Two setups per character, "pve" (ST and AoE) and "pvp". Each holds:
--   actions  what sits behind keys 2-7 and Shift 1-7: every page those keys can show (keys 2-7 on the main bar also
--            flip to the stealth / form pages), read from your bindings, so it follows wherever you bound them
--   gear     every worn piece but shirt and tabard (an empty slot is left as it is, never stripped)
-- Crossing into or out of PvP mode saves the setup you're leaving and puts the other one on. The first time into a
-- mode nothing changes: set up your keys and gear, and the next switch saves them. ST <-> AoE never swaps.
-- Key 1 is VoidSequencer's own binding and is never touched; its rotation follows the mode by itself.
-- Out of combat only (placing actions and changing armor are blocked in combat): a switch in a fight swaps the
-- moment it ends. Works without VoidSequencer too: then there's no mode to follow and nothing happens.
-- VoidBarsCharDB.modeSets = { pve = {actions, gear}, pvp = {...} }, VoidBarsCharDB.modeCur = "pve" | "pvp".
----------------------------------------------------------------------
local _, VB = ...

local M = {}
VB.ModeSwap = M

M.KEYS = { "2", "3", "4", "5", "6", "7", "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-5", "SHIFT-6", "SHIFT-7" }
local GEAR = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }   -- no shirt (4) / tabard (19)
local MAIN_PAGES = { 1, 7, 8, 9, 10 }   -- bar1: normal, stealth / forms (Bars.lua PageDriver)
local Equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName

-- the action slots behind M.KEYS: "MULTIACTIONBAR1BUTTON3" -> bar2 page 6 -> slot 63
function M.Slots()
    local slots, seen = {}, {}
    local function add(s) if s >= 1 and s <= 180 and not seen[s] then seen[s] = true; slots[#slots + 1] = s end end
    for _, key in ipairs(M.KEYS) do
        local cmd = GetBindingAction(key) or ""
        for _, def in ipairs(VB.BAR_DEFS) do
            local n = def.bind and def.page and tonumber((cmd:match("^" .. def.bind .. "(%d+)$")))
            if n and n >= 1 and n <= 12 then
                for _, page in ipairs(def.paging and MAIN_PAGES or { def.page }) do add((page - 1) * 12 + n) end
            end
        end
    end
    table.sort(slots)
    return slots
end

-- riding gear on for a ride (MountGear.lua) isn't part of a setup: what it replaced is
local function worn()
    local g = {}
    local ride = VoidBarsCharDB and VoidBarsCharDB.mountSaved or {}
    for _, slot in ipairs(GEAR) do
        local r = ride[slot]
        if r and r.back ~= nil then g[slot] = r.back or false else g[slot] = GetInventoryItemLink("player", slot) or false end
    end
    return g
end

function M.Snapshot()
    local s = { saved = time(), actions = {}, gear = worn() }
    for _, slot in ipairs(M.Slots()) do s.actions[slot] = VB.DescribeSlot(slot) or false end
    return s
end

local function inBags(link)
    local id = link and tonumber((link:match("item:(%d+)")))
    local same
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for s = 1, C_Container.GetContainerNumSlots(bag) do
            local l = C_Container.GetContainerItemLink(bag, s)
            if l == link then return true end
            if l and id and tonumber((l:match("item:(%d+)"))) == id then same = true end
        end
    end
    return same
end

-- put a saved setup on; returns placed, cleared, pieces, missing (names)
function M.Apply(set)
    local placed, cleared, pieces, missing = 0, 0, 0, {}
    ClearCursor()
    -- only slots your keys use now: rebinding since the save must not land old buttons on other keys (Codex 11-27)
    local now = {}
    for _, s in ipairs(M.Slots()) do now[s] = true end
    for slot, want in pairs(set.actions or {}) do
        want = want or nil
        local have = VB.DescribeSlot(slot)
        local skip = not now[slot] or (want and want.skip) or (have and have.skip)
        if not skip and not VB.SameEntry(want, have) then
            if want then
                if VB.PickupEntry(want) then PlaceAction(slot); placed = placed + 1 end
            elseif have then
                ClearCursor()
                PickupAction(slot)
                cleared = cleared + 1
            end
            ClearCursor()
        end
    end
    -- main hand before off hand (a new main hand can push the off hand off)
    for _, slot in ipairs(GEAR) do
        local link = set.gear and set.gear[slot]
        if link and GetInventoryItemLink("player", slot) ~= link then
            -- worn in another slot (rings, trinkets or weapons the other way round): swap the two, like dragging it
            -- on the character sheet (Codex 11-27: both were "not in your bags" and nothing moved)
            local from
            for _, o in ipairs(GEAR) do
                if o ~= slot and GetInventoryItemLink("player", o) == link then from = o break end
            end
            if from then
                ClearCursor()
                PickupInventoryItem(from)
                PickupInventoryItem(slot)
                ClearCursor()
                pieces = pieces + 1
            elseif inBags(link) then
                Equip(link, slot)
                pieces = pieces + 1
            else
                missing[#missing + 1] = link
            end
        end
    end
    ClearCursor()
    return placed, cleared, pieces, missing
end

local function db()
    VoidBarsCharDB.modeSets = VoidBarsCharDB.modeSets or {}
    return VoidBarsCharDB
end

M.LABEL = { pve = "dungeon", pvp = "PvP" }

-- the mode VoidSequencer is in now -> swap if it isn't the setup we have on
function M.Sync(pvp)
    if not VoidBarsCharDB then return end
    local want = pvp and "pvp" or "pve"
    local d = db()
    if not d.modeCur then d.modeCur = want; return end   -- first run: what you wear now belongs to this mode
    if d.modeCur == want then return end
    VB:RunOutOfCombat("modeswap", function()
        -- the mode may have changed back during the fight
        local api = _G.VoidSequencerAPI
        local nowPvp = api and api.IsPvpMode and api.IsPvpMode()
        local target = nowPvp and "pvp" or "pve"
        if d.modeCur == target then return end
        d.modeSets[d.modeCur] = M.Snapshot()
        local set = d.modeSets[target]
        local was = d.modeCur
        d.modeCur = target
        if not set then
            VB:Print(("%s setup: first time. Put your %s keys and gear on now; switching back saves them and puts your %s setup on."):format(
                M.LABEL[target], M.LABEL[target], M.LABEL[was]))
            return
        end
        local placed, cleared, pieces, missing = M.Apply(set)
        VB:Print(("%s setup on: %d buttons placed, %d cleared, %d gear pieces%s."):format(M.LABEL[target], placed, cleared,
            pieces, #missing > 0 and (", not in your bags: " .. table.concat(missing, ", ")) or ""))
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    local api = _G.VoidSequencerAPI
    if not (api and api.OnModeChange) then return end
    api.OnModeChange(M.Sync)
    -- the mode as it stands after login (VoidSequencer pushes it again when its rotation loads)
    C_Timer.After(3, function() if api.IsPvpMode then M.Sync(api.IsPvpMode()) end end)
end)
