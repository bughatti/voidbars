----------------------------------------------------------------------
-- VoidBars — smart bars: bars that fill themselves from your bags instead
-- of action slots (they never use any of the 180 server-side slots).
--
-- Consumables (one button per JOB, best version only, current expansion only):
--   healthstone, health potion, combat potion, flask/phial, buff food, feast,
--   weapon oil/stone, augment rune, vantus rune (raids only); also plain food (eat)
--   and water (drink, mana users) to recover between pulls, mage food included;
--   plus one recovery spell you know (Cannibalize, Gift of the Naaru, ...) and your
--   class's group buff (Mark of the Wild, Arcane Intellect, ...), first on the bar.
-- Shift+right-click a button to hide that item from the bar for good (reset in options);
-- a plain right-click uses it, like left-click.
-- Travel: hearthstone, class teleport, Teleport Home, Switch Flight Style,
-- random mount + your own list of mounts/toys/items/spells (drag to add).
-- Random: only your own list, whatever you drag onto it.
--
-- Buttons are secure "item" buttons. Which item each one holds is a secure
-- attribute, so the bar is rebuilt out of combat; counts and cooldowns keep
-- updating live in combat.
----------------------------------------------------------------------
local _, VB = ...

local IsSecret = VB.IsSecret
local SUB = Enum.ItemConsumableSubclass
local CLASS_CONSUMABLE = Enum.ItemClass and Enum.ItemClass.Consumable or 0
local MAX_BUTTONS = 12

local HEALTHSTONES = { [5512] = true, [224464] = true }

-- eat / drink go last: a bar holds 12 buttons, so with every job stocked it's plain food
-- that drops off, never a raid flask or rune.
local JOB_ORDER = { "buff", "healthstone", "health", "mana", "combat", "flask", "food", "feast", "recover", "oil", "rune", "vantus", "eat", "drink" }

-- Class GROUP buffs: cast before the pull / after a wipe, out of combat, so they sit with
-- the consumables (the player, 2026-10-27: "the druid has a buff... shouldn't it be on the
-- bar with consumables"). First known one wins; Shift+right-click hides it.
local GROUP_BUFFS = { "Mark of the Wild", "Arcane Intellect", "Power Word: Fortitude", "Battle Shout",
    "Blessing of the Bronze", "Skyfury" }

-- Out-of-combat recovery SPELLS that belong with food and potions rather than on a
-- combat key (the player, 2026-10-25: "Cannibalize ... warlocks can swap health for
-- mana"). Racials + class ones; each shows only if this character knows it, best first.
local RECOVER_SPELLS = { "Cannibalize", "Gift of the Naaru", "Regeneratin'", "Life Tap" }

-- Pets bar: a pet class's own pet buttons, apart from Blizzard's pet bar (which holds the
-- PET's abilities). The player, 2026-10-29: "for hunter it almost means it needs its own
-- pet bar". Hunter Call Pet 1-5 are spell ids by stable slot (each button shows its pet).
local CALL_PET = { 883, 83242, 83243, 83244, 83245 }
local PET_SPELLS = {
    HUNTER = { "Revive Pet", "Mend Pet", "Dismiss Pet" },
    WARLOCK = { "Summon Felguard", "Summon Imp", "Summon Voidwalker", "Summon Felhunter", "Summon Sayaad",
        "Fel Domination" },
    MAGE = { "Summon Water Elemental" },
}
local JOB_RANK = {}
for i, j in ipairs(JOB_ORDER) do JOB_RANK[j] = i end

VB.smartBars = {}

----------------------------------------------------------------------
-- Classification
----------------------------------------------------------------------
-- Lower-cased tooltip text, plus whether it was actually available (it can be
-- missing right after login; callers then retry instead of guessing).
-- English text matching -- fine for this (English-client, private) build.
local function UseText(itemID)
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or not data or not data.lines or #data.lines < 2 then return "", false end
    local parts = {}
    for _, line in ipairs(data.lines) do
        local t = line.leftText
        if t and not IsSecret(t) then parts[#parts + 1] = t end
    end
    return table.concat(parts, "\n"):lower(), true
end

local function CurrentExpansion()
    return LE_EXPANSION_LEVEL_CURRENT or (GetExpansionLevel and GetExpansionLevel()) or 0
end

-- Returns job, or nil when the item doesn't belong on the bar.
-- `pending` is true when item data isn't loaded yet (try again later).
local function Classify(itemID)
    if HEALTHSTONES[itemID] then return "healthstone" end
    local name, _, _, _, minLevel, _, _, _, _, _, _, classID, subID, _, expac = C_Item.GetItemInfo(itemID)
    if not name or expac == nil then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil, true
    end
    if classID ~= CLASS_CONSUMABLE then return nil end
    -- At max level only current-expansion items count (no old leveling food in
    -- M+). While leveling, anything usable at your level does; the best one
    -- wins by item level below.
    -- Mage food (Conjured Mana Bun) is an old item but the best free food at any level.
    local lname = name:lower()
    local conjured = subID == SUB.Fooddrink and lname:find("^conjured")
    local leveling = GetMaxLevelForPlayerExpansion and UnitLevel("player") < GetMaxLevelForPlayerExpansion()
    if not leveling and not conjured and expac < CurrentExpansion() then return nil end
    if minLevel and minLevel > UnitLevel("player") then return nil end
    if subID == SUB.Potion then
        local txt, ready = UseText(itemID)
        if not ready then return nil, true end
        if txt:find("restores? [%d,%.]+ health") or txt:find("heal") then return "health" end
        if txt:find("restores? [%d,%.]+ mana") then return "mana" end
        -- combat potions are identified positively (primary stat / damage);
        -- invisibility, water-breathing and other utility potions get no button
        if txt:find("strength") or txt:find("agility") or txt:find("intellect")
            or txt:find("primary stat") or txt:find("damage") then
            return "combat"
        end
        return nil
    elseif subID == SUB.Flasksphials then
        return "flask"
    elseif subID == SUB.Fooddrink then
        local txt, ready = UseText(itemID)
        if not ready then return nil, true end
        if lname:find("feast") or txt:find("set out") or txt:find("feast") then return "feast" end
        if txt:find("well fed") then return "food" end
        -- plain food / water (no buff): eat / drink slots, to recover between pulls.
        -- Food that restores both (Bobbing Apple) is also a drink candidate.
        local hp, mp = txt:find("restores.-health"), txt:find("restores.-mana")
        if hp then return "eat", nil, mp and "drink" or nil end
        if mp then return "drink" end
        return nil
    elseif subID == SUB.Itemenhancement then
        return "oil"
    elseif subID == SUB.VantusRune then
        return "vantus"
    elseif lname:find("augment rune") then
        return "rune"
    elseif subID == SUB.Other then
        -- Midnight files weapon oils/stones as consumable "Other" (e.g. Thalassian
        -- Phoenix Oil = class 0 / subclass 8), not "Item Enhancement".
        if lname:find(" oil$") or lname:find("whetstone") or lname:find("weightstone")
            or lname:find("sharpening") or UseText(itemID):find("your weapon") then
            return "oil"
        end
    end
    return nil
end

-- What a buff food's buff is worth to THIS character, so a fishing-skill fish doesn't win
-- over an attack-power one just by being the bigger stack (the user, 2026-11-06, WoW
-- Forever). 30 = your main stat (attack power / strength / agility for physical fighters,
-- intellect / spell power / healing for casters), 20 = secondary combat stats, 10 =
-- stamina / spirit / regen, 0 = anything else (fishing skill, swim speed, ...).
-- Your main stat: "str" / "agi" / "int", or nil when it can't be told (then all three
-- count). Strength and agility are kept apart (Codex review: a hunter's agility food
-- shouldn't tie with strength food).
local CLASS_STAT = { WARRIOR = "str", DEATHKNIGHT = "str", ROGUE = "agi", HUNTER = "agi",
    DEMONHUNTER = "agi", MAGE = "int", PRIEST = "int", WARLOCK = "int", EVOKER = "int" }
local STAT_IDS = { [1] = "str", [2] = "agi", [4] = "int" }
local function MainStat()
    -- retail: the spec's primary stat, through C_SpecializationInfo (the old globals can be
    -- turned off; Codex review)
    local SI = C_SpecializationInfo
    local getSpec = (SI and SI.GetSpecialization) or _G.GetSpecialization
    local getInfo = (SI and SI.GetSpecializationInfo) or _G.GetSpecializationInfo
    if getSpec and getInfo then
        local ok, spec = pcall(getSpec)
        if ok and type(spec) == "number" and spec > 0 then
            local ok2, _, _, _, _, _, primary = pcall(getInfo, spec)
            if ok2 and STAT_IDS[primary] then return STAT_IDS[primary] end
        end
    end
    local _, class = UnitClass("player")
    return CLASS_STAT[class]   -- nil for hybrids with no spec to go by (druid, paladin, shaman, monk)
end
local MAIN_WORDS = {
    str = { "strength", "attack power" },
    agi = { "agility", "attack power" },
    int = { "intellect", "spell power", "spell damage", "healing done", "healing and damage" },
}
local SECONDARY_WORDS = { "critical", "haste", "mastery", "versatility", "hit rating", "chance to hit", "expertise" }
local SURVIVAL_WORDS = { "stamina", "spirit", "mana every", "mana per", "health every", "armor" }
local function anyOf(txt, words)
    for _, w in ipairs(words) do if txt:find(w, 1, true) then return true end end
    return false
end
local function FoodScore(itemID)
    local txt = UseText(itemID)
    local stat = MainStat()
    if stat then
        if anyOf(txt, MAIN_WORDS[stat]) then return 30 end
    elseif anyOf(txt, MAIN_WORDS.str) or anyOf(txt, MAIN_WORDS.agi) or anyOf(txt, MAIN_WORDS.int) then
        return 30
    end
    if anyOf(txt, SECONDARY_WORDS) then return 20 end
    if anyOf(txt, SURVIVAL_WORDS) then return 10 end
    return 0
end

local function Quality(itemID)
    local fn = C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo
    local ok, q = pcall(fn or function() end, itemID)
    return (ok and q) or 0
end

-- Is this job wanted where the player is right now?
local function JobWanted(job)
    -- eat / drink at max level too: buff food is for the pull, not for topping off between
    -- packs (the player, 2026-10-30: "i am not going to constantly use harandar celebration to heal")
    if job == "mana" or job == "drink" then   -- only for characters with a mana pool
        return (UnitPowerMax("player", Enum.PowerType.Mana) or 0) > 0
    end
    if job == "vantus" then
        local inInst, instType = IsInInstance()
        return inInst and instType == "raid"
    end
    return true
end

-- Best item per job from the bags.
function VB:CollectConsumables()
    local hidden = VoidBarsCharDB.hiddenItems or {}
    local best, pending = {}, false
    local seen = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] and not hidden[id] then
                seen[id] = true
                local job1, wait, job2 = Classify(id)   -- job2: food that also restores mana
                if wait then pending = true end
                for _, job in ipairs({ job1 or false, job2 or false }) do
                if job and JobWanted(job) then
                    local cand = {
                        kind = "item", id = id, job = job,
                        q = Quality(id),
                        ilvl = select(4, C_Item.GetItemInfo(id)) or 0,
                        fleeting = (C_Item.GetItemNameByID(id) or ""):lower():find("fleeting") and 1 or 0,
                        count = C_Item.GetItemCount(id, false, true) or 0,
                        -- buff food: what the buff is worth to you comes first
                        score = (job == "food") and FoodScore(id) or 0,
                    }
                    local cur = best[job]
                    -- better = the more useful buff (buff food), then higher item level
                    -- (newer/stronger, matters while leveling), then crafted quality,
                    -- then free cauldron flask, then stack
                    local better
                    if not cur then better = true
                    elseif cand.score ~= cur.score then better = cand.score > cur.score
                    elseif cand.ilvl ~= cur.ilvl then better = cand.ilvl > cur.ilvl
                    elseif cand.q ~= cur.q then better = cand.q > cur.q
                    elseif cand.fleeting ~= cur.fleeting then better = cand.fleeting > cur.fleeting
                    else better = cand.count > cur.count end
                    if better then best[job] = cand end
                end
                end
            end
        end
    end
    -- one food that does both (Bobbing Apple) gets one button, not eat + drink
    if best.drink and best.eat and best.drink.id == best.eat.id then best.drink = nil end
    -- recovery spell: the first one this character knows (Shift+right-click hides it)
    for _, name in ipairs(RECOVER_SPELLS) do
        local info = C_Spell.GetSpellInfo(name)
        local sid = info and info.spellID
        if sid and not hidden["s" .. sid] and C_SpellBook.IsSpellKnownOrInSpellBook(sid) then
            best.recover = { kind = "spell", id = sid, job = "recover" }
            break
        end
    end
    -- group buff: the one this class has (Mark of the Wild, Arcane Intellect, ...)
    for _, name in ipairs(GROUP_BUFFS) do
        local info = C_Spell.GetSpellInfo(name)
        local sid = info and info.spellID
        if sid and not hidden["s" .. sid] and C_SpellBook.IsSpellKnownOrInSpellBook(sid) then
            best.buff = { kind = "spell", id = sid, job = "buff" }
            break
        end
    end
    local list = {}
    for _, job in ipairs(JOB_ORDER) do
        if best[job] then list[#list + 1] = best[job] end
    end
    return list, pending
end

-- Pets: hunter Call Pet for each stable slot holding a pet (Call Pet 1 alone when the
-- stable list isn't known), then the class's other pet buttons you know. Shift+right-click
-- hides one, like a consumable.
function VB:CollectPets()
    local _, class = UnitClass("player")
    local hidden = VoidBarsCharDB.hiddenItems or {}
    local list = {}
    local function add(sid)
        if sid and not hidden["s" .. sid] and C_SpellBook.IsSpellKnownOrInSpellBook(sid) then
            list[#list + 1] = { kind = "spell", id = sid, job = "pet" }
        end
    end
    if class == "HUNTER" then
        local pets = C_StableInfo and C_StableInfo.GetActivePetList and C_StableInfo.GetActivePetList()
        local slotted = {}
        for _, p in ipairs(pets or {}) do slotted[p.slotID] = true end
        if not next(slotted) then slotted[1] = true end
        for slot, sid in ipairs(CALL_PET) do
            if slotted[slot] then add(sid) end
        end
    end
    for _, name in ipairs(PET_SPELLS[class] or {}) do
        local info = C_Spell.GetSpellInfo(name)
        add(info and info.spellID)
    end
    return list, false
end

----------------------------------------------------------------------
-- Travel: hearthstone, class teleport, Teleport Home (housing), Switch
-- Flight Style, random mount, then YOUR list (mounts / toys / items /
-- spells). Drag a mount, toy, item or spell onto the bar to add it;
-- shift+right-click removes. Hidden in dungeons and raids by default.
----------------------------------------------------------------------
local HEARTHSTONE = 6948
local SWITCH_FLIGHT_STYLE = 460002
local RANDOM_FAVORITE_MOUNT = 150544
local CLASS_TRAVEL = {
    50977,    -- Death Gate (DK)
    193753,   -- Dreamwalk (druid)
    126892,   -- Zen Pilgrimage (monk)
    556,      -- Astral Recall (shaman)
}

VB.house = nil   -- first owned house (from PLAYER_HOUSE_LIST_UPDATED)

-- Identity for hiding / dedup: a swap-back entry (normal helm shown while the
-- fishing hat is worn) keeps the PROFESSION item's identity.
local function EntryKey(e) return e.kind .. ":" .. tostring(e.swapFor or e.id) end

-- Known by this character, including general/account spells like Switch Flight
-- Style that IsPlayerSpell() alone does not report.
local function Known(spellID)
    local sb = C_SpellBook
    -- IsPlayerSpell only exists with Blizzard's deprecation fallbacks on
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if sb and sb.IsSpellKnown and sb.IsSpellKnown(spellID) then return true end
    return sb and sb.IsSpellKnownOrInSpellBook and sb.IsSpellKnownOrInSpellBook(spellID) or false
end

-- The smart bars' lists, hidden buttons and first-run seeding are PER CHARACTER
-- (VoidBarsCharDB). Up to 1.0.3 they were account-wide (VoidBarsDB), so a mount
-- dragged on as one character showed on all of them (the player, 2026-11-02).
local MOVED = { "lists", "hiddenBy", "hiddenItems", "travelSeeded", "professionsSeeded" }

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = DeepCopy(v) end
    return o
end

-- ADDON_LOADED: a character that already used VoidBars keeps what it saw (a copy of
-- the old shared lists, now its own); a new character starts fresh and seeds from
-- its own bars. The shared copy stays for characters not logged in since.
function VB:MigrateSmartLists()
    local char, acct = VoidBarsCharDB, VoidBarsDB
    if char.smartPerChar then return end
    if acct.travelList then   -- 0.3 data
        acct.lists = acct.lists or {}
        acct.lists.travel = acct.lists.travel or acct.travelList
        acct.travelList = nil
    end
    if acct.hiddenTravel then   -- 0.3 data
        acct.hiddenBy = acct.hiddenBy or {}
        acct.hiddenBy.travel = acct.hiddenTravel
        acct.hiddenTravel = nil
    end
    if char.imported or char.bars then   -- used VoidBars before this version
        for _, k in ipairs(MOVED) do
            if char[k] == nil then char[k] = DeepCopy(acct[k]) end
        end
    end
    char.smartPerChar = true
end

-- The player's own list for a bar (travel, professions, random), per character.
local function CuratedList(barKey)
    VoidBarsCharDB.lists = VoidBarsCharDB.lists or {}
    VoidBarsCharDB.lists[barKey] = VoidBarsCharDB.lists[barKey] or {}
    return VoidBarsCharDB.lists[barKey]
end
VB.CuratedList = CuratedList

-- Automatic entries the player right-clicked away, per bar.
local function HiddenSet(barKey)
    VoidBarsCharDB.hiddenBy = VoidBarsCharDB.hiddenBy or {}
    VoidBarsCharDB.hiddenBy[barKey] = VoidBarsCharDB.hiddenBy[barKey] or {}
    return VoidBarsCharDB.hiddenBy[barKey]
end
VB.HiddenSet = HiddenSet

-- Is a saved entry still usable by this character?
local function Owned(e)
    if e.kind == "mount" then
        local name, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(e.id)
        return name and collected
    elseif e.kind == "toy" then
        return PlayerHasToy(e.id)
    elseif e.kind == "spell" then
        return Known(e.id)
    elseif e.kind == "item" then
        return (C_Item.GetItemCount(e.id) or 0) > 0 or C_Item.IsEquippedItem(e.id)
    elseif e.kind == "macro" then
        return (GetMacroIndexByName(e.id) or 0) > 0   -- deleted or renamed -> drops off
    end
    return true
end

-- Builder shared by curated bars: auto entries (hideable) + the player's list.
local function NewCollector(barKey)
    local hidden = HiddenSet(barKey)
    local list, seen = {}, {}
    local function add(e, curated)
        local k = EntryKey(e)
        -- hidden applies to your own copies too (dragging an item back clears it)
        if seen[k] or hidden[k] then return end
        seen[k] = true
        e.curated = curated
        list[#list + 1] = e
    end
    local function addCurated()
        for _, e in ipairs(CuratedList(barKey)) do
            if Owned(e) then
                local entry = { kind = e.kind, id = e.id }
                -- a worn profession item (fishing rod) shows its swap-back piece
                if barKey == "professions" and e.kind == "item" and C_Item.IsEquippedItem(e.id) then
                    entry = VB.ProfessionSwap(e.id)
                end
                add(entry, entry.swapFor == nil)
            end
        end
    end
    return list, add, addCurated
end

local function HiddenInInstance(barKey)
    local inInst, instType = IsInInstance()
    -- shown by default (2026-10-25, the user: "i dont want them hidden"); only an
    -- explicit false from the option hides the bar in dungeons / raids
    return inInst and (instType == "party" or instType == "raid") and VB:BarConfig(barKey).inInstances == false
end

-- Profile slots in action-bar order (for seeding lists).
local function ProfileEntries()
    local p = VB.Profiles and VB:Profiles().Default
    if not p then return nil end
    local slots = {}
    for slot in pairs(p.actions) do slots[#slots + 1] = slot end
    table.sort(slots)
    local out = {}
    for _, slot in ipairs(slots) do out[#out + 1] = p.actions[slot] end
    return out
end

-- `pick(a)` returns an entry, or nil, true when the item's data isn't loaded
-- yet -- then the seed stays open and runs again on the next rebuild.
local function SeedList(barKey, flag, pick)
    if VoidBarsCharDB[flag] then return end
    local entries = ProfileEntries()
    if not entries then return end
    local list, have, waiting = CuratedList(barKey), {}, false
    for _, e in ipairs(list) do have[EntryKey(e)] = true end
    for _, a in ipairs(entries) do
        local e, notReady = pick(a)
        if notReady then waiting = true end
        if e and not have[EntryKey(e)] then
            have[EntryKey(e)] = true
            list[#list + 1] = e
        end
    end
    if not waiting then VoidBarsCharDB[flag] = true end
    return waiting
end

----------------------------------------------------------------------
-- Travel
----------------------------------------------------------------------
-- First run: start the list with the mounts and teleport toys already on the
-- player's bars (their "Default" profile), so the bar isn't empty.
function VB:SeedTravelList()
    return SeedList("travel", "travelSeeded", function(a)
        if a.t == "summonmount" and a.id and a.id ~= 268435455 then
            return { kind = "mount", id = a.id }
        elseif a.t == "item" and a.toy then
            local txt, ready = UseText(a.id)
            if not ready then return nil, true end
            if txt:find("teleport") or txt:find("return") then return { kind = "toy", id = a.id } end
        end
    end)
end

function VB:CollectTravel()
    if HiddenInInstance("travel") then return {}, false end
    local list, add, addCurated = NewCollector("travel")
    if (C_Item.GetItemCount(HEARTHSTONE) or 0) > 0 then add({ kind = "item", id = HEARTHSTONE }) end
    for _, sid in ipairs(CLASS_TRAVEL) do
        if Known(sid) then add({ kind = "spell", id = sid }) end
    end
    if self.house then add({ kind = "house", id = "home" }) end
    if Known(SWITCH_FLIGHT_STYLE) then add({ kind = "spell", id = SWITCH_FLIGHT_STYLE }) end
    add({ kind = "spell", id = RANDOM_FAVORITE_MOUNT })
    addCurated()
    return list, false
end

----------------------------------------------------------------------
-- Professions: every active ability of each profession you have (craft
-- window, Disenchant, Cooking Fire, Fishing, ...), your profession gear in
-- your bags (rods, hats, tools), then your own list.
----------------------------------------------------------------------
local PROFESSION_WORDS = {
    "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "inscription",
    "jewelcrafting", "leatherworking", "mining", "skinning", "tailoring",
    "cooking", "fishing", "archaeology",
}
local CLASS_PROFESSION = Enum.ItemClass and Enum.ItemClass.Profession or 19

-- Profession-related by its tooltip: "Requires Fishing", or gear that boosts a
-- profession ("Equip: +11 Midnight Fishing Skill" -- the fishing hat is plain
-- armor, class 4). Returns true/false, plus "not loaded yet" so callers can wait.
local profCache = {}
local function RequiresProfession(itemID)
    if profCache[itemID] ~= nil then return profCache[itemID] end
    local txt, ready = UseText(itemID)
    if not ready then return false, true end
    local hit = false
    for _, w in ipairs(PROFESSION_WORDS) do
        if txt:find("requires " .. w) or txt:find(w .. " skill") then hit = true break end
    end
    profCache[itemID] = hit
    return hit
end

-- First run: the profession items already on the player's bars (rod, hat,
-- repair hammer, engineering gear, ...). Profession SPELLS are automatic.
function VB:SeedProfessionList()
    return SeedList("professions", "professionsSeeded", function(a)
        if a.t == "item" and not a.toy and a.id then
            local name, _, _, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(a.id)
            if not name then C_Item.RequestLoadItemDataByID(a.id) return nil, true end
            if classID == CLASS_PROFESSION then return { kind = "item", id = a.id } end
            local needs, notReady = RequiresProfession(a.id)
            if notReady then return nil, true end
            if needs then return { kind = "item", id = a.id } end
        end
    end)
end

----------------------------------------------------------------------
-- Profession gear swap (fishing hat, fishing rod, ...): while you WEAR the
-- profession piece, its button shows and equips the normal item you had in
-- that slot, so one button switches back and forth. The normal piece per
-- slot is remembered whenever non-profession gear is equipped there.
----------------------------------------------------------------------
function VB.IsProfessionGear(id)
    local name, _, _, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(id)
    if not name then C_Item.RequestLoadItemDataByID(id) return false, true end
    if classID == CLASS_PROFESSION then return true end
    if classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon then
        return RequiresProfession(id)
    end
    return false
end

local function SlotOfEquipped(id)
    for slot = 1, 19 do
        if GetInventoryItemID("player", slot) == id then return slot end
    end
end

-- Entry for a profession item: itself, or -- while it's worn -- the remembered
-- normal piece for that slot (if it's in your bags).
-- Nothing remembered yet (e.g. already wearing the hat when this was added):
-- the highest item-level non-profession piece in the bags with the same
-- equip type (head for a hat, two-hander for a fishing pole).
local function BestBagPieceLike(id)
    local invType = C_Item.GetItemInventoryTypeByID(id)
    if not invType then return nil end
    local best, bestLvl
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local cand = info and info.itemID
            if cand and cand ~= id and C_Item.GetItemInventoryTypeByID(cand) == invType then
                local isGear, notReady = VB.IsProfessionGear(cand)
                if not isGear and not notReady then
                    local lvl = C_Item.GetDetailedItemLevelInfo(info.hyperlink or cand) or 0
                    if not bestLvl or lvl > bestLvl then best, bestLvl = cand, lvl end
                end
            end
        end
    end
    return best
end

function VB.ProfessionSwap(id)
    local slot = SlotOfEquipped(id)
    local main = slot and VoidBarsCharDB.mainGear and VoidBarsCharDB.mainGear[slot]
    if not (main and (C_Item.GetItemCount(main) or 0) > 0) then main = BestBagPieceLike(id) end
    if main and main ~= id and (C_Item.GetItemCount(main) or 0) > 0 then
        return { kind = "item", id = main, swapFor = id }
    end
    return { kind = "item", id = id }
end

local function RememberMainGear(slot, tries)
    local id = GetInventoryItemID("player", slot)
    if not id then return end
    local isGear, notReady = VB.IsProfessionGear(id)
    if notReady then
        -- item data not loaded yet: check again shortly if it's still the same item
        if (tries or 0) < 5 then
            C_Timer.After(1, function()
                if GetInventoryItemID("player", slot) == id then RememberMainGear(slot, (tries or 0) + 1) end
            end)
        end
    elseif not isGear then
        VoidBarsCharDB.mainGear = VoidBarsCharDB.mainGear or {}
        VoidBarsCharDB.mainGear[slot] = id
    end
end

local gearEv = CreateFrame("Frame")
gearEv:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
gearEv:RegisterEvent("PLAYER_ENTERING_WORLD")
gearEv:SetScript("OnEvent", function(_, event, slot)
    if not VoidBarsCharDB then return end
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot then
        RememberMainGear(slot)
        if VB.RebuildSmartBars then
            VB:RunOutOfCombat("smartrebuild", function() VB:RebuildSmartBars() end)
        end
    else
        for s = 1, 19 do RememberMainGear(s) end
    end
end)

function VB:CollectProfessions()
    if HiddenInInstance("professions") then return {}, false end
    local list, add, addCurated = NewCollector("professions")
    local bank = Enum.SpellBookSpellBank.Player
    -- GetProfessions() returns prof1, prof2, archaeology, fishing, cooking with
    -- nils for the ones you don't have: ipairs over that stopped at the first
    -- gap (no archaeology -> Fishing and Cooking were skipped). Walk all five.
    local p = { GetProfessions() }
    for n = 1, 5 do
        local idx = p[n]
        if idx then
            local _, _, _, _, numSpells, offset = GetProfessionInfo(idx)
            for i = 1, (numSpells or 0) do
                local info = C_SpellBook.GetSpellBookItemInfo(offset + i, bank)
                if info and info.spellID and not info.isPassive then
                    add({ kind = "spell", id = info.spellID })
                end
            end
        end
    end
    -- profession gear you're WEARING: offer the swap back to your normal piece
    local pending = false
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then
            local isGear, notReady = VB.IsProfessionGear(id)
            if notReady then pending = true
            elseif isGear then add(VB.ProfessionSwap(id)) end
        end
    end
    -- profession gear sitting in the bags
    local seen = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] then
                seen[id] = true
                local isGear, notReady = VB.IsProfessionGear(id)   -- e.g. fishing hat
                if notReady then
                    pending = true   -- not loaded yet: the rebuild retries shortly
                elseif isGear then
                    add({ kind = "item", id = id })
                end
            end
        end
    end
    addCurated()
    return list, pending
end

-- Add whatever is on the cursor to a curated bar's list.
function VB:AddCursorTo(barKey, label)
    local cType, i1, i2, i3 = GetCursorInfo()
    local e
    if cType == "mount" then
        for _, cand in ipairs({ i1, i2 }) do
            if type(cand) == "number" and C_MountJournal.GetMountInfoByID(cand) then e = { kind = "mount", id = cand } break end
        end
    elseif cType == "item" then
        e = { kind = (PlayerHasToy(i1) and "toy" or "item"), id = i1 }
    elseif cType == "spell" then
        e = { kind = "spell", id = i3 }
    elseif cType == "macro" then
        -- saved by name: macro indexes shift when you add or delete macros
        local name = GetMacroInfo(i1)
        if name and GetMacroIndexByName(name) ~= i1 then
            -- two macros with this name: the name would run the other one
            ClearCursor()
            self:Print(("two of your macros are named \"%s\". Rename one, then drag it on again."):format(name))
            return
        end
        e = { kind = "macro", id = name }
    end
    ClearCursor()
    if not e or not e.id then
        self:Print(("the %s bar takes mounts, toys, items, spells and macros."):format(label or barKey))
        return
    end
    local key = EntryKey(e)
    -- An automatic entry (e.g. the Hearthstone) is never copied into your list:
    -- if it was hidden, dragging it back just un-hides it; if it's showing, nothing to do.
    local hidden = HiddenSet(barKey)
    if hidden[key] then
        hidden[key] = nil
        self:RebuildSmartBars()
        return
    end
    local bar = self.bars[barKey]
    for _, b in ipairs(bar and bar.buttons or {}) do
        if b.entry and EntryKey(b.entry) == key then return end   -- already on the bar
    end
    local list = CuratedList(barKey)
    for _, x in ipairs(list) do
        if EntryKey(x) == key then return end
    end
    list[#list + 1] = e
    self:RebuildSmartBars()
end


-- Random: nothing automatic, only what you drag onto it (the user, 2026-10-30: "a bar
-- called random for people to put whatever in").
function VB:CollectRandom()
    local list, _, addCurated = NewCollector("random")
    addCurated()
    return list, false
end

local houseEv = CreateFrame("Frame")
houseEv:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
houseEv:RegisterEvent("PLAYER_ENTERING_WORLD")
houseEv:SetScript("OnEvent", function(_, event, houses)
    if event == "PLAYER_ENTERING_WORLD" then
        if C_Housing and C_Housing.GetPlayerOwnedHouses then pcall(C_Housing.GetPlayerOwnedHouses) end
        return
    end
    local h = houses and houses[1]
    VB.house = (h and h.neighborhoodGUID and h.houseGUID and h.plotID) and h or nil
    -- always rebuild: a moved/replaced house changes the secure destination even
    -- when "has a house" stays true (RebuildSmartBars waits for combat to end)
    if VB.RebuildSmartBars then VB:RebuildSmartBars() end
end)

----------------------------------------------------------------------
-- Buttons (one engine for every kind of entry)
----------------------------------------------------------------------
local Smart = {}
local HOUSE_ICON = "Interface\\Icons\\INV_Misc_Rune_01"

local function SetCD(cd, start, duration, enable)
    if IsSecret(start) or IsSecret(duration) then
        pcall(cd.SetCooldown, cd, start, duration)
    elseif enable and enable ~= 0 and enable ~= false and duration and duration > 0 then
        cd:SetCooldown(start, duration)
    else
        cd:Clear()
    end
end

local function Tint(self, usable, noMana)
    if not IsSecret(usable) and usable == false then
        self.icon:SetVertexColor((noMana and VB.COLOR.noResource or VB.COLOR.unusable):GetRGB())
    else
        self.icon:SetVertexColor(1, 1, 1)
    end
end

function Smart:UpdateVisual()
    local e = self.entry
    if not e then return end
    self.Count:SetText("")
    self.vbPlus:SetShown(e.kind == "drop")
    if e.kind == "drop" then
        self.icon:SetTexture(nil)
        self.cooldown:Clear()
    elseif e.kind == "item" then
        self.icon:SetTexture(C_Item.GetItemIconByID(e.id))
        local count = C_Item.GetItemCount(e.id, false, true) or 0
        self.Count:SetText(count > 1 and count or "")
        if count == 0 then self.icon:SetVertexColor(VB.COLOR.unusable:GetRGB())
        else Tint(self, C_Item.IsUsableItem(e.id)) end
        SetCD(self.cooldown, C_Container.GetItemCooldown(e.id))
    elseif e.kind == "toy" then
        local _, _, icon = C_ToyBox.GetToyInfo(e.id)
        self.icon:SetTexture(icon or C_Item.GetItemIconByID(e.id))
        self.icon:SetVertexColor(1, 1, 1)
        SetCD(self.cooldown, C_Container.GetItemCooldown(e.id))
    elseif e.kind == "spell" or e.kind == "mount" then
        local sid = e.kind == "mount" and select(2, C_MountJournal.GetMountInfoByID(e.id)) or e.id
        if e.kind == "mount" then
            local _, _, icon, _, usable = C_MountJournal.GetMountInfoByID(e.id)
            self.icon:SetTexture(icon)
            Tint(self, usable)
        else
            self.icon:SetTexture(C_Spell.GetSpellTexture(sid))
            Tint(self, C_Spell.IsSpellUsable(sid))
        end
        local ok, d = pcall(C_Spell.GetSpellCooldownDuration, sid)
        if ok and d then self.cooldown:SetCooldownFromDurationObject(d) else self.cooldown:Clear() end
    elseif e.kind == "macro" then
        local idx = GetMacroIndexByName(e.id) or 0
        local _, icon = GetMacroInfo(e.id)
        self.icon:SetTexture(icon)
        -- #showtooltip macros: cooldown and usable tint of the spell / item they'd cast now
        local sid = idx > 0 and GetMacroSpell(idx)
        local link = idx > 0 and select(2, GetMacroItem(idx))
        local itemID = link and not IsSecret(link) and C_Item.GetItemInfoInstant(link)
        if sid and not IsSecret(sid) then
            Tint(self, C_Spell.IsSpellUsable(sid))
            local ok, d = pcall(C_Spell.GetSpellCooldownDuration, sid)
            if ok and d then self.cooldown:SetCooldownFromDurationObject(d) else self.cooldown:Clear() end
        elseif itemID then
            Tint(self, C_Item.IsUsableItem(itemID))
            SetCD(self.cooldown, C_Container.GetItemCooldown(itemID))
        else
            self.icon:SetVertexColor(1, 1, 1)
            self.cooldown:Clear()
        end
    elseif e.kind == "house" then
        self.icon:SetTexture(HOUSE_ICON)
        self.icon:SetVertexColor(1, 1, 1)
        self.cooldown:Clear()
    end
end

-- Secure attributes for an entry (out of combat only).
function Smart:Assign(e)
    self.entry = e
    for _, a in ipairs({ "item", "toy", "spell", "macro", "macrotext", "house-neighborhood-guid", "house-guid", "house-plot-id" }) do
        self:SetAttribute(a, nil)
    end
    if not e or e.kind == "drop" then   -- the "+" square uses nothing
        self:SetAttribute("type", nil)
        if e then self:UpdateVisual() end
        return
    end
    -- Mounts are summoned through the Mount Journal by mount ID (as Blizzard's
    -- journal does). Casting the mount's spell ID did nothing: mounts aren't
    -- spellbook spells. 0 = random favorite.
    local mountID = (e.kind == "mount" and e.id) or (e.kind == "spell" and e.id == RANDOM_FAVORITE_MOUNT and 0)
    if mountID then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", ("/run C_MountJournal.SummonByID(%d)"):format(mountID))
    elseif e.kind == "item" then
        self:SetAttribute("type", "item")
        self:SetAttribute("item", "item:" .. e.id)
    elseif e.kind == "toy" then
        self:SetAttribute("type", "toy")
        self:SetAttribute("toy", e.id)
    elseif e.kind == "spell" then
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", e.id)
    elseif e.kind == "macro" then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macro", e.id)   -- RunMacro takes the name
    elseif e.kind == "house" and VB.house then
        self:SetAttribute("type", "teleporthome")
        self:SetAttribute("house-neighborhood-guid", VB.house.neighborhoodGUID)
        self:SetAttribute("house-guid", VB.house.houseGUID)
        self:SetAttribute("house-plot-id", VB.house.plotID)
    end
    self:UpdateVisual()
end

local function ShowTooltip(self)
    local e = self.entry
    if not e then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if e.kind == "drop" then
        GameTooltip:SetText(("Add to the %s bar"):format(self:GetParent().def.label:lower()))
        GameTooltip:AddLine("Drag a mount, toy, item, spell or macro here", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    if e.kind == "macro" then
        local idx = GetMacroIndexByName(e.id) or 0
        local sid = idx > 0 and GetMacroSpell(idx)
        local link = idx > 0 and select(2, GetMacroItem(idx))
        if sid and not IsSecret(sid) then GameTooltip:SetSpellByID(sid)
        elseif link and not IsSecret(link) then GameTooltip:SetHyperlink(link)
        else GameTooltip:SetText(e.id) end
        GameTooltip:AddLine("Macro: " .. e.id, 0.6, 0.6, 0.6)
    elseif e.kind == "item" then GameTooltip:SetItemByID(e.id)
    elseif e.kind == "toy" then GameTooltip:SetToyByItemID(e.id)
    elseif e.kind == "spell" then GameTooltip:SetSpellByID(e.id)
    elseif e.kind == "mount" then
        local _, sid = C_MountJournal.GetMountInfoByID(e.id)   -- one value: the extra returns would land in checkIndoors
        if sid then GameTooltip:SetMountBySpellID(sid) end
    elseif e.kind == "house" then GameTooltip:SetText("Teleport Home")
    end
    local bar = self:GetParent()
    if e.swapFor then
        GameTooltip:AddLine(("Click: put this back on (you're wearing %s)"):format(
            C_Item.GetItemNameByID(e.swapFor) or "your profession gear"), 0.4, 1, 0.4, true)
    end
    if bar.def.curated then
        GameTooltip:AddLine(e.curated and ("Shift+Right-click: remove from the " .. bar.def.label:lower() .. " bar")
            or "Shift+Right-click: hide", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Drag a mount, toy, item, spell or macro here to add it", 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine("Shift+Right-click: hide this item from the bar", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- Shift+right-click: consumables -> hide the item; curated bars (travel, professions)
-- -> remove it from your list, or hide an automatic entry.
local function RightClick(self, bar)
    local e = self.entry
    if bar.def.curated then
        local key = EntryKey(e)
        if e.curated then
            local list = CuratedList(bar.def.key)
            for i, x in ipairs(list) do
                if EntryKey(x) == key then table.remove(list, i) break end
            end
        else
            HiddenSet(bar.def.key)[key] = true
        end
    else
        VoidBarsCharDB.hiddenItems = VoidBarsCharDB.hiddenItems or {}
        -- recovery spells use an "s<id>" key so a spell and an item with the same ID can't collide
        local spell = e.kind == "spell"
        VoidBarsCharDB.hiddenItems[spell and ("s" .. e.id) or e.id] = true
        VB:Print(("hid %s from the %s bar (Options -> VoidBars to bring hidden items back)."):format(
            (spell and C_Spell.GetSpellName(e.id)) or C_Item.GetItemNameByID(e.id) or "that item", bar.def.label))
    end
    VB:RebuildSmartBars()
end

local function CreateSmartButton(bar, i)
    local b = CreateFrame("CheckButton", "VoidBars" .. bar.def.key .. "Button" .. i, bar,
        "ActionButtonTemplate, SecureActionButtonTemplate")
    VB.Button.Style(b)
    b.ApplySize = VB.Button.ApplySize
    Mixin(b, Smart)
    b:RegisterForClicks("AnyDown", "AnyUp")
    -- Right-click USES the item like left-click (as in your bags: players right-clicked
    -- food to eat it and it vanished from the bar, 2026-10-25). Shift+right-click is the
    -- remove/hide, and never uses or casts.
    b:SetAttribute("shift-type2", "vbnoop")
    b.HotKey:SetText("")
    b:HookScript("PostClick", function(self, button, down)
        self:SetChecked(false)
        -- release only: the button fires on press AND release, and the bar
        -- rebuilds in between -- reacting to both would act twice
        if down or not self.entry or InCombatLockdown() then return end
        if self.entry.kind == "drop" then
            -- clicking the "+" while holding something adds it, like dropping it
            if GetCursorInfo() then VB:AddCursorTo(bar.def.key, bar.def.label:lower()) end
        elseif button == "RightButton" and IsShiftKeyDown() then
            RightClick(self, bar)
        end
    end)
    b:HookScript("OnEnter", ShowTooltip)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    if bar.def.curated then
        b:SetScript("OnReceiveDrag", function()
            if not InCombatLockdown() then VB:AddCursorTo(bar.def.key, bar.def.label:lower()) end
        end)
    end
    return b
end

----------------------------------------------------------------------
-- Bars
----------------------------------------------------------------------
local SMART_DEFS = {
    -- side: which side of the combat block the bar lives on (the Naga preset's spots);
    -- cfg.side overrides it once the bar is dragged in move mode
    { key = "consumables", label = "Consumables", kind = "smart", collect = "CollectConsumables", y = 305, side = "left" },
    { key = "travel",      label = "Travel",      kind = "smart", collect = "CollectTravel",      y = 350, curated = true, side = "right" },
    { key = "professions", label = "Professions", kind = "smart", collect = "CollectProfessions", y = 395, curated = true, side = "left" },
    -- near: a bar's first spot, when it arrives after the layout was set, is next to that bar
    { key = "pets",        label = "Pets",        kind = "smart", collect = "CollectPets",        y = 305, side = "right",
      near = { key = "travel", above = true } },
    { key = "random",      label = "Random",      kind = "smart", collect = "CollectRandom",      y = 305, curated = true, side = "right",
      near = { key = "travel" } },
}

function VB:CreateSmartBars()
    for _, def in ipairs(SMART_DEFS) do
        local bar = CreateFrame("Frame", "VoidBars_" .. def.key, UIParent, "SecureHandlerStateTemplate")
        bar.def = def
        bar.buttons = {}
        bar:SetSize(1, 1)
        bar:SetMovable(true)
        bar:SetClampedToScreen(true)
        bar:Hide()
        for i = 1, MAX_BUTTONS do
            bar.buttons[i] = CreateSmartButton(bar, i)
            bar.buttons[i]:Hide()
        end
        local cfg = self:BarConfig(def.key)
        if cfg.enabled == nil then cfg.enabled = true end
        self.bars[#self.bars + 1] = bar
        self.bars[def.key] = bar
        self.smartBars[#self.smartBars + 1] = bar
    end
end

-- Is this smart bar on the left half of the screen? Such a bar keeps its RIGHT edge
-- fixed and grows leftward (toward the screen edge, away from the center bars).
-- The side is stored, not read off the position: a layout pass that ran before the
-- combat block had its size once snapped Travel onto the block, after which its
-- position said "left" and it jumped sides (2026-10-25).
function VB:SmartBarOnLeft(bar)
    local cfg = self:BarConfig(bar.def.key)
    local side = cfg.side or bar.def.side
    if side then return side == "left" end
    local w = bar:GetWidth() or 1
    return cfg.x ~= nil and (cfg.x + w / 2) < UIParent:GetWidth() / 2
end

-- Lay out the visible buttons in a grid; size/columns/spacing per bar.
-- Everything lines up on the middle and stretches outward (the user, 2026-10-25): a
-- smart bar in the lower part of the screen puts its INNER edge GROUP_GAP from the
-- combat block (bar1 + bar2) -- right edge for a bar left of center, left edge for a
-- bar right of center -- so side bars stay even however many buttons they hold.
function VB:SnapToBlock(bar, cfg, onLeft)
    if not (cfg.x and cfg.y) or cfg.y > UIParent:GetHeight() * 0.45 then return end
    local x0, x1
    for _, key in ipairs({ "bar1", "bar2" }) do
        local b, c = self.bars[key], self:BarConfig(key)
        -- width 1 = not laid out yet: no block to line up on this pass
        if b and c.enabled and c.x and (b:GetWidth() or 0) > 1 then
            x0 = math.min(x0 or c.x, c.x)
            x1 = math.max(x1 or 0, c.x + (b:GetWidth() or 0))
        end
    end
    if not x0 then return end
    local gap = self.GROUP_GAP or 14
    cfg.x = onLeft and (x0 - gap - bar:GetWidth()) or (x1 + gap)
end

-- A smart bar never sits on top of one of the 8 action bars in the same rows: push it
-- outward (left-half bars to the left, others to the right), i.e. middle out.
function VB:NudgeOffBars(bar, cfg, onLeft)
    if not (cfg.x and cfg.y) then return end
    local w, h = bar:GetWidth(), bar:GetHeight()
    local gap = VB.GROUP_GAP or 14   -- same space the Naga preset leaves between groups
    for _, other in ipairs(self.bars) do
        -- regular action bars only: pet / stance / marker bars come and go (pet out,
        -- stealth), which would make this bar jump
        if other ~= bar and not other.def.kind then
            local oc = self:BarConfig(other.def.key)
            local ow, oh = other:GetWidth() or 0, other:GetHeight() or 0
            if oc.enabled and oc.x and oc.y and ow > 1 then   -- 1 = not laid out yet
                -- y is each bar's TOP edge (TOPLEFT anchors)
                local rowsOverlap = cfg.y - h < oc.y and oc.y - oh < cfg.y
                -- closer than the gap counts as overlapping
                local colsOverlap = cfg.x < oc.x + ow + gap and oc.x - gap < cfg.x + w
                if rowsOverlap and colsOverlap then
                    cfg.x = onLeft and (oc.x - gap - w) or (oc.x + ow + gap)
                end
            end
        end
    end
end

function VB:LayoutSmartBar(bar)
    local cfg = self:BarConfig(bar.def.key)
    local size = cfg.size or 36
    local cols = math.max(1, cfg.cols or 12)
    local spacing = cfg.spacing or 3
    local shown = bar.shownCount or 0
    for i, b in ipairs(bar.buttons) do
        b:ApplySize(size)
        b:ClearAllPoints()
        if i <= shown then
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (size + spacing), -row * (size + spacing))
            b:Show()
        else
            b:Hide()
        end
    end
    local usedCols = math.min(cols, math.max(shown, 1))
    local rows = math.max(1, math.ceil(shown / cols))
    local onLeft = self:SmartBarOnLeft(bar)
    -- Width at the last layout is SAVED: after a reload every bar starts 1 wide, so the
    -- frame can't tell where a left-half bar's right edge was (seen 2026-10-25: the
    -- dungeon's one-square bar came back full width growing into the combat block).
    local oldW = cfg.w or bar:GetWidth() or 1
    bar:SetSize(usedCols * (size + spacing) - spacing, rows * (size + spacing) - spacing)
    -- left-half bar: keep its right edge where it was (1 = never laid out yet)
    if onLeft and cfg.x and oldW > 1 then cfg.x = cfg.x + oldW - bar:GetWidth() end
    cfg.w = bar:GetWidth()
    -- once: a left-half bar laid out before the "+" moved to its left end had grown one
    -- square to the RIGHT (into the combat block) -- shift it back by that square
    -- (only for a bar that already had a position: the side is now known before the
    -- first layout, so a brand-new bar reached here with no x -- 2026-10-25 error)
    if onLeft and bar.def.curated and not cfg.dropShift then
        cfg.dropShift = true
        if cfg.x then cfg.x = cfg.x - (size + spacing) end
    end
    if self.Outline then self:Outline(bar) end
    -- once: a Pets bar placed before it had a neighbour landed at the fixed y, far above
    -- Travel (the user's hunter, 2026-10-30); one never moved goes next to Travel
    if bar.def.key == "pets" and not cfg.nearV2 then
        cfg.nearV2 = true
        if cfg.y == bar.def.y then cfg.x = nil end
    end
    if not cfg.x then
        local near = bar.def.near
        local nc, nb = near and self:BarConfig(near.key), near and self.bars[near.key]
        if nc and nc.x and nc.y and nb and (nb:GetWidth() or 0) > 1 then
            local gap = self.GROUP_GAP or 14
            cfg.x = nc.x
            cfg.y = near.above and (nc.y + gap + bar:GetHeight()) or (nc.y - nb:GetHeight() - gap)
        else
            cfg.x = (UIParent:GetWidth() - bar:GetWidth()) / 2
            cfg.y = bar.def.y or 305   -- above the usual bottom-center bars; move it in move mode
        end
    end
    self:SnapToBlock(bar, cfg, onLeft)
    self:NudgeOffBars(bar, cfg, onLeft)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
    -- hidden in pet battles and vehicles (Bars.lua VEHICLES)
    RegisterStateDriver(bar, "visibility", (cfg.enabled and (shown > 0 or VB.unlocked))
        and ("[petbattle][vehicleui][overridebar] hide; " .. VB:ShowRule(cfg)) or "hide")
end

local pendingRetry = false
function VB:RebuildSmartBars()
    if InCombatLockdown() then
        self:RunOutOfCombat("smartrebuild", function() self:RebuildSmartBars() end)
        return
    end
    local seedWaiting = (self.SeedTravelList and self:SeedTravelList()) or false
    seedWaiting = (self.SeedProfessionList and self:SeedProfessionList()) or seedWaiting
    for _, bar in ipairs(self.smartBars) do
        local list, pending = self[bar.def.collect](self)
        -- bars you add to (Travel, Professions) get a "+" square to drop things on: at the
        -- outer end -- the LEFT for a bar on the left half of the screen, so it never
        -- grows into the combat block beside it (Professions, 2026-10-25)
        -- No "+" while the bar is hidden in a dungeon / raid (its list is empty there;
        -- a lone "+" kept the bar on screen, seen 2026-10-25 in Den of Nalorakk).
        if bar.def.curated and #list < MAX_BUTTONS and not HiddenInInstance(bar.def.key) then
            table.insert(list, self:SmartBarOnLeft(bar) and 1 or #list + 1, { kind = "drop" })
        end
        bar.shownCount = math.min(#list, MAX_BUTTONS)
        for i, b in ipairs(bar.buttons) do
            b:Assign(list[i])
        end
        self:LayoutSmartBar(bar)
        if (pending or seedWaiting) and not pendingRetry then
            -- some items weren't loaded yet; try again shortly
            pendingRetry = true
            C_Timer.After(2, function() pendingRetry = false; self:RebuildSmartBars() end)
        end
    end
end

function VB:UpdateSmartVisuals()
    for _, bar in ipairs(self.smartBars) do
        for i = 1, (bar.shownCount or 0) do bar.buttons[i]:UpdateVisual() end
    end
end

local queued = false
local function QueueRebuild()
    if queued then return end
    queued = true
    C_Timer.After(0.3, function() queued = false; VB:RebuildSmartBars() end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "PLAYER_LEVEL_UP",
    "SPELLS_CHANGED", "NEW_MOUNT_ADDED", "TOYS_UPDATED", "MOUNT_JOURNAL_USABILITY_CHANGED",
    "SKILL_LINES_CHANGED", "PET_STABLE_UPDATE", "UPDATE_MACROS" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if not VB.smartBars[1] then return end
    if event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN"
        or event == "MOUNT_JOURNAL_USABILITY_CHANGED" then
        VB:UpdateSmartVisuals()
    elseif event == "BAG_UPDATE_DELAYED" then
        VB:UpdateSmartVisuals()   -- counts now
        QueueRebuild()            -- membership (out of combat)
    else
        QueueRebuild()
    end
end)
