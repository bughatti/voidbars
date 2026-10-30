----------------------------------------------------------------------
-- VoidBars — suggested layout for the 14-key combat block (naga7).
--
-- Key 1 is VoidSequencer, which casts the whole damage rotation (and its
-- held-modifier spells). So the other 13 keys get what it DOESN'T press:
-- interrupt (always key 3), then stuns, heals, defensives, escapes, mobility
-- and group utility, in each class's order below. Only spells you actually
-- have count (talents + level), and anything VoidSequencer casts is skipped
-- and also cleared off your shown bars -- one press, one place.
--
-- Talented active abilities that aren't in a class list (e.g. a new talent)
-- are added too, so nothing you took gets lost. Spells are compared by
-- base spell id, so a talent override and its base never take two keys.
-- The class lists are English spell names (enUS client).
-- Your bars are saved as profile "Before suggested" first.
--
-- Order (2026-10-24): damage the rotation doesn't cast gets the best keys (2, 4-7),
-- ranked by YOUR damage per spell (SpellDamage.lua, Blizzard's damage meter), unmeasured
-- ones by shortest cooldown; then defensives / heals, crowd control, movement, utility
-- (class-list order inside each group). Spells already on one of the 14 keys keep that
-- key; new ones fill the free keys. "Re-sort all" ignores where spells sit now.
--
-- Without VoidSequencer (2026-10-28) VoidBars stands alone: key 1 is a normal key, your
-- spellbook's damage spells join the list (the rotation the class lists leave out), the
-- top row 1-7 gets damage and the Shift row the rest. The fixed spec layouts need
-- VoidSequencer's macros, so they're skipped.
----------------------------------------------------------------------
local _, VB = ...

local INTERRUPT_KEY = 3

-- Per class: interrupt candidates (first one you know wins), taunts (tanks only, go
-- right after the interrupt), then everything else most-important first. The first
-- five fill keys 2,4,5,6,7; the rest Shift+1..7. Names you don't know are skipped.
local CLASS = {
    ROGUE = {
        interrupt = { "Kick" },
        -- Shadowstep = Subtlety's gap closer (Grappling Hook is Outlaw's). Cheap Shot and
        -- Sap are left out: stealth-only openers that would push Shroud (M+ skips) off the
        -- 14 keys, since crowd control ranks above utility.
        list = { "Kidney Shot", "Crimson Vial", "Feint", "Evasion", "Vanish",
            "Stealth", "Sprint", "Shadowstep", "Grappling Hook", "Cloak of Shadows", "Blind", "Gouge",
            "Tricks of the Trade", "Shroud of Concealment", "Shiv", "Distract" },
    },
    DEATHKNIGHT = {
        interrupt = { "Mind Freeze" }, taunt = { "Dark Command" },
        list = { "Death Grip", "Death Strike", "Anti-Magic Shell", "Asphyxiate", "Death's Advance",
            "Icebound Fortitude", "Anti-Magic Zone", "Lichborne", "Raise Ally", "Chains of Ice",
            "Blinding Sleet", "Gorefiend's Grasp", "Vampiric Blood", "Wraith Walk", "Control Undead", "Path of Frost" },
    },
    DEMONHUNTER = {
        interrupt = { "Disrupt" }, taunt = { "Torment" },
        list = { "Chaos Nova", "Blur", "Fel Rush", "Vengeful Retreat", "Darkness", "Imprison",
            "Sigil of Misery", "Sigil of Silence", "Fiery Brand", "Demon Spikes", "Infernal Strike",
            "Netherwalk", "Consume Magic", "Spectral Sight" },
    },
    DRUID = {
        interrupt = { "Skull Bash", "Solar Beam" }, taunt = { "Growl" },
        list = { "Barkskin", "Frenzied Regeneration", "Regrowth", "Survival Instincts", "Dash",
            "Mighty Bash", "Incapacitating Roar", "Typhoon", "Ursol's Vortex", "Stampeding Roar",
            "Wild Charge", "Renewal", "Remove Corruption", "Nature's Cure", "Soothe", "Rebirth",
            "Innervate", "Cyclone", "Entangling Roots" },
    },
    EVOKER = {
        interrupt = { "Quell" },
        list = { "Obsidian Scales", "Hover", "Renewing Blaze", "Verdant Embrace", "Tail Swipe",
            "Wing Buffet", "Landslide", "Sleep Walk", "Cauterizing Flame", "Expunge", "Rescue",
            "Time Spiral", "Zephyr", "Oppressing Roar", "Source of Magic" },
    },
    HUNTER = {
        interrupt = { "Counter Shot", "Muzzle" },
        list = { "Exhilaration", "Disengage", "Aspect of the Turtle", "Freezing Trap", "Intimidation",
            "Binding Shot", "Feign Death", "Misdirection", "Survival of the Fittest", "Tar Trap",
            "Tranquilizing Shot", "Aspect of the Cheetah", "Concussive Shot" },
    },
    MAGE = {
        interrupt = { "Counterspell" },
        list = { "Blink", "Shimmer", "Ice Block", "Ice Barrier", "Blazing Barrier", "Prismatic Barrier",
            "Frost Nova", "Mirror Image", "Alter Time", "Greater Invisibility", "Invisibility",
            "Dragon's Breath", "Blast Wave", "Polymorph", "Ring of Frost", "Spellsteal",
            "Remove Curse", "Slow", "Mass Barrier" },
    },
    MONK = {
        interrupt = { "Spear Hand Strike" }, taunt = { "Provoke" },
        list = { "Leg Sweep", "Fortifying Brew", "Roll", "Chi Torpedo", "Expel Harm", "Vivify",
            "Touch of Karma", "Diffuse Magic", "Dampen Harm", "Paralysis", "Tiger's Lust",
            "Transcendence", "Transcendence: Transfer", "Ring of Peace", "Detox", "Life Cocoon" },
    },
    PALADIN = {
        interrupt = { "Rebuke" }, taunt = { "Hand of Reckoning" },
        list = { "Hammer of Justice", "Word of Glory", "Divine Shield", "Divine Steed",
            "Divine Protection", "Shield of Vengeance", "Ardent Defender", "Guardian of Ancient Kings",
            "Blessing of Freedom", "Blessing of Protection", "Lay on Hands", "Blessing of Sacrifice",
            "Cleanse Toxins", "Cleanse", "Blinding Light", "Repentance", "Intercession", "Turn Evil" },
    },
    PRIEST = {
        interrupt = { "Silence" },
        list = { "Desperate Prayer", "Power Word: Shield", "Fade", "Dispersion", "Psychic Scream",
            "Vampiric Embrace", "Angelic Feather", "Flash Heal", "Mass Dispel", "Purify Disease",
            "Purify", "Dispel Magic", "Leap of Faith", "Psychic Horror", "Mind Soothe",
            "Shackle Undead", "Mind Control" },
    },
    SHAMAN = {
        interrupt = { "Wind Shear" },
        list = { "Astral Shift", "Healing Surge", "Capacitor Totem", "Spirit Walk", "Gust of Wind",
            "Ghost Wolf", "Earth Elemental", "Thunderstorm", "Hex", "Tremor Totem", "Earthbind Totem",
            "Wind Rush Totem", "Poison Cleansing Totem", "Cleanse Spirit", "Purify Spirit", "Purge",
            "Spiritwalker's Grace" },
    },
    WARLOCK = {
        interrupt = { "Spell Lock", "Axe Toss" },
        list = { "Unending Resolve", "Mortal Coil", "Dark Pact", "Shadowfury", "Demonic Circle: Teleport",
            "Fear", "Howl of Terror", "Demonic Gateway", "Burning Rush", "Demonic Circle",
            "Create Healthstone", "Soulstone", "Banish", "Health Funnel" },
    },
    WARRIOR = {
        interrupt = { "Pummel" }, taunt = { "Taunt" },
        list = { "Impending Victory", "Victory Rush", "Storm Bolt", "Shockwave", "Charge", "Heroic Leap",
            "Rallying Cry", "Die by the Sword", "Enraged Regeneration", "Spell Reflection",
            "Shield Wall", "Last Stand", "Intimidating Shout", "Intervene", "Berserker Rage",
            "Piercing Howl", "Hamstring" },
    },
}

-- Same "do you have it" test VoidSequencer uses: known directly or via its base spell
-- (talent overrides).
local function KnownID(name)
    local info = C_Spell.GetSpellInfo(name)
    local id = info and info.spellID
    if not id then return nil end
    if C_SpellBook.IsSpellKnown(id) then return id end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id)
    if base and base ~= id and C_SpellBook.IsSpellKnown(base) then return base end
    return nil
end

-- Active (non-passive) abilities from your applied talents, hero tree included.
local function TalentedActives()
    local out = {}
    local cfg = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    local ci = cfg and C_Traits.GetConfigInfo(cfg)
    for _, treeID in ipairs(ci and ci.treeIDs or {}) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
            local n = C_Traits.GetNodeInfo(cfg, nodeID)
            if n and n.activeEntry and (n.activeRank or 0) > 0 and not (n.subTreeID and not n.subTreeActive) then
                local e = C_Traits.GetEntryInfo(cfg, n.activeEntry.entryID)
                local d = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
                local sid = d and d.spellID
                if sid and not C_Spell.IsSpellPassive(sid) and C_SpellBook.IsSpellKnown(sid) then
                    local nm = C_Spell.GetSpellName(sid)
                    if nm then out[#out + 1] = nm end
                end
            end
        end
    end
    table.sort(out)
    return out
end

-- One identity per ability: a talent override (Shimmer over Blink) and its base spell
-- compare equal, whichever name or slot id we start from.
local function Canon(id)
    if not id then return nil end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id)
    return base or id
end

local function CanonByName(name)
    local info = C_Spell.GetSpellInfo(name)
    return info and Canon(info.spellID)
end

-- VoidSequencer drives key 1 only when it's loaded AND switched on. Every VoidSequencer
-- branch below (key 1, skipped spells, fixed layouts, wording) asks this one question.
local function SeqActive()
    local api = VoidSequencerAPI
    return api ~= nil and (not api.IsEnabled or api.IsEnabled()) and true or false
end
VB.SeqActive = SeqActive

-- Spells VoidSequencer already casts (rotation + held modifiers), as canonical ids.
-- Empty without it.
local function RotationSpells()
    local api = VoidSequencerAPI
    local out = {}
    if not (SeqActive() and api.RotationSpells) then return out end
    for name in pairs(api.RotationSpells() or {}) do
        local c = CanonByName(name)
        if c then out[c] = true end
    end
    return out
end

-- Active spells in your class and current spec spellbook tabs (General, off-spec and
-- passives skipped). Only used without VoidSequencer, to find the rotation.
local function SpellbookActives()
    local out = {}
    local bank = Enum.SpellBookSpellBank.Player
    for line = 2, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.isGuild and not info.shouldHide and not info.offSpecID then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local it = C_SpellBook.GetSpellBookItemInfo(i, bank)
                if it and it.itemType == Enum.SpellBookItemType.Spell and it.spellID
                    and not it.isPassive and not it.isOffSpec then
                    out[#out + 1] = C_Spell.GetSpellName(it.spellID) or it.name
                end
            end
        end
    end
    return out
end

local function KeyText(cmd, fallback)
    local key = GetBindingKey(cmd)
    return key and GetBindingText(key) or fallback
end

-- Canonical spell id in a slot (nil for empty / non-spell).
local function SpellAt(slot)
    local t, id = GetActionInfo(slot)
    if VB.IsSecret(t) or VB.IsSecret(id) or t ~= "spell" or not id then return nil end
    return Canon(id)
end

-- Tooltip text (lower case) and cooldown in seconds (0 = none) of a spell. The
-- tooltip is the one place both live (enUS: "30 sec cooldown", "2 min recharge").
local function SpellText(id)
    local data = C_TooltipInfo and C_TooltipInfo.GetSpellByID and C_TooltipInfo.GetSpellByID(id)
    local parts, cd = {}, 0
    for _, l in ipairs(data and data.lines or {}) do
        for _, txt in ipairs({ l.leftText or "", l.rightText or "" }) do
            if type(txt) == "string" and not VB.IsSecret(txt) and txt ~= "" then
                parts[#parts + 1] = txt:lower()
                local n, unit = txt:match("([%d%.]+) (%a+) cooldown")
                if not n then n, unit = txt:match("([%d%.]+) (%a+) recharge") end
                n = tonumber(n)
                if n and (unit == "sec" or unit == "min") then cd = unit == "min" and n * 60 or n end
            end
        end
    end
    return table.concat(parts, " "), cd
end

-- Groups, best keys first.
local DAMAGE, DEFENSIVE, CONTROL, MOVEMENT, UTILITY = 1, 2, 3, 4, 5
local function Has(text, list)
    for _, p in ipairs(list) do if text:find(p) then return true end end
end
-- escapes / threat drops count as defensive: Vanish was listed as "damage your rotation
-- doesn't cast" (2026-10-25) -- it must never go into the one-button rotation
local DEF_WORDS  = { "damage taken", "heal", "absorb", "immun", "dodge", "parry", "invulnerab", "reduces all damage",
    "vanish", "threat", "enters? stealth", "entering stealth", "drop%a* combat" }
local CC_WORDS   = { "stun", "incapacitat", "disorient", "fear", "silenc", "root", "knock", "blind", "sleep",
    "polymorph", "taunt", "slowing", "reduc%a* .-movement speed" }
local DMG_WORDS  = { "deals? [%d,%.]+", "dealing", "inflict", "[%d,%.]+ %a+ damage", "[%d,%.]+ damage" }
local MOVE_WORDS = { "movement speed", "teleport", "leap", "charges? to", "jump", "dash", "grappl", "pull yourself" }

-- Without VoidSequencer the top row holds your main buttons. A spell is one if it does
-- damage (measured, or its tooltip says so even when it also slows or stuns), or, for a
-- healer, if it heals with a short cooldown (Tranquility-size cooldowns stay on Shift).
-- Returns its rank in the DAMAGE group, or nil.
local function MainRank(id, name, healer)
    local score, fights = VB:SpellDamage(name)
    if score and score >= 0.03 then return 1000 + score end
    local measuredLow = fights and fights >= 3
    local text, cd = SpellText(id)
    local rank = 100 - math.min(cd, 3600) / 3600
    if not measuredLow and Has(text, DMG_WORDS) then return rank end
    if healer and cd <= 30 and text:find("heal") then return rank end
    return nil
end

-- Group of one spell + its damage rank key (higher = better) for the DAMAGE group.
local function Classify(id, name)
    local score, fights = VB:SpellDamage(name)
    -- measured over a few fights: real damage, or (barely any) not a damage button
    local measuredLow = fights and fights >= 3 and score < 0.03
    if score and score >= 0.03 then return DAMAGE, 1000 + score end
    local text, cd = SpellText(id)
    if Has(text, DEF_WORDS) then return DEFENSIVE end
    if Has(text, CC_WORDS) then return CONTROL end
    -- unmeasured damage: shortest cooldown first (rank stays below any measured one)
    if not measuredLow and Has(text, DMG_WORDS) then return DAMAGE, 100 - math.min(cd, 3600) / 3600 end
    if Has(text, MOVE_WORDS) then return MOVEMENT end
    return UTILITY
end

-- The page keys 1-7 show while playing the current spec: Guardian lives in Bear Form
-- (page 9), Feral in Cat Form (page 7), as in PageDriver; everything else page 1.
local HOME_PAGE = { [103] = 7, [104] = 9 }
local function SpecID()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local si = getSpec and getSpec()
    return si and getInfo and getInfo(si)
end
function VB:HomePage()
    return HOME_PAGE[SpecID()] or 1
end

-- Fixed layouts for specs where the player agreed the keys (instead of the ranked
-- class list). Key -> spell name, a list of names (first one you know), or
-- { macro = spell } = VoidSequencer's healer macro for that spell (aimed at the hovered
-- frame / the tank), falling back to the plain spell without VoidSequencer.
local FIXED = {
    [105] = {   -- Restoration Druid (2026-10-27): key 1 = VoidSequencer heals by hover
        [2] = { macro = "Lifebloom" }, [3] = "Skull Bash", [4] = { macro = "Ironbark" },
        [5] = { macro = "Nature's Cure" }, [6] = "Nature's Swiftness", [7] = "Convoke the Spirits",
        s1 = "Tranquility", s2 = "Innervate", s3 = "Barkskin", s4 = { "Typhoon", "Ursol's Vortex" },
        s5 = "Soothe", s6 = "Stampeding Roar", s7 = { macro = "Rebirth" },
        -- Cat Form pages keys 1-7 to page 7 (the player's pick, 2026-10-27: "Mix"): key 1 =
        -- VoidSequencer's cat loop, cat finishers / AoE on 5-7, and the tank Lifebloom +
        -- Ironbark kept on 2 / 4 as emergencies (they pull you out of cat). The Shift row
        -- doesn't page, so it's the same in every form.
        pages = {
            [7] = { [2] = { macro = "Lifebloom" }, [3] = "Skull Bash", [4] = { macro = "Ironbark" },
                    [5] = "Swipe", [6] = "Rip", [7] = "Ferocious Bite" },
        },
    },
}

-- Name of the macro in an action slot (nil if it isn't a macro). GetActionInfo's id is
-- not reliably the macro index (a spell macro reports its spell), so match by name.
local function MacroAt(slot)
    local t = GetActionInfo(slot)
    if VB.IsSecret(t) or t ~= "macro" then return nil end
    local name = GetActionText(slot)
    if VB.IsSecret(name) then return nil end
    return name
end

local function FixedPlan(fixed, base)
    local api = VoidSequencerAPI
    local macros = (api and api.HealMacros and api.HealMacros()) or {}
    local plan = {}
    local function entry(slot, cmd, fallback, want)
        local p = { slot = slot, key = KeyText(cmd, fallback) }
        local names = (type(want) == "table" and not want.macro) and want or { want and (want.macro or want) }
        for _, nm in ipairs(names) do
            local id = KnownID(nm)
            if id then
                p.name, p.id = C_Spell.GetSpellName(id) or nm, id
                if type(want) == "table" and want.macro and macros[nm] then
                    p.macro = macros[nm]
                    p.name = p.name .. " (" .. macros[nm] .. ")"
                end
                break
            end
        end
        plan[#plan + 1] = p
    end
    for i = 2, 7 do entry(base + i, "ACTIONBUTTON" .. i, tostring(i), fixed[i]) end
    for i = 1, 7 do entry(60 + i, "MULTIACTIONBAR1BUTTON" .. i, "Shift-" .. i, fixed["s" .. i]) end
    -- extra form pages (Resto: Cat Form = page 7) with their own keys 2-7
    for pg, keys in pairs(fixed.pages or {}) do
        local pbase = (pg - 1) * 12
        if pbase ~= base then
            for i = 2, 7 do
                entry(pbase + i, "ACTIONBUTTON" .. i, tostring(i), keys[i])
                local p = plan[#plan]
                p.key = p.key .. " (cat)"
            end
        end
    end
    return plan
end

-- Slots on the shown bars; bar1 also counts the spec's home page.
function VB:ShownSlots()
    local slots = {}
    for _, def in ipairs(self.BAR_DEFS) do
        local cfg = def.page and self:BarConfig(def.key)
        local shown = cfg and cfg.enabled
        if cfg and shown == nil then shown = (def.key == "bar1") end   -- same default as Options
        if shown then
            local pages = { def.page }
            if def.key == "bar1" and self:HomePage() ~= def.page then pages[2] = self:HomePage() end
            for _, pg in ipairs(pages) do
                for i = 1, (cfg.num or 12) do slots[#slots + 1] = (pg - 1) * 12 + i end
            end
        end
    end
    return slots
end

-- The plan: { {slot=, key=, name=, id=}, ... }, the spells left over, VoidSequencer's
-- spells, and the damage spells placed (not in the rotation). fresh = ignore where
-- spells sit now.
function VB:BuildSuggestion(fresh)
    local _, class = UnitClass("player")
    local def = CLASS[class] or { list = {} }
    local skip = RotationSpells()
    local seq = SeqActive()
    local fixed = seq and FIXED[SpecID()]
    if fixed then return FixedPlan(fixed, (self:HomePage() - 1) * 12), {}, skip, {} end
    local taken = {}   -- canonical ids already planned
    local function usable(name)
        local id = name and KnownID(name)
        local c = Canon(id)
        if not c or taken[c] or skip[c] then return nil end
        taken[c] = true
        return id
    end

    -- interrupt (always key 3); tanks: taunt first; then the class list and other talents,
    -- sorted into groups (damage by rank, the rest keep their list order)
    local interrupt
    for _, nm in ipairs(def.interrupt or {}) do
        local id = usable(nm)
        if id then interrupt = { name = C_Spell.GetSpellName(id) or nm, id = id } break end
    end
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getRole = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole) or GetSpecializationRole
    local si = getSpec and getSpec()
    local role = si and getRole and getRole(si)
    local queue = {}
    -- mainOnly: a spellbook spell, kept only when it's a main (top-row) button.
    local function add(nm, group, mainOnly)
        local id = usable(nm)
        if not id then return end
        local name = C_Spell.GetSpellName(id) or nm
        local g, rank
        local main = not seq and MainRank(id, name, role == "HEALER")
        if main then
            g, rank = DAMAGE, main
        elseif mainOnly then
            taken[Canon(id)] = nil
            return
        else
            g, rank = Classify(id, name)
        end
        queue[#queue + 1] = { name = name, id = id, c = Canon(id), group = group or g, rank = rank or 0, order = #queue }
    end
    if role == "TANK" then
        for _, nm in ipairs(def.taunt or {}) do add(nm, 0) end
    end
    for _, nm in ipairs(def.list) do add(nm) end
    for _, nm in ipairs(TalentedActives()) do add(nm) end
    if not seq then
        for _, nm in ipairs(SpellbookActives()) do add(nm, nil, true) end
    end
    table.sort(queue, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.order < b.order
    end)

    -- keys: top row 2..7 (1..7 without VoidSequencer; 3 = interrupt) on the spec's home
    -- page, then Shift row 1..7 (bar 2 doesn't page, so it's the same in every form)
    local base = (self:HomePage() - 1) * 12
    local keys = {}
    for i = seq and 2 or 1, 7 do
        keys[#keys + 1] = { slot = base + i, cmd = "ACTIONBUTTON" .. i, fallback = tostring(i), top = true }
    end
    for i = 1, 7 do
        keys[#keys + 1] = { slot = 60 + i, cmd = "MULTIACTIONBAR1BUTTON" .. i, fallback = "Shift-" .. i }
    end
    local free = #keys - 1   -- minus the interrupt key
    local chosen = {}
    if seq then
        for i = 1, math.min(free, #queue) do chosen[queue[i].c] = queue[i] end
    else
        -- damage fills the 6 free top keys, the rest the 7 Shift keys; a row with room
        -- left takes the other kind
        local dmg, other = {}, {}
        for _, q in ipairs(queue) do
            if q.group == DAMAGE then dmg[#dmg + 1] = q else other[#other + 1] = q end
        end
        local topFree, shiftFree = free - 7, 7
        for i = 1, math.min(#dmg, topFree + math.max(0, shiftFree - #other)) do chosen[dmg[i].c] = dmg[i] end
        for i = 1, math.min(#other, shiftFree + math.max(0, topFree - #dmg)) do chosen[other[i].c] = other[i] end
    end

    -- 1) spells already on one of these keys stay there (unless fresh); 2) the rest fill
    -- the free keys best-first, in queue order (without VoidSequencer: damage on the top
    -- row, the rest on Shift, either one when its own kind has run out)
    local pick, placed = {}, {}
    if not fresh then
        for _, k in ipairs(keys) do
            local cur = k.slot ~= base + INTERRUPT_KEY and SpellAt(k.slot)
            local q = cur and chosen[cur]
            -- without VoidSequencer a spell only stays put on its own row (main buttons on
            -- top, the rest on Shift); the fill below moves it otherwise
            if q and not placed[q] and (seq or (q.group == DAMAGE) == (k.top == true)) then
                pick[k.slot] = q; placed[q] = true
            end
        end
    end
    for _, k in ipairs(keys) do
        if k.slot ~= base + INTERRUPT_KEY and not pick[k.slot] then
            local best
            for _, q in ipairs(queue) do
                if chosen[q.c] == q and not placed[q] then
                    if seq or (q.group == DAMAGE) == (k.top == true) then best = q break end
                    best = best or q
                end
            end
            if best then pick[k.slot] = best; placed[best] = true end
        end
    end

    local plan, damage = {}, {}
    for _, k in ipairs(keys) do
        local p = (k.slot == base + INTERRUPT_KEY) and interrupt or pick[k.slot]
        plan[#plan + 1] = { slot = k.slot, key = KeyText(k.cmd, k.fallback), name = p and p.name, id = p and p.id }
        if p and p.group == DAMAGE then damage[#damage + 1] = p.name end
    end
    local extra = {}
    for _, q in ipairs(queue) do
        if not placed[q] then extra[#extra + 1] = q.name end
    end
    return plan, extra, skip, damage
end

function VB:ApplySuggestion(fresh)
    if InCombatLockdown() then self:Print("can't change your bars in combat.") return end
    local plan, extra, skip = self:BuildSuggestion(fresh)
    self:SaveProfile("Before suggested", true)
    if self:EnsureBlockBindings() > 0 then self:ApplyBindings() end   -- keys the plan's labels promise

    ClearCursor()
    local placed = 0
    -- 1) key 1 stays empty while VoidSequencer drives it (caster page and the spec's home page)
    if SeqActive() then
        local key1 = { 1, (self:HomePage() - 1) * 12 + 1 }
        local fixed = FIXED[SpecID()]
        for pg in pairs(fixed and fixed.pages or {}) do key1[#key1 + 1] = (pg - 1) * 12 + 1 end
        for _, s in ipairs(key1) do
            if GetActionInfo(s) then PickupAction(s); ClearCursor() end
        end
    end
    -- 2) the 13 keys
    for _, p in ipairs(plan) do
        if p.macro then
            local idx = GetMacroIndexByName(p.macro)
            if idx and idx > 0 and MacroAt(p.slot) ~= p.macro then
                PickupMacro(idx)
                PlaceAction(p.slot)
                placed = placed + 1
            end
        elseif p.id then
            if SpellAt(p.slot) ~= Canon(p.id) and self.PickupEntry({ t = "spell", id = p.id }) then
                PlaceAction(p.slot)
                placed = placed + 1
            end
        elseif GetActionInfo(p.slot) then
            PickupAction(p.slot)   -- nothing suggested for this key: empty it
        end
        ClearCursor()
    end
    -- 3) VoidSequencer's spells off every shown bar
    local cleared = 0
    for _, slot in ipairs(self:ShownSlots()) do
        local c = SpellAt(slot)
        if c and skip[c] then
            PickupAction(slot); ClearCursor()
            cleared = cleared + 1
        end
    end
    self:QueueFullUpdate()
    VoidBarsCharDB.suggestUsed = true   -- from now on, offer an update after talent changes
    local seqNote = SeqActive() and (", %d VoidSequencer spell(s) taken off your bars"):format(cleared) or ""
    self:Print(("suggested layout applied: %d placed%s. Undo: Options -> profile \"Before suggested\" -> Restore."):format(placed, seqNote))
    if #extra > 0 then
        self:Print("didn't fit on the 14 keys: " .. table.concat(extra, ", ") .. " (drag any you want onto the Travel bar).")
    end
end

-- Preview text for the confirm popup.
function VB:SuggestionText()
    local plan, extra, _, damage = self:BuildSuggestion()
    local lines = {}
    for _, p in ipairs(plan) do
        lines[#lines + 1] = ("%s:  %s"):format(p.key, p.name or "|cff888888(empty)|r")
    end
    local text = table.concat(lines, "\n")
    if #extra > 0 then text = text .. "\n\n|cff888888Didn't fit: " .. table.concat(extra, ", ") .. "|r" end
    if #damage > 0 and SeqActive() then
        text = text .. "\n\n|cffffd100Damage your rotation (key 1) doesn't cast: " .. table.concat(damage, ", ")
            .. ".|r Adding them to VoidSequencer frees these keys."
    end
    return text
end

StaticPopupDialogs.VOIDBARS_SUGGEST = {
    text = "%s\n\n%s\n\nSpells already on these keys stay put; \"Re-sort all\" re-orders every key.\nYour current bars are saved as \"Before suggested\" first.",
    button1 = "Apply", button2 = "Not now", button3 = "Re-sort all",
    OnAccept = function() VB:ApplySuggestion() end,
    OnAlt = function() VB:ApplySuggestion(true) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- The plan lives on the main bar (keys 1-7) and Action Bar 2 (Shift+1-7): both must be on
-- with 7+ buttons, or half of it would land on buttons you can't see.
function VB:BlockReady()
    for _, key in ipairs({ "bar1", "bar2" }) do
        local cfg = self:BarConfig(key)
        local on = cfg.enabled
        if on == nil then on = (key == "bar1") end
        if not on or (cfg.num or 12) < 7 then return false end
    end
    return true
end

function VB:ShowSuggestion(intro)
    if InCombatLockdown() then self:Print("can't change your bars in combat.") return end
    if not self:BlockReady() then
        self:Print("suggested spells go on keys 1-7 (Action Bar 1) and Shift+1-7 (Action Bar 2). "
            .. "Turn both on with 7+ buttons (/vbars bar), or apply the clean layout: Options -> VoidBars -> Layout.")
        return
    end
    intro = intro or (SeqActive() and "Suggested layout (key 1 = VoidSequencer):"
        or "Suggested layout (damage on 1-7, interrupt on 3, the rest on Shift):")
    StaticPopup_Show("VOIDBARS_SUGGEST", intro, self:SuggestionText())
end

-- How many of the 14 keys (plus VoidSequencer spells on shown bars) would the
-- suggestion change right now? 0 = your bars already match your talents.
function VB:SuggestionChanges()
    local plan, _, skip = self:BuildSuggestion()
    local n = 0
    for _, p in ipairs(plan) do
        if p.macro then
            if MacroAt(p.slot) ~= p.macro then n = n + 1 end
        elseif p.id then
            if SpellAt(p.slot) ~= Canon(p.id) then n = n + 1 end
        elseif GetActionInfo(p.slot) then
            n = n + 1
        end
    end
    for _, slot in ipairs(self:ShownSlots()) do
        local c = SpellAt(slot)
        if c and skip[c] then n = n + 1 end
    end
    return n
end

-- After talents change (or a level-up teaches something new), WoW drops spells onto your
-- bars and the plan shifts. On characters that use the suggested layout, offer the update
-- once things settle -- never in combat, never on characters that don't use it.
do
    local pending, waitCombat
    local function Check()
        pending = nil
        -- uses the suggested layout = applied it (flag, or its undo profile from before the flag)
        local used = VoidBarsCharDB and (VoidBarsCharDB.suggestUsed
            or (VoidBarsCharDB.profiles and VoidBarsCharDB.profiles["Before suggested"]))
        if not used then return end
        if InCombatLockdown() then waitCombat = true return end
        if StaticPopup_FindVisible and StaticPopup_FindVisible("VOIDBARS_SUGGEST") then return end
        local n = VB:SuggestionChanges()
        if n > 0 then
            VB:ShowSuggestion(("Your talents or spells changed -- %d key(s) don't match the suggested layout any more. Update them?"):format(n))
        end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then
            if not waitCombat then return end
            waitCombat = nil
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
            return
        end
        if not pending then pending = true; C_Timer.After(3, Check) end
    end)
end
