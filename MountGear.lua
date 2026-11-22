----------------------------------------------------------------------
-- VoidBars — riding gear: puts your mount-speed gear on when you mount and your normal pieces back when you
-- get down. The user, 2026-11-19: "a way to auto put on mount stuff when mounted and put the other stuff back on
-- when dismounted"; picked: auto-detect + anything added by hand, part of VoidBars.
--
-- Riding gear = anything whose tooltip (enchants included) says "mount speed" or "riding skill", Mithril Spurs on
-- boots, Carrot on a Stick, plus items added in Options. Any color, bound or not.
-- Game rules: out of combat any gear swaps; in combat none of this runs (armor can't change in combat), so a
-- dismount into a fight puts your pieces back the moment combat ends. A trinket put back on starts a 30 s
-- cooldown, so the riding trinket goes in the slot WITHOUT an on-use trinket / PvP-bar item when it can.
--
-- One 0.5 s check (no event juggling): mounted + not done yet -> put riding gear on; not mounted + something of
-- ours still worn -> put the normal piece back (waits through combat, death, casting, a taxi, a reload).
-- VoidBarsCharDB.mountSaved[slot] = { put = itemID we put on, back = link of what came off (false = was empty) }.
----------------------------------------------------------------------
local _, VB = ...
local IsSecret = VB.IsSecret

local M = {}
VB.MountGear = M

local CARROT = 11122
local Equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName   -- 12.1.5 moved item globals to C_Item
local WORDS = { "mount speed", "riding skill", "mithril spurs" }

-- equip location -> the slots it can go in
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 12, 11 }, INVTYPE_TRINKET = { 14, 13 }, INVTYPE_CLOAK = { 15 },
}
M.SLOTS = SLOTS

local function db()
    VoidBarsCharDB.mountSaved = VoidBarsCharDB.mountSaved or {}
    return VoidBarsCharDB.mountSaved
end
local function added()
    VoidBarsCharDB.mountGearAdded = VoidBarsCharDB.mountGearAdded or {}
    return VoidBarsCharDB.mountGearAdded
end

local function idOf(link)
    if not link or IsSecret(link) then return nil end
    return C_Item.GetItemInfoInstant(link)
end

-- the tooltip says it (enchant lines included: Riding Skill gloves, spurs on boots)
local cache = {}
local function saysMountSpeed(data)
    if not (data and data.lines) then return nil end
    for _, line in ipairs(data.lines) do
        local t = line.leftText
        if t and not IsSecret(t) then
            t = t:lower()
            for _, w in ipairs(WORDS) do
                if t:find(w, 1, true) then return true end
            end
        end
    end
    return false
end

-- is this item (by link, read from where it sits) riding gear?
local function isRiding(link, tooltipFn)
    local id = idOf(link)
    if not id then return false end
    if id == CARROT or added()[id] then return true end
    if cache[link] ~= nil then return cache[link] end
    local ok, data = pcall(tooltipFn)
    local hit = ok and saysMountSpeed(data)
    if hit == nil then return false end   -- tooltip not loaded yet: ask again next time
    cache[link] = hit
    return hit
end
M.IsRiding = isRiding

function M.IsRidingWorn(slot)
    local link = GetInventoryItemLink("player", slot)
    return link and isRiding(link, function() return C_TooltipInfo.GetInventoryItem("player", slot) end) or false
end

-- an item id known as riding gear (Carrot, added by hand, or a tooltip already read as riding gear)
function M.WasRiding(id)
    if not id then return false end
    if id == CARROT or added()[id] then return true end
    for link, hit in pairs(cache) do
        if hit and idOf(link) == id then return true end
    end
    return false
end

-- a slot holding a piece we put on (for SmartBars: not "main gear", and the PvP bar's swap-back)
function M:Holds(slot)
    local s = VoidBarsCharDB and VoidBarsCharDB.mountSaved and VoidBarsCharDB.mountSaved[slot]
    return s and GetInventoryItemID("player", slot) == s.put and s or nil
end
function M:Forget(slot)
    if VoidBarsCharDB and VoidBarsCharDB.mountSaved then VoidBarsCharDB.mountSaved[slot] = nil end
end

-- Any riding piece goes on, bound or not, any color. The user, 2026-11-22: "blue, purple, white, none of it should
-- matter, if it has the gloves enchant or boot riding skill it should be swapped". (It used to be bound pieces only;
-- their Battered Leather Gloves / Boots, logged in game, are white and never bind, so they were skipped. Enchants and
-- spurs bind gear anyway; a piece that would still bind on equip gets the game's own question once.)

-- the riding pieces in your bags: { {link, bag, slot, equipLoc}, ... }
local function bagPieces()
    local out = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and not IsSecret(link) then
                local _, _, _, loc = C_Item.GetItemInfoInstant(link)
                if loc and SLOTS[loc] and isRiding(link, function() return C_TooltipInfo.GetBagItem(bag, slot) end) then
                    out[#out + 1] = { link = link, loc = loc }
                end
            end
        end
    end
    return out
end

-- a worn trinket / ring that must not come off for a ride: one with an on-use, or one on the PvP bar
local function keepOn(slot)
    local id = GetInventoryItemID("player", slot)
    if not id then return false end
    if C_Item.GetItemSpell(id) then return true end
    return VB.IsPvPItem and VB.IsPvPItem(id) or false
end

-- which slot a piece goes in: the only one, or (trinket / ring) one not already riding gear, best one that
-- isn't an on-use / PvP piece
local function slotFor(loc)
    local slots = SLOTS[loc]
    for _, s in ipairs(slots) do
        if M.IsRidingWorn(s) then return nil end   -- already riding in this group
    end
    if #slots == 1 then return slots[1] end
    for _, s in ipairs(slots) do
        if not keepOn(s) then return s end
    end
    return slots[1]
end

-- HasFullControl: a flight path takes your controls the moment it starts, before UnitOnTaxi turns true; the
-- Carrot went on for flight-path rides (the user, 2026-11-20: "it is doing it with the flight mounts from place to
-- place, it should only be for ground mounts")
local function busy()
    return InCombatLockdown() or UnitIsDeadOrGhost("player") or UnitOnTaxi("player")
        or (HasFullControl and not HasFullControl())
        or UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
end

-- riding gear is for your own GROUND mount: never a flight path, never while flying
local function onGroundMount()
    if not IsMounted() then return false end
    if UnitOnTaxi("player") or (HasFullControl and not HasFullControl()) then return false end
    if IsFlying and IsFlying() then return false end
    return true
end

local APPLY_TICKS = 6   -- after mounting, keep trying 3 s (a locked item, a tooltip not loaded yet), then leave it
local BACK_TRIES = 8    -- after getting down, try 4 s to put a piece back, then give up on that slot

local function locked(slot)
    return IsInventoryItemLocked and IsInventoryItemLocked(slot) or false
end

local said = false
local function putOn()
    local names = {}
    local saved = db()
    for _, p in ipairs(bagPieces()) do   -- riding pieces still in the bags
        local id = idOf(p.link)
        local slot, s
        for sl, r in pairs(saved) do
            if r.put == id then slot, s = sl, r end
        end
        if s then
            -- already tried: again only while the slot still holds what was there (a slow or locked swap),
            -- never over something you put there yourself (Sol)
            -- once it was on (landed), it came off by your hand: leave it (Sol, 2nd pass)
            if not s.landed and (GetInventoryItemLink("player", slot) or false) == s.back and not locked(slot) then
                Equip(p.link, slot)
            end
        else
            slot = slotFor(p.loc)
            if slot and not saved[slot] and not locked(slot) then
                saved[slot] = { put = id, back = GetInventoryItemLink("player", slot) or false }
                Equip(p.link, slot)
                names[#names + 1] = C_Item.GetItemNameByID(id) or "riding gear"
            end
        end
    end
    if #names > 0 and not said then
        said = true
        VB:Print(("riding gear on (%s); your own pieces go back when you get down. Options -> VoidBars to turn this off.")
            :format(table.concat(names, ", ")))
    end
end

-- a general bag with a free slot (for a riding piece that went into an empty slot)
local function freeBag()
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if free and free > 0 and (family == nil or family == 0) then return bag end
    end
end

-- A record stays until the slot no longer holds what we put on (done, or you changed it yourself). A swap the game
-- didn't take is tried again on the next tick (Sol); after BACK_TRIES real tries it waits for the next mount /
-- dismount (or reload) to try again, and the record is KEPT (Astra: a locked slot or full bags must not lose your
-- piece for good). Waiting on a locked slot or full bags uses no tries.
local function putBack()
    local saved = db()
    for slot, s in pairs(saved) do
        if GetInventoryItemID("player", slot) ~= s.put then
            saved[slot] = nil   -- done, or you changed it yourself
        elseif locked(slot) or (s.tries or 0) >= BACK_TRIES then
            -- the game is still moving it / tried enough for now: wait
        elseif s.back then
            if (C_Item.GetItemCount(s.back) or 0) > 0 then
                s.tries = (s.tries or 0) + 1
                Equip(s.back, slot)
            else
                saved[slot] = nil   -- your piece isn't in the bags any more (sold, banked): nothing to put back
            end
        else
            -- the slot was empty before the ride: take the riding piece off into a bag with room (Sol)
            local bag = freeBag()
            if bag then
                s.tries = (s.tries or 0) + 1
                ClearCursor()
                PickupInventoryItem(slot)
                if bag == 0 then PutItemInBackpack() else PutItemInBag(C_Container.ContainerIDToInventoryID(bag)) end
                if CursorHasItem and CursorHasItem() then ClearCursor() end   -- never leave it on the cursor
            elseif not s.toldFull then
                s.toldFull = true
                VB:Print(("your bags are full: %s stays on until there's room."):format(
                    C_Item.GetItemNameByID(s.put) or "your riding gear"))
            end
        end
    end
end

local wasMounted, applyTicks = nil, 0
function M:Tick()
    if not VoidBarsCharDB then return end
    if VoidBarsCharDB._dbgMount then VoidBarsCharDB._dbgMount, VoidBarsCharDB._dbgMountOn = nil, nil end   -- 11-22 debug log
    local on = VB:Get("mountGear") ~= false
    local mounted = onGroundMount()
    if mounted ~= wasMounted then
        wasMounted = mounted
        applyTicks = 0
        -- a new mount / dismount: try again; a record whose piece already came off is done (a remount within
        -- half a second still held the last ride's "landed" record, and the Carrot stayed off)
        local saved = db()
        for slot, s in pairs(saved) do
            if GetInventoryItemID("player", slot) ~= s.put then saved[slot] = nil else s.tries = 0 end
        end
    end
    if busy() then return end
    if mounted then
        if on and applyTicks < APPLY_TICKS then
            applyTicks = applyTicks + 1
            putOn()
        end
    elseif next(db()) then
        -- turned off while riding: no new swaps, but your pieces still go back (Astra)
        putBack()
    end
end

-- the item on the cursor becomes riding gear (Options button)
function M:AddCursor()
    local kind, id = GetCursorInfo()
    ClearCursor()
    local loc = id and select(4, C_Item.GetItemInfoInstant(id))   -- not "id and f(id)": that keeps one value
    if kind ~= "item" or not (loc and SLOTS[loc]) then
        VB:Print("pick up a piece of gear first (a trinket, gloves, boots...), then click Add.")
        return
    end
    added()[id] = true
    VB:Print(("%s is riding gear now: it goes on when you mount."):format(C_Item.GetItemNameByID(id) or "that item"))
end
function M:ForgetAdded()
    VoidBarsCharDB.mountGearAdded = {}
    wipe(cache)
    VB:Print("riding gear you added by hand is forgotten (Carrot on a Stick and mount-speed gear still count).")
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.5, function() M:Tick() end)
end

-- a riding piece seen going on is "landed": it's never put on again this ride (you took it off yourself)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:SetScript("OnEvent", function(_, _, slot)
    local s = slot and VoidBarsCharDB and VoidBarsCharDB.mountSaved and VoidBarsCharDB.mountSaved[slot]
    if s and GetInventoryItemID("player", slot) == s.put then s.landed = true end
end)
