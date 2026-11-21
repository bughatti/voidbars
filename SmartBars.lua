----------------------------------------------------------------------
-- VoidBars — smart bars: bars that fill themselves from your bags instead
-- of action slots (they never use any of the 180 server-side slots).
--
-- Consumables (one button per JOB, best version only, current expansion only):
--   healthstone, health potion, bandage, combat potion, flask/phial, buff food, feast,
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
local CLASS_TRADEGOODS = Enum.ItemClass and Enum.ItemClass.Tradegoods or 7
local IS_FOREVER = (select(4, GetBuildInfo()) or 0) < 100000
local MAX_BUTTONS = 12

local HEALTHSTONES = { [5512] = true, [224464] = true }

-- eat / drink go last: a bar holds 12 buttons, so with every job stocked it's plain food
-- that drops off, never a raid flask or rune.
local JOB_ORDER = { "buff", "healthstone", "health", "bandage", "mana", "combat", "flask", "food", "feast", "recover", "oil", "rune", "vantus", "eat", "drink" }

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

-- A red "Requires ..." line on the item's tooltip: this character can't use it yet (a Heavy
-- Silk Bandage before First Aid 150). The game colours an unmet requirement red on every
-- client, so no skill lookup is needed. nil = tooltip not loaded yet.
local function UnmetRequirement(itemID)
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or not data or not data.lines or #data.lines < 2 then return nil end
    for _, line in ipairs(data.lines) do
        local t, c = line.leftText, line.leftColor
        if t and not IsSecret(t) and t:find("^Requires") and c and c.r and c.g
            and c.r > 0.9 and c.g < 0.3 then
            return true
        end
    end
    return false
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
    if classID ~= CLASS_CONSUMABLE then
        -- WoW Forever: raw fish (Raw Sunscale Salmon, Raw Rockscale Cod...) are cooking materials you can also
        -- eat, with no buff: plain food for between pulls. The user, 2026-11-13: "i have fish in my bag that
        -- is just reg food". Blizzard files them as Trade Goods, so the consumable check skipped them.
        if IS_FOREVER and classID == CLASS_TRADEGOODS then
            if minLevel and minLevel > UnitLevel("player") then return nil end
            local txt, ready = UseText(itemID)
            if not ready then return nil, true end
            if txt:find("while eating") and txt:find("restores.-health") and not txt:find("well fed") then
                return "eat"
            end
        end
        return nil
    end
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
    elseif subID == SUB.Bandage then
        -- the user, 2026-11-12: "why is bandages not in the bar with the potions and food"
        local unmet = UnmetRequirement(itemID)
        if unmet == nil then return nil, true end
        if unmet then return nil end
        return "bandage"
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
-- The main stats each class's specs can have: a spec answer outside the set is wrong
-- (Demon Hunter includes Devourer, the intellect spec; Codex review).
local CLASS_STATS = {
    WARRIOR = { str = true }, DEATHKNIGHT = { str = true }, PALADIN = { str = true, int = true },
    ROGUE = { agi = true }, HUNTER = { agi = true }, DEMONHUNTER = { agi = true, int = true },
    MONK = { agi = true, int = true }, DRUID = { agi = true, int = true }, SHAMAN = { agi = true, int = true },
    MAGE = { int = true }, PRIEST = { int = true }, WARLOCK = { int = true }, EVOKER = { int = true },
}
local function MainStat()
    local _, class = UnitClass("player")
    -- WoW Forever: the spec data is a placeholder for its Classic-style characters (a rogue
    -- reported spec 1 with intellect as main stat, 2026-11-07, so attack power food lost to a
    -- fishing fish again). Go by class there.
    local forever = (select(4, GetBuildInfo()) or 0) < 100000
    if not forever then
        -- retail: the spec's primary stat, through C_SpecializationInfo (the old globals can
        -- be turned off; Codex review)
        local SI = C_SpecializationInfo
        local getSpec = (SI and SI.GetSpecialization) or _G.GetSpecialization
        local getInfo = (SI and SI.GetSpecializationInfo) or _G.GetSpecializationInfo
        if getSpec and getInfo then
            local ok, spec = pcall(getSpec)
            if ok and type(spec) == "number" and spec > 0 then
                local ok2, _, _, _, _, _, primary = pcall(getInfo, spec)
                local stat = ok2 and STAT_IDS[primary]
                -- never trust an answer the class can't have (an intellect rogue)
                local allowed = CLASS_STATS[class]
                if stat and (not allowed or allowed[stat]) then return stat end
            end
        end
    end
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

-- WoW Forever: plain vendor food and water by level, for the eat / drink spot when your bags hold none. The
-- user, 2026-11-13: "we have an item that gives well fed, but i also need a spot for just normal food, im not
-- gonna waste well fed food on grinding to heal between pulls". On Forever most cooked food is well fed
-- (Mithril Head Trout: +20 attack power), and the trout was the only food in the bags, so no eat spot showed.
-- Every item below is from Blizzard's Forever item data (checked 2026-11-13): no buff, sold by innkeepers and
-- food vendors, and each tier restores more than the well-fed food of its level.
local VENDOR_FOOD = {
    eat = {
        { 45, { 8952, 8950, 8932, 8953, 8948 } },   -- Roasted Quail, Homemade Cherry Pie, Alterac Swiss, Deep Fried Plantains, Dried King Bolete
        { 35, { 4599, 4601, 3927, 4602 } },         -- Cured Ham Steak, Soft Banana Bread, Fine Aged Cheddar, Moon Harvest Pumpkin
        { 25, { 3771, 4544, 1707 } },               -- Wild Hog Shank, Mulgore Spice Bread, Stormwind Brie
        { 15, { 3770, 4542, 422 } },                -- Mutton Chop, Moist Cornbread, Dwarven Mild
        { 5,  { 2287, 4541, 414 } },                -- Haunch of Meat, Freshly Baked Bread, Dalaran Sharp
        { 1,  { 117, 4540 } },                      -- Tough Jerky, Tough Hunk of Bread
    },
    drink = {
        { 45, { 8766 } }, { 35, { 1645 } }, { 25, { 1708 } },   -- Morning Glory Dew, Moonberry Juice, Sweet Nectar
        { 15, { 1205 } }, { 5, { 1179 } }, { 1, { 159 } },      -- Melon Juice, Ice Cold Milk, Refreshing Spring Water
    },
}
-- the item of your level's tier sold nearest to you (VoidGPS), else the tier's first; plus that vendor
local function VendorFood(job)
    local lvl = UnitLevel("player") or 1
    local goods = _G.VoidGPS and _G.VoidGPS.Goods
    for _, tier in ipairs(VENDOR_FOOD[job]) do
        if lvl >= tier[1] then
            local pick, vendor, yards
            for _, id in ipairs(tier[2]) do
                local ok, e = pcall(goods and goods.Get or function() end, goods, id)
                local v = ok and e and e.vendors and e.vendors[1]
                if v and v.yards and (not yards or v.yards < yards) then pick, vendor, yards = id, v, v.yards end
            end
            return pick or tier[2][1], vendor
        end
    end
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
    -- WoW Forever: no plain food / water in the bags -> the spot stays, greyed, showing what to buy; a click
    -- routes you to the vendor (VendorFood above). Shift+right-click hides it like any item. Before the
    -- one-button rule below, so a food that does both doesn't get a "buy water" spot next to it (Sol review).
    if IS_FOREVER then
        for _, job in ipairs({ "eat", "drink" }) do
            if not best[job] and JobWanted(job) then
                local id, vendor = VendorFood(job)
                if id and not hidden[id] then
                    best[job] = { kind = "item", id = id, job = job, missing = true, vendor = vendor }
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
                elseif barKey == "pvp" and e.kind == "item" and VB.PvPEntry then
                    entry = VB.PvPEntry(e.id)
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
    -- riding gear we put on for a ride (MountGear.lua) is not your main piece
    if VB.MountGear and VB.MountGear:Holds(slot) then return end
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

----------------------------------------------------------------------
-- PvP gear swap (the user, 2026-11-19: "a pvp bar that can hold anything and allows switching of any items that
-- that pvp item went to"; picked: one click puts the PvP piece on, the button then puts back what it replaced).
-- Whenever a piece on the PvP bar goes on in a slot, the piece it pushed off is remembered for it:
-- VoidBarsCharDB.pvpBack[pvpItemID] = { id = replaced itemID, slot = slot }. Riding gear we put on for a ride
-- doesn't count as "replaced": the piece under it does (MountGear's saved one).
----------------------------------------------------------------------
local worn = {}   -- slot -> item LINK worn there (to know what a change pushed off, down to its suffix / enchant)

-- "item:12345:0:..." from a link: the exact copy ("of the Owl", an enchant), and no brackets for a macro to parse
-- (Astra: by item ID alone the wrong copy could go back on)
local function ItemString(link)
    if type(link) ~= "string" or IsSecret(link) then return nil end
    return link:match("|H(item:[^|]+)|h")
end
local function LinkID(link)
    return type(link) == "string" and not IsSecret(link) and C_Item.GetItemInfoInstant(link) or nil
end

local function PvPList()
    local out = {}
    for _, e in ipairs(CuratedList("pvp")) do
        if e.kind == "item" then out[e.id] = true end
    end
    return out
end
function VB.IsPvPItem(id) return id and PvPList()[id] or false end

local function PvPBack()
    VoidBarsCharDB.pvpBack = VoidBarsCharDB.pvpBack or {}
    return VoidBarsCharDB.pvpBack
end

local MAIN, OFF = 16, 17
local offGone, offGoneAt, lastMainAt   -- the off-hand that just came off (a two-hander going on), whichever event comes first

-- takes both hands: two-handers, and on retail bows / guns / crossbows too (they sit in the main hand; Astra)
local function isTwoHander(id)
    local loc = id and select(4, C_Item.GetItemInfoInstant(id))
    return loc == "INVTYPE_2HWEAPON"
        or (not IS_FOREVER and (loc == "INVTYPE_RANGED" or loc == "INVTYPE_RANGEDRIGHT")) or false
end

-- a copy of this item in the bags (C_Item.IsEquippedItem is true for ANY worn copy: with two of the same sword in
-- both hands, the one you took off looked "worn", Astra)
local function InBags(id)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for s = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, s)
            if info and info.itemID == id then return true end
        end
    end
    return false
end

local function RememberPvPSwap(slot)
    local newLink, prevLink = GetInventoryItemLink("player", slot), worn[slot]
    local prevOffLink = worn[OFF]
    worn[slot] = newLink
    local new, prev = LinkID(newLink), LinkID(prevLink)
    local pvp = PvPList()
    local back = PvPBack()
    -- A two-hander pushed the off-hand off: it goes back with the one-hander (Sol). One swap fires two events in
    -- either order. Main-hand first: it still sees the off-hand in worn[OFF]. Off-hand first: it's kept in offGone
    -- for the main-hand event of the SAME swap only (Sol: a shield from an earlier swap got pinned on a later one).
    -- "The same swap" = the same frame: both events of one swap carry the same GetTime(), two swaps never do.
    if slot == OFF and not new and prevLink then
        if lastMainAt ~= GetTime() then offGone, offGoneAt = prevLink, GetTime() end
        return
    end
    local gone = nil
    if slot == MAIN then
        lastMainAt = GetTime()
        gone = offGoneAt == GetTime() and offGone or nil
        offGone, offGoneAt = nil, nil   -- used by this swap or by none
    end
    if not new or newLink == prevLink or not pvp[new] then return end
    local rec = back[new] or {}
    back[new] = rec
    rec.slot = slot   -- where it went: equipping it again goes there (trinkets, rings)
    -- the off-hand a two-hander pushed off just now (either event order)
    local offNow = slot == MAIN and isTwoHander(new) and (prevOffLink or gone) or nil
    -- a partner you picked (Shift+right-click menu) stays, whatever this swap pushed off; a shield a picked
    -- two-hander pushed off still goes back with your pick (Codex)
    if rec.picked then
        rec.off, rec.offStr = offNow and LinkID(offNow) or nil, offNow and ItemString(offNow) or nil
        -- the pick itself came off the off-hand (dual wield): it goes back to the main hand only (Codex)
        if rec.offStr and rec.offStr == rec.str then rec.off, rec.offStr = nil, nil end
        return
    end
    if not prev then
        -- nothing was in that hand: only a shield it pushed off goes back (Sol: it was lost)
        if offNow then rec.id, rec.str, rec.off, rec.offStr = nil, nil, LinkID(offNow), ItemString(offNow) end
        return
    end
    local mg = VB.MountGear
    local saved = mg and VoidBarsCharDB.mountSaved and VoidBarsCharDB.mountSaved[slot]
    if saved and saved.put == prev then
        local under = saved.back and LinkID(saved.back)
        -- getting down: the riding swap put THIS piece back, so what it replaced before stands (Sol)
        if under == new then return end
        -- it went on over riding gear: the piece under the riding gear is the one to go back to
        mg:Forget(slot)
        if under then rec.id, rec.str = under, ItemString(saved.back) end
    elseif mg and mg.WasRiding and mg.WasRiding(prev) then
        return   -- riding gear coming off isn't what this piece replaced
    elseif pvp[prev] then
        -- one PvP piece over another: this one goes back to the other's normal piece (each PvP button switches
        -- between itself and your normal piece; Sol: it was left with nothing to go back to). A shield this swap
        -- pushed off (PvP one-hander -> PvP two-hander) goes back too (Astra).
        local pr = back[prev]
        if pr and (pr.id or pr.off) and pr.id ~= new then   -- (a shield-only record counts too, Sol)
            rec.id, rec.str = pr.id, pr.str
            -- the off-hand you actually wore wins over one inherited from an older swap (Sol)
            if offNow then rec.off, rec.offStr = LinkID(offNow), ItemString(offNow)
            else rec.off, rec.offStr = pr.off, pr.offStr end
        end
    else
        rec.id, rec.str = prev, ItemString(prevLink)
        rec.off, rec.offStr = nil, nil
        if offNow then rec.off, rec.offStr = LinkID(offNow), ItemString(offNow) end
    end
end

-- Weapons switch in combat too (the game allows it), but a button can't change what it does mid-fight. A button
-- that flipped itself after each click went out of step with two PvP weapons or a refused swap (Astra), so a
-- weapon's button does two FIXED things, right whatever you wear: click = put this weapon on, right-click = your
-- own weapon (and off-hand) back. Ranged: slot 18 on WoW Forever, the main hand on retail (Astra).
local RANGED = IS_FOREVER and 18 or MAIN
local WEAPON_SLOT = { INVTYPE_WEAPON = MAIN, INVTYPE_2HWEAPON = MAIN, INVTYPE_WEAPONMAINHAND = MAIN,
    INVTYPE_WEAPONOFFHAND = OFF, INVTYPE_SHIELD = OFF, INVTYPE_HOLDABLE = OFF,
    INVTYPE_RANGED = RANGED, INVTYPE_RANGEDRIGHT = RANGED, INVTYPE_THROWN = RANGED }
local function EquipText(slot, str, offStr)
    return ("/equipslot %d %s"):format(slot, str) .. (offStr and ("\n/equipslot 17 " .. offStr) or "")
end

-- where your picked partner is worn: that exact copy first (two rings of one name, different suffixes; Codex),
-- else any copy
local function SlotOfPick(rec)
    if rec.str then
        for s = 1, 19 do
            if ItemString(GetInventoryItemLink("player", s)) == rec.str then return s end
        end
    end
    return SlotOfEquipped(rec.id)
end

-- can an item of this equip type go in that slot?
local FIT = { INVTYPE_TRINKET = { [13] = true, [14] = true }, INVTYPE_FINGER = { [11] = true, [12] = true },
    INVTYPE_WEAPON = { [MAIN] = true, [OFF] = true } }
local function FitsSlot(loc, s)
    if FIT[loc] then return FIT[loc][s] or false end
    if WEAPON_SLOT[loc] then return WEAPON_SLOT[loc] == s end
    return true   -- armor: one slot, the game puts it there anyway
end

-- the PvP bar's entry for an item on your list
local function TwoSlot(id)
    local _, _, _, loc = C_Item.GetItemInfoInstant(id)
    return loc == "INVTYPE_TRINKET" or loc == "INVTYPE_FINGER" or loc == "INVTYPE_WEAPON", loc
end
function VB.PvPEntry(id)
    local _, loc = TwoSlot(id)
    if not C_Item.IsEquippableItem(id) or loc == "INVTYPE_BAG" then
        return { kind = "item", id = id }   -- a potion, a scroll...: just used
    end
    local rec = PvPBack()[id]
    local slot = SlotOfEquipped(id)
    local wslot = WEAPON_SLOT[loc]
    local back = rec and rec.id
    local have = back and back ~= id and InBags(back)
    local backStr = have and (rec.str or ("item:" .. back)) or nil
    local off = rec and rec.off and InBags(rec.off) and (rec.offStr or ("item:" .. rec.off)) or nil
    -- the partner you picked, where you wear it now: the PvP piece goes in exactly that slot (Smotts' Compass in
    -- place of the Golden Banana, not whichever trinket the game picks; the user, 2026-11-20)
    local pickedSlot = rec and rec.picked and rec.id and not slot and SlotOfPick(rec) or nil
    -- only a slot this piece can go in (a picked one-hander in the off-hand is no spot for a two-hander; Codex)
    if pickedSlot and not FitsSlot(loc, pickedSlot) then pickedSlot = nil end
    if wslot then
        -- a weapon: click = this weapon on, right-click = your own weapon back (fixed, so right in combat too)
        local eq = slot or pickedSlot or (rec and rec.slot) or wslot
        local normStr, normOff, normID = backStr, off, have and back or nil
        if not slot then
            -- not worn: your own weapon is what's in that slot now, or, when that's another PvP weapon, ITS own
            local curLink = GetInventoryItemLink("player", eq)
            local curID = LinkID(curLink)
            local pr = curID and PvPList()[curID] and PvPBack()[curID]
            if rec and rec.picked and rec.id then
                -- your pick, whatever you wear now: the right-click is fixed for the fight (Codex)
                normID, normStr = rec.id, rec.str or ("item:" .. rec.id)
                normOff = isTwoHander(id) and ItemString(GetInventoryItemLink("player", OFF)) or nil
                if normOff == normStr then normOff = nil end   -- the pick itself sat in the off-hand
            elseif pr then
                normID, normStr = pr.id, pr.id and (pr.str or ("item:" .. pr.id))
                -- (a PvP one-hander kept your shield on: the shield you wear now goes back with it, Astra)
                normOff = (isTwoHander(id) and ItemString(GetInventoryItemLink("player", OFF))) or pr.offStr   -- worn now wins (Sol)
            elseif curID then
                normID, normStr = curID, ItemString(curLink)
                normOff = isTwoHander(id) and ItemString(GetInventoryItemLink("player", OFF)) or nil
            end
        end
        -- your weapon goes back where it fits: a two-hander picked for a one-hander worn in the off-hand goes in the
        -- main hand, with nothing for the off-hand (Codex)
        local putSlot = eq
        local normLoc = normID and select(4, C_Item.GetItemInfoInstant(normID))
        if normLoc and not FitsSlot(normLoc, eq) then putSlot = WEAPON_SLOT[normLoc] or eq end
        -- a two-hander takes both hands: no off-hand line after it (it would knock the two-hander off again)
        if normID and isTwoHander(normID) then normOff = nil end
        -- (the hand was empty before: the shield alone goes back)
        local backText = (normStr and EquipText(putSlot, normStr, normOff)) or (normOff and ("/equipslot 17 " .. normOff)) or nil
        -- right-click: worn = your own weapon back; not worn = this one on
        -- (a worn weapon with an on-use: left-click uses it, like a trinket; Codex)
        -- In combat the right-click keeps the direction it had when the fight began (a button can't change in
        -- combat): one swap per fight, it flips once the fight ends.
        return { kind = "item", id = id, pvp = true, weapon = true, worn = slot ~= nil, equipSlot = eq,
            use = slot ~= nil and C_Item.GetItemSpell(id) ~= nil,
            backID = normID, backText = backText,
            swapText = slot and backText or ("/equipslot %d item:%d"):format(eq, id) }
    end
    -- The PvP bar's clicks (the user, 2026-11-20: "right click swaps the item with what slot it goes in, left click
    -- uses the item if its usable"): the button always shows the PvP piece itself.
    --   left-click: use it (worn, with an on-use: a PvP trinket breaks free); otherwise nothing
    --   right-click: worn = the piece it replaced (or your pick) back on; not worn = it on, in your pick's slot /
    --   the slot it went to last time / where the game puts it
    local use = slot ~= nil and C_Item.GetItemSpell(id) ~= nil
    if slot then
        return { kind = "item", id = id, pvp = true, worn = true, use = use, backID = have and back or nil,
            backSlot = slot, swapText = have and EquipText(slot, backStr) or nil }
    end
    local twoSlot = TwoSlot(id)
    local es = pickedSlot or (twoSlot and rec and rec.slot) or nil
    return { kind = "item", id = id, pvp = true, worn = false, equipSlot = es,
        swapText = es and ("/equipslot %d item:%d"):format(es, id) or ("/equip item:%d"):format(id) }
end

-- Choosing what a PvP piece trades places with (the user, 2026-11-20: "i have no way to swap out that spot ...
-- Smotts compass which i would swap out with the golden banana, the mark of the chosen gets swapped out with
-- carrot ... in some bgs i would not use a mount so i would use something other than carrot").
-- Shift+right-click a PvP gear button: every piece in your bags or worn that fits the same slot, plus
-- "whatever it pushes off" (the automatic way), plus removing it from the bar.
-- VoidBarsCharDB.pvpBack[id].picked = true keeps the pick: swaps never overwrite it.
local function SlotGroup(id)
    local loc = id and select(4, C_Item.GetItemInfoInstant(id))
    if not loc or loc == "" then return nil end
    if WEAPON_SLOT[loc] then return "w" .. WEAPON_SLOT[loc] end
    if loc == "INVTYPE_ROBE" then return "INVTYPE_CHEST" end
    return loc
end

-- pieces that could trade places with item id: { id, link, str }, bags first, then worn; one per exact copy
function VB.PvPPartners(id)
    local group, out, seen = SlotGroup(id), {}, {}
    if not group then return out end
    local function add(link)
        local pid, str = LinkID(link), ItemString(link)
        if pid and pid ~= id and str and not seen[str] and SlotGroup(pid) == group then
            seen[str] = true
            out[#out + 1] = { id = pid, link = link, str = str }
        end
    end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for s = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, s)
            if info and info.hyperlink then add(info.hyperlink) end
        end
    end
    for slot = 1, 19 do add(GetInventoryItemLink("player", slot)) end
    return out
end

-- the pick: a partner (from VB.PvPPartners) or nil = back to the automatic way
function VB.SetPvPPartner(id, p)
    local back = PvPBack()
    local rec = back[id] or {}
    back[id] = rec
    if p then
        rec.id, rec.str, rec.picked = p.id, p.str, true
        -- worn right now: the off-hand this piece pushed off stays recorded (no equip event would bring it back);
        -- not worn: the next swap records it (Codex)
        if not SlotOfEquipped(id) then rec.off, rec.offStr = nil, nil end
        -- the pick was that off-hand (dual wield): it goes back to the main hand only (Codex)
        if rec.offStr and rec.offStr == rec.str then rec.off, rec.offStr = nil, nil end
        -- the pick's slot only when this piece fits there (a one-hander in the off-hand: not a two-hander's; Codex)
        local ps = SlotOfEquipped(p.id)
        if ps and FitsSlot(select(4, C_Item.GetItemInfoInstant(id)), ps) then rec.slot = ps end
    else
        rec.picked = nil
    end
    VB:RunOutOfCombat("smartrebuild", function() VB:RebuildSmartBars() end)
end

function VB.PvPPartnerOf(id)
    local rec = PvPBack()[id]
    return rec and rec.picked and rec.id or nil
end

local gearEv = CreateFrame("Frame")
gearEv:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
gearEv:RegisterEvent("PLAYER_ENTERING_WORLD")
gearEv:SetScript("OnEvent", function(_, event, slot)
    if not VoidBarsCharDB then return end
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot then
        RememberPvPSwap(slot)
        RememberMainGear(slot)
        if VB.RebuildSmartBars then
            VB:RunOutOfCombat("smartrebuild", function() VB:RebuildSmartBars() end)
        end
    else
        for s = 1, 19 do
            worn[s] = GetInventoryItemLink("player", s)
            RememberMainGear(s)
        end
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

-- PvP: like Random (anything you drag on), and gear on it swaps (VB.PvPEntry).
function VB:CollectPvP()
    local list, _, addCurated = NewCollector("pvp")
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
    -- PvP gear you're wearing: a small green corner, so you see which way a right-click goes
    if e.pvp and e.worn and not self.vbWorn then
        self.vbWorn = self:CreateTexture(nil, "OVERLAY")
        self.vbWorn:SetColorTexture(0.2, 1, 0.3, 0.9)
        self.vbWorn:SetSize(6, 6)
        self.vbWorn:SetPoint("TOPRIGHT", -2, -2)
    end
    if self.vbWorn then self.vbWorn:SetShown(e.pvp and e.worn or false) end
    if e.kind == "drop" then
        self.icon:SetTexture(nil)
        self.cooldown:Clear()
    elseif e.kind == "item" then
        self.icon:SetTexture(C_Item.GetItemIconByID(e.id))
        local count = C_Item.GetItemCount(e.id, false, true) or 0
        self.Count:SetText(count > 1 and count or "")
        -- a worn piece (PvP trinket) isn't in the bags but is there to use
        if count == 0 and not C_Item.IsEquippedItem(e.id) then self.icon:SetVertexColor(VB.COLOR.unusable:GetRGB())
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
    for _, a in ipairs({ "item", "toy", "spell", "macro", "macrotext", "house-neighborhood-guid", "house-guid", "house-plot-id",
        "type2", "macrotext2" }) do
        self:SetAttribute(a, nil)
    end
    -- the "+" square and a food you don't carry (Forever's plain-food spot) use nothing: the click routes
    -- to a vendor instead (PostClick)
    if not e or e.kind == "drop" or e.missing then
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
    elseif e.kind == "item" and e.pvp then
        -- PvP gear (VB.PvPEntry): left = use it (worn, with an on-use), right = swap it in / out. A missing action
        -- is "vbnoop": with no type2 the right button would fall back to the left one (secure template rule)
        self:SetAttribute("type", e.use and "item" or "vbnoop")
        self:SetAttribute("item", e.use and ("item:" .. e.id) or nil)
        self:SetAttribute("type2", e.swapText and "macro" or "vbnoop")
        self:SetAttribute("macrotext2", e.swapText)
    elseif e.kind == "item" and e.equipSlot then
        -- gear into one exact slot (the profession bar's swaps)
        -- (equipStr: the exact copy, suffix and enchant included)
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", EquipText(e.equipSlot, e.equipStr or ("item:" .. e.id)))
        if e.weapon and e.backText then
            -- a weapon: right-click = your own weapon (and off-hand) back, in combat too (Shift+right-click
            -- still removes it from the bar)
            self:SetAttribute("type2", "macro")
            self:SetAttribute("macrotext2", e.backText)
        end
    elseif e.kind == "item" then
        self:SetAttribute("type", "item")
        self:SetAttribute("item", "item:" .. e.id)
        if e.back and e.backSlot then
            -- a worn on-use piece: right-click puts the old one back (Shift+right-click still removes)
            self:SetAttribute("type2", "macro")
            self:SetAttribute("macrotext2", EquipText(e.backSlot, e.backStr or ("item:" .. e.back)))
        end
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

-- the PvP item a PvP bar button stands for (a worn piece without an on-use shows its partner: e.swapFor)
local function PvPItemOf(e)
    local id = e and e.kind == "item" and (e.swapFor or e.id)
    return id and C_Item.IsEquippableItem(id) and VB.IsPvPItem(id) and id or nil
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
    elseif e.kind == "item" then
        GameTooltip:SetItemByID(e.id)
        if e.missing then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("None in your bags", 1, 0.35, 0.35)
            GameTooltip:AddLine(e.job == "drink" and "Plain water restores mana between pulls."
                or "Plain food heals between pulls, so your well-fed food is kept for when the buff counts.", 0.8, 0.8, 0.8, true)
            if e.vendor then
                GameTooltip:AddLine("Click: the way to the nearest vendor that sells it", 0.4, 1, 0.4, true)
            else
                GameTooltip:AddLine("Sold by innkeepers and food vendors.", 0.8, 0.8, 0.8, true)
            end
        end
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
            C_Item.GetItemNameByID(e.swapFor) or "the other piece"), 0.4, 1, 0.4, true)
    elseif e.pvp then
        if e.use then GameTooltip:AddLine("Left-click: use it", 0.4, 1, 0.4) end
        local backName = e.backID and C_Item.GetItemNameByID(e.backID)
        if e.worn and e.swapText then
            GameTooltip:AddLine(("Right-click: put %s back on"):format(backName or "your own piece"), 0.4, 1, 0.4, true)
        elseif e.worn then
            GameTooltip:AddLine("Wearing it. Nothing to swap back yet: Shift+Right-click to pick what it swaps with",
                0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Right-click: put it on", 0.4, 1, 0.4)
        end
        if not e.weapon then
            GameTooltip:AddLine("Gear swaps only out of combat (the game's rule); weapons swap in combat too",
                0.6, 0.6, 0.6, true)
        end
    end
    local pvpID = bar.def.key == "pvp" and PvPItemOf(e)
    if pvpID then
        local partner = VB.PvPPartnerOf(pvpID)
        if partner then
            GameTooltip:AddLine(("Swaps with %s (your pick)"):format(C_Item.GetItemNameByID(partner) or "your pick"),
                0.4, 0.8, 1, true)
        end
        GameTooltip:AddLine("Shift+Right-click: choose what it swaps with, or remove it", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Drag a mount, toy, item, spell or macro here to add it", 0.6, 0.6, 0.6)
    elseif bar.def.curated then
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

-- Shift+right-click on PvP gear: pick what it trades places with, or remove it (VB.PvPPartners / SetPvPPartner)
local function PvPPartnerMenu(self, bar, id)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then RightClick(self, bar) return end
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle((C_Item.GetItemNameByID(id) or "This piece") .. " swaps with:")
        local cur = VB.PvPPartnerOf(id)
        local curStr = cur and PvPBack()[id].str
        local list = VB.PvPPartners(id)
        local function pick(p) VB.SetPvPPartner(id, p) end
        for _, p in ipairs(list) do
            -- the exact copy (two of one name with different suffixes: only yours is marked; Codex)
            local isIt = function() return cur == p.id and (curStr == nil or curStr == p.str) end
            if root.CreateRadio then
                root:CreateRadio(p.link, isIt, function() pick(p) end)
            else
                root:CreateButton((isIt() and "> " or "") .. p.link, function() pick(p) end)
            end
        end
        if #list == 0 then
            root:CreateTitle("|cff999999Nothing in your bags fits that slot|r")
        end
        local auto = "Whatever it pushes off (automatic)"
        if root.CreateRadio then
            root:CreateRadio(auto, function() return cur == nil end, function() pick(nil) end)
        else
            root:CreateButton((cur == nil and "> " or "") .. auto, function() pick(nil) end)
        end
        root:CreateDivider()
        root:CreateButton("|cffff6060Remove from the PvP bar|r", function()
            -- by the PvP item itself: a worn piece's button shows its partner, so the button's own entry
            -- would only hide that
            local pvp = CuratedList("pvp")
            for i = #pvp, 1, -1 do
                if pvp[i].kind == "item" and pvp[i].id == id then table.remove(pvp, i) end
            end
            VB:RunOutOfCombat("smartrebuild", function() VB:RebuildSmartBars() end)
        end)
    end)
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
    -- was it a "buy this" spot when the click STARTED? Eating your last plain food can turn the button into
    -- one between press and release, and that click must not also start a route (Sol review).
    b:HookScript("PreClick", function(self, button, down)
        if down then self.vbMissingClick = self.entry and self.entry.missing or nil end
    end)
    b:HookScript("PostClick", function(self, button, down)
        self:SetChecked(false)
        -- release only: the button fires on press AND release, and the bar
        -- rebuilds in between -- reacting to both would act twice
        if down or not self.entry or InCombatLockdown() then return end
        if self.entry.kind == "drop" then
            -- clicking the "+" while holding something adds it, like dropping it
            if GetCursorInfo() then VB:AddCursorTo(bar.def.key, bar.def.label:lower()) end
        elseif button == "RightButton" and IsShiftKeyDown() then
            local pvpID = bar.def.key == "pvp" and PvPItemOf(self.entry)
            if pvpID then PvPPartnerMenu(self, bar, pvpID) else RightClick(self, bar) end
        elseif self.entry.missing and self.vbMissingClick then
            -- a plain food / water you don't carry: the way to the nearest vendor that sells it (VoidGPS)
            -- (looked up now: the nearest one from where you stand, not where the bar was last built)
            local e, goods = self.entry, _G.VoidGPS and _G.VoidGPS.Goods
            local name = C_Item.GetItemNameByID(e.id) or "food"
            local ok, went = pcall(goods and goods.Go or function() end, goods, e.id)
            if not (ok and went) then
                VB:Print(("No %s in your bags: innkeepers and food vendors sell it."):format(name))
            end
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
    -- the user, 2026-11-19: "a pvp bar that can hold anything"; gear on it swaps (VB.PvPEntry); then "as big as my
    -- 1-7 and under the aoe mode button": one row of 7 at the 1-7 keys' size, under VoidSequencer's switch
    { key = "pvp",         label = "PvP",         kind = "smart", collect = "CollectPvP",         y = 305, curated = true, side = "right",
      near = { key = "random" }, underToggle = true, max = 7 },
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

-- The PvP bar's own spot: the 1-7 keys' (bar1) button size and spacing, one row, centered under VoidSequencer's
-- ST/AoE switch in the space between it and bar1 (the user's layout: 57 px there, a 45 px row fits). No switch
-- shown (no VoidSequencer, a healer spec): right above bar1. Dragged in move mode -> cfg.free: yours from then on.
function VB:PlaceUnderToggle(bar, cfg)
    local b1, c1 = self.bars.bar1, self:BarConfig("bar1")
    if not (b1 and c1 and c1.enabled and c1.x and c1.y and (b1:GetWidth() or 0) > 1) then return false end
    local gap = c1.spacing or 4
    local h, w = bar:GetHeight(), bar:GetWidth()
    local bottom = c1.y + gap
    local cx = c1.x + b1:GetWidth() / 2
    local tog = _G.VoidSeqToggle
    local tb, tl, tr = tog and tog:IsShown() and tog:GetBottom(), tog and tog:GetLeft(), tog and tog:GetRight()
    if tb and tl and tr and tb > c1.y then
        local room = tb - c1.y
        if room >= h then bottom = c1.y + (room - h) / 2 end   -- centered between bar1 and the switch
        cx = (tl + tr) / 2
    end
    local x, top = cx - w / 2, bottom + h
    -- another bar already sits there (a rogue's stance bar, a pet bar: seen on the user's rogue 2026-11-20, the
    -- "+" lay on the Stealth bar's end): slide right past it, never on top of it
    -- (the switch itself too: with too little room under it the row would reach up into it; Sol)
    local sgap = self.GROUP_GAP or 14
    local others = {}
    for _, o in ipairs(self.bars) do others[#others + 1] = o end
    if tog then others[#others + 1] = tog end
    for _ = 1, #others + 1 do   -- each pass moves past at least one frame, so this always ends clear (Sol)
        local moved = false
        for _, o in ipairs(others) do
            if o ~= bar and o ~= b1 and o:IsVisible() then
                local l, r, t, bo = o:GetLeft(), o:GetRight(), o:GetTop(), o:GetBottom()
                if type(l) == "number" and type(r) == "number" and type(t) == "number" and type(bo) == "number"
                    and (r - l) > 1
                    and top > bo and top - h < t                        -- rows overlap
                    and x < r + gap and l - gap < x + w then             -- columns overlap (or touch)
                    x, moved = r + sgap, true
                end
            end
        end
        if not moved then break end
    end
    cfg.x, cfg.y = x, top
    return true
end

function VB:LayoutSmartBar(bar)
    local cfg = self:BarConfig(bar.def.key)
    -- the PvP bar takes the 1-7 keys' size once (the sliders still change it after)
    if bar.def.underToggle and not cfg.likeBar1 then
        local c1 = self:BarConfig("bar1")
        if c1 and c1.size then
            cfg.likeBar1 = true
            cfg.size, cfg.spacing, cfg.cols = c1.size, c1.spacing or 4, bar.def.max or 7
        end
    end
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
    local placed = bar.def.underToggle and not cfg.free and self:PlaceUnderToggle(bar, cfg)
    if bar.def.underToggle then bar.vbUnderToggle = placed or nil end
    if not placed then
        self:SnapToBlock(bar, cfg, onLeft)
        self:NudgeOffBars(bar, cfg, onLeft)
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
    -- the get-off button moves beside the PvP bar while it fills the row above the 1-7 keys (Bars.lua)
    if bar.def.underToggle and self.PlaceVehicleExit then self:PlaceVehicleExit() end
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
        local max = bar.def.max or MAX_BUTTONS   -- the PvP bar: one row of 7, like the 1-7 keys
        if bar.def.curated and #list < max and not HiddenInInstance(bar.def.key) then
            table.insert(list, self:SmartBarOnLeft(bar) and 1 or #list + 1, { kind = "drop" })
        end
        bar.shownCount = math.min(#list, max)
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

-- What the shown smart bars hold right now: { [id] = true } for one kind ("spell" / "item").
-- The suggested layout keeps these off the 14 keys (one press, one place).
function VB:SmartBarIDs(kind)
    local out = {}
    for _, bar in ipairs(self.smartBars or {}) do
        local cfg = self:BarConfig(bar.def.key)
        if cfg and cfg.enabled ~= false then
            for i = 1, (bar.shownCount or 0) do
                local e = bar.buttons[i] and bar.buttons[i].entry
                if e and e.kind == kind and e.id and not e.missing then out[e.id] = true end
            end
        end
    end
    return out
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

-- The PvP bar follows VoidSequencer's ST/AoE switch: it's placed at login (maybe after our first layout) and can be
-- dragged (right-click), shown or hidden by spec.
local toggleHooked = false
local function HookToggle()
    local tog = _G.VoidSeqToggle
    if toggleHooked or not tog then return end
    toggleHooked = true
    local function relayout()
        local bar = VB.bars and VB.bars.pvp
        if bar and bar.shownCount then
            VB:RunOutOfCombat("pvpplace", function() VB:LayoutSmartBar(bar) end)
        end
    end
    hooksecurefunc(tog, "SetPoint", relayout)
    tog:HookScript("OnDragStop", relayout)
    tog:HookScript("OnShow", relayout)
    tog:HookScript("OnHide", relayout)
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
    if event == "PLAYER_ENTERING_WORLD" then HookToggle() end
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
